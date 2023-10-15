import AVFoundation
import LibWhisper
import libfvad

public struct Segment {
    let text: String
    let t0: Int64
    let t1: Int64
}

public typealias OrderedSegments = [Segment]

public extension OrderedSegments {
    var text: any StringProtocol {
        map { $0.text }.joined()
    }
}

public class WhisperStream: Thread {
    public let vad = VAD()
    
    @Published public private(set) var segments = OrderedSegments()
    @Published public private(set) var alive = true
    private var streamContext: stream_context_t?

    let waiter = DispatchGroup()
    
    let model: URL
    let device: CaptureDevice?
    let window: TimeInterval
    let suppressNonSpeechOutput: Bool
    let language: String

    // Define a class-level lock to ensure serial execution of stream_init
    private static let streamInitLock = NSLock()

    public init(model: URL, device: CaptureDevice? = nil, window: TimeInterval = (60 * 60), suppressNonSpeechOutput: Bool = true, language: String? = nil) {
        self.model = model
        self.device = device
        self.window = window
        self.suppressNonSpeechOutput = suppressNonSpeechOutput
        self.language = language?.lowercased() ?? ""
        super.init()
    }

    deinit {
        if let streamContext = streamContext {
            stream_free(streamContext)
        }
    }

    public override func start() {
        waiter.enter()
        super.start()
    }

    public override func main() {
        task()
        waiter.leave()
    }

    public func join() {
        waiter.wait()
    }

    func task() {
        language.withCString { languageCStr in
            model.path.withCString { modelCStr in
                var params = stream_default_params()
                params.model = modelCStr
                params.language = languageCStr
                
                if let device = device {
                    params.capture_id = device.id
                }
                
                guard !isCancelled else {
                    alive = false
                    return
                }
                
                // Use the class-level lock to ensure only one instance initializes stream at a time
                WhisperStream.streamInitLock.lock()
                defer {
                    WhisperStream.streamInitLock.unlock()
                }
                
                let ctx = stream_init(params)
                streamContext = ctx
                if ctx == nil {
                    return
                }
                
                while !isCancelled {
                    let errno = stream_run(ctx, Unmanaged.passUnretained(self).toOpaque()) {
                        return Unmanaged<WhisperStream>.fromOpaque($3!).takeUnretainedValue().callback(
                            text: $0 != nil ? String(cString: $0!) : nil,
                            t0: $1,
                            t1: $2
                        )
                    }
                    if errno != 0 {
                        break
                    }
                }
                
                stream_free(ctx)
                streamContext = nil
                alive = false
            }
        }
    }

    func callback(text: String?, t0: Int64, t1: Int64) -> Int32 {
        if segments.isEmpty || text == nil {
            segments.append(Segment(text: "", t0: -1, t1: -1))
        }
        if var text = text {
            if suppressNonSpeechOutput {
                text = suppressNonSpeech(text: text)
            }
            segments[segments.count - 1] = Segment(text: text, t0: t0, t1: t1)
        }

        var k = 0
        for segment in segments {
            if let last = segments.last, last.t0 - segment.t0 > Int64(window * 1000) {
                k += 1
            }
        }
        segments.removeFirst(k)

        return 0
    }
    
    public func clearSegments() {
        segments.removeAll()
    }
    
    func suppressNonSpeech(text: String) -> String {
        var text = text
        // TODO: Disallow hyphens, single quotes at start of line (only between words)
        //        symbols = list("\"#()*+/:;<=>@[\\]^_`{|}~「」『』")
        //        symbols += "<< >> <<< >>> -- --- -( -[ (' (\" (( )) ((( ))) [[ ]] {{ }} ♪♪ ♪♪♪".split()
        //                miscellaneous = set("♩♪♫♬♭♮♯")
        text = text
            .replacingOccurrences(of: bracketPairsPattern, with: " ")
            .replacingOccurrences(of: symbolsPattern, with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)    }
}

// Non-symbol chars in brackets/parens
fileprivate let bracketPairsPattern = #"\[[^\p{L}\p{N}\s]+\]|\([^[:alnum:]\s]+\)|\{[^\p{L}\p{N}\s]+\}|\「[^\p{L}\p{N}\s]+\」|\『[^\p{L}\p{N}\s]+\』"#
fileprivate let symbolsPattern = #"[#*+/:;<=>^_`|~♩♪♫♬♭♮♯♪]+"#
