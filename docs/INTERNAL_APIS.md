# Internal API contracts (schema_version 1)

All native calls are wrapped by `lib/core/platform/pose_channel.dart`. Every
failure is converted into a typed `PlatformResult(ok:false, code, message)`;
a `PlatformException` never reaches widget lifecycle code. Raw camera frames
never cross this boundary — only compact landmark events.

## MethodChannel `ai_gym_trainer/camera`

| Method | Input | Output |
|---|---|---|
| `camera.requestPermission` | `{}` | `{ok, code?, message?, granted?, pending?}` |
| `camera.initialize` | `{camera:"front", targetFps:30}` | `{ok:true}` or typed error |
| `camera.start` | `{}` | `{ok:true}` or `{ok:false, code:"CAMERA_NOT_ATTACHED", message}` |
| `camera.stop` | `{}` | `{ok:true}` or typed error |
| `camera.getStatus` | `{}` | `{running, permission, fps, cameraId, error}` |
| `pose.getStatus` | `{}` | `{running, modelId, modelSha256, modelReady, backend, inferenceMs, fps, lastError}` |
| `pose.unload` | `{}` | `{ok:true}` or typed error |
| `device.getInfo` | `{}` | `{platform, model, osVersion, sdk, abi, totalRamBytes, freeStorageBytes, cameraAvailable, acceleration}` |
| `storage.getFreeSpace` | `{}` | `{bytes:int}` (`-1` when unavailable) |
| `storage.encrypt` | plaintext `String` | `{schema_version, alg:"AES-256-GCM", iv, ct}` or `null` |
| `storage.decrypt` | AES-GCM envelope `Map` | plaintext `String` or `null` |
| `model.register` | `{id, path}` | `{ok:true}` or typed error |
| `model.delete` | `{path}` | `{ok:true}` or typed error |
| `app.openSettings` | `{}` | `{ok:true}` or typed error |

Platform view `ai_gym_trainer/camera_view` renders the native preview. Each
Flutter view id gets its own `PreviewView`; `camera.start` is deferred until
the view is attached, and a late `stop()` is serialized through
`CameraSession` so it cannot race a new `start()`.

## EventChannel `ai_gym_trainer/pose`

Emits one compact map per inference result:

```json
{
  "event": "pose_frame",
  "schema_version": 1,
  "timestamp_ms": 153200,
  "landmarks": [
    {"x":0.51,"y":0.44,"z":-0.02,"visibility":0.93,"presence":0.91}
  ],
  "worldLandmarks": [{"x":0.1,"y":-0.4,"z":0.0,"visibility":0.9,"presence":0.9}],
  "inference_ms": 12.4
}
```

Malformed events become `PoseFrame(error:"Malformed pose event")`, which the
workout controller renders as a tracking error and ignores for rep counting.

## EventChannel `ai_gym_trainer/system`

| Event | Payload | Meaning |
|---|---|---|
| permission | `{type:"permission", granted:bool, message}` | Runtime permission result; drives permission-recovery UI. |
| lifecycle | `{type:"lifecycle", phase:"paused|resumed|detached"}` | Native lifecycle; app pauses/stops and resumes camera ownership. |
| audio | `{type:"audio", message}` | Audio focus/interruption hint. |

## Dart-only contracts

Exercise intelligence, coaching, voice selection, demos and storage are
implemented in Dart/native platform code, not as extra method channels:

- `exercise_intelligence/`: deterministic `SquatEngine` and `PushUpEngine`;
  a rep requires a complete phase sequence, never a single threshold crossing.
- `coach/CoachEngine`: safety-first policy with cooldown and approved phrase ids.
- `voice/VoiceService`: plays only bundled `assets/audio/<lang>/<key>.wav`.
- `visual_learning/GhostTrainerPainter`: interpolates authored 3D keyframes.
- `core/storage/workout_db.dart`: encrypted payload envelopes in SQLite.

Event schemas for rep and form events are versioned and covered by
`test/integration/platform_contract_test.dart`.
