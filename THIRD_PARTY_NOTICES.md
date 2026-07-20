# Third-party notices

TripWeave's own source code is licensed under the MIT License. Components and
assets listed below remain under their respective licenses.

## FFmpeg and FFmpeg Kit

- `third_party/ffmpeg_kit_flutter_new_min/` is a modified minimal Flutter
  wrapper distributed under LGPL-3.0. Its full license is kept beside the
  source in `third_party/ffmpeg_kit_flutter_new_min/LICENSE`.
- `web/ffmpeg/` contains the browser FFmpeg runtime and WebAssembly core. See
  the upstream FFmpeg and ffmpeg.wasm projects for the corresponding source
  and license terms: https://ffmpeg.org/ and https://github.com/ffmpegwasm/ffmpeg.
- Runner-built desktop packages bundle separate `ffmpeg` and `ffprobe`
  executables. The Windows workflow downloads the Gyan FFmpeg Essentials
  build; the macOS workflow packages Homebrew's FFmpeg build and its dynamic
  libraries. These executables are invoked as separate programs and retain
  their upstream FFmpeg build licenses. Source and configuration information
  are available from https://www.gyan.dev/ffmpeg/builds/ and
  https://formulae.brew.sh/formula/ffmpeg.

FFmpeg builds may include LGPL or GPL components depending on the runner
provider's configuration. Redistributors are responsible for preserving the
matching license and source offer.

## Music

The default catalog references public-domain/CC0 recordings from the
SoundSafari CC0 music collection. Audio is fetched on demand and is not stored
in this repository. Per-track author, source, and license links are listed in
`assets/music/LICENSES.md` and shown in the application.

## Fonts

- Manrope and Fraunces are licensed under the SIL Open Font License.
- Noto Sans SC is licensed under the SIL Open Font License; the included notice
  is in `assets/fonts/NotoSansSC-LICENSE.txt`.
- Browser fallback font notices are in `web/font-fallback/LICENSES.md`.

## Flutter packages

Dependency names and exact versions are recorded in `pubspec.lock`. Each
package remains under the license published with its upstream source.
