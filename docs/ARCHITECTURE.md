# Architecture

TripWeave is a Flutter single-codebase application with platform-specific
render adapters.

```text
Import and local beautification
            |
            v
Optional vision + planning loop ---- OpenAI-compatible endpoint
            |
            v
Three editable plans
            |
            v
Preview + timeline + BGM
            |
            v
Hardware encoder probe -> FFmpeg fallback -> FFprobe validation
```

## Platform acceleration

- Android: MediaCodec is probed through the vendored FFmpeg Kit wrapper.
- Web: WebCodecs is preferred when native H.264/AAC support is available;
  `ffmpeg.wasm` is the fallback.
- Windows: NVENC, QSV, and AMF are tried before the software encoder.
- macOS: VideoToolbox is tried before the software encoder.

Hardware selection is capability-based. A listed encoder is tested with a
short real encode before it is used, and failed hardware attempts fall back to
the compatible software path.

## Data boundaries

Media import, GPU beautification, timeline edits, audio mixing, rendering, and
project history remain on the device. The optional agent receives only the
contact sheet and metadata assembled for the explicit analysis request.
