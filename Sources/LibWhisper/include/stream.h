#include <stdint.h>
#include <stdbool.h>

#include <SDL.h>
#include <SDL_audio.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct stream_params {
    int32_t n_threads;
    int32_t step_ms;
    int32_t length_ms;
    int32_t keep_ms;
    int32_t capture_id;
    int32_t max_tokens;
    int32_t audio_ctx;

    float vad_thold;
    float freq_thold;

    bool speed_up;
    bool translate;
    bool print_special;
    bool no_context;
    bool no_timestamps;
    bool suppress_non_speech_tokens;

    const char *language;
    bool detect_language;
    const char *model;
} stream_params_t;

stream_params_t stream_default_params();

typedef struct stream_context *stream_context_t;

stream_context_t stream_init(stream_params_t params, void *vad, SDL_AudioCallback rawCallback);
void stream_free(stream_context_t ctx);

int stream_audio_clear(stream_context_t ctx);

int64_t stream_timestamp();

typedef int (*stream_callback_t) (const char *text, int64_t t0, int64_t t1, int64_t startTime, void *ctx);
int stream_run(stream_context_t ctx, void *callback_ctx, stream_callback_t callback);

#ifdef __cplusplus
}
#endif
