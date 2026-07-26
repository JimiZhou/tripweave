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

## Admin model presets

The sign-in screen has an admin entry (管理员入口). The first admin sign-in on a
device sets a local passcode (stored as a salted SHA-256 digest); later admin
sign-ins verify it. Admins see **Settings → 模型预置管理** where they can:

- create named presets (endpoint, planning/vision model, API key, note),
- mark one preset as the default, which is auto-applied for new sessions,
- edit or delete device-local presets.

Travelers pick a preset from **Settings → 剪辑服务预置** and never see the API
key. Presets are stored on the device via `shared_preferences`; there is still
no hosted account or configuration service.

Private deployments may additionally bake presets into a build:

```json
{
  "TRIPWEAVE_MODEL_PRESETS": "[{\"id\":\"studio\",\"name\":\"工作室通道\",\"endpoint\":\"https://llm.example.com/v1/chat/completions\",\"planningModel\":\"planner\",\"visionModel\":\"vision\",\"apiKey\":\"sk-...\",\"note\":\"内部使用\"}]"
}
```

Built-in presets appear with a “部署内置” badge and cannot be edited or deleted
on the device. A dart-define value is embedded in the binary — for Web builds it
is downloadable JavaScript, so only use it behind access control, never in a
public deployment.

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
