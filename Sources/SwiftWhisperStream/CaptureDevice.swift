import whisper_cpp
import SDL
import libfvad

public enum CaptureDeviceError: Error {
    case sdlErrorCode(Int32)
}

public struct CaptureDevice: Identifiable {
    public let id: Int32
    public let name: String
    
    public init(id: Int32, name: String) {
        self.id = id
        self.name = name
    }
    
    public static var devices: [CaptureDevice] {
        get throws {
            var devices = [CaptureDevice]()
            
            SDL_SetMainReady()
            let result = SDL_Init(SDL_INIT_AUDIO)
            if result < 0 {
                print("SDL could not initialize! SDL_Error: \(String(cString: SDL_GetError()))")
                throw CaptureDeviceError.sdlErrorCode(result)
            }
            
            for i in 0..<SDL_GetNumAudioDevices(1) {
                let name = String(cString: SDL_GetAudioDeviceName(i, 1))
                devices.append(CaptureDevice(id: i, name: name))
            }
            
            return devices
        }
    }
    
    public func close() {
        SDL_CloseAudioDevice(SDL_AudioDeviceID(id))
    }
}

extension CaptureDevice: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}

extension CaptureDevice: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
