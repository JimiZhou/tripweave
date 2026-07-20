# Configuration

TripWeave has no built-in API key, private endpoint, update server, or managed
configuration service.

## LLM settings

Open **Settings → Editing service** and enter an OpenAI-compatible Chat
Completions endpoint, planning model, optional vision model, and API key.

- If the vision model field is empty, the planning model is used for both
  visual understanding and planning.
- Native clients call the configured HTTPS endpoint directly.
- Browser deployments must enable CORS on the model endpoint or provide their
  own non-logging HTTPS proxy.
- Original videos are not uploaded by the built-in agent loop. It sends a
  compressed contact sheet and media metadata only when analysis is requested.

Credentials entered in the open-source build are session-scoped. Do not put an
API key in Dart source, `--dart-define`, a workflow file, or a public Web build.

## Optional public service endpoints

`tool/dart-defines.example.json` documents two optional, non-secret values:

- `TRIPWEAVE_UPDATE_MANIFEST_URL`: HTTPS release manifest used by OTA checks.
- `TRIPWEAVE_MUSIC_CATALOG_URL`: HTTPS catalog that may replace the built-in
  CC0 metadata list.

Create the ignored file `tool/dart-defines.local.json`, then pass it during a
development build:

```bash
flutter run --dart-define-from-file=tool/dart-defines.local.json
```

Official public runner builds intentionally leave both values empty. The app
continues to work without them; update checks are disabled and the public CC0
catalog remains available.
