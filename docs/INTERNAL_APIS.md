# Internal API contracts (schema_version 1)

All method channels are namespaced `ai_gym_trainer/<service>`. All errors are returned as
`FlutterError` with codes `PERMISSION_DENIED`, `MODEL_NOT_FOUND`, `INFERENCE_ERROR`,
`INVALID_STATE`, `STORAGE_ERROR`.

## camera

| Method | Input | Output |
|---|---|---|
| `camera.initialize` | `{camera: "front", targetFps: 30}` | `{ok: true, cameraId: string}` |
| `camera.start` | `{}` | `{ok: true}` |
| `camera.stop` | `{}` | `{ok: true}` |
| `camera.getStatus` | `{}` | `{running: bool, permission: bool, fps: double}` |

Platform view `ai_gym_trainer/camera_view` renders the native preview. No frames cross to Dart.

## pose

EventChannel `ai_gym_trainer/pose` emits:

```json
{
  "event": "pose_frame",
  "schema_version": 1,
  "timestamp_ms": 153200,
  "landmarks": [
    {"x": 0.51, "y": 0.44, "z": -0.02, "visibility": 0.93, "presence": 0.91}
  ],
  "worldLandmarks": [{"x": 0.1, "y": -0.4, "z": 0.0}],
  "inference_ms": 12.4
}
```

Methods: `pose.startTracking()`, `pose.stopTracking()`, `pose.getStatus()` →
`{running, modelId, modelSha256, backend}`.

## exercise

`exercise.loadModel({exerciseId})`, `startSession({exerciseId, targetReps, targetSets})`,
`pauseSession()`, `resumeSession()`, `stopSession()`, `getEvents()`.

Events:

```json
{"event":"rep_completed","schema_version":1,"exercise":"squat","rep_count":8,
 "phase":"standing","confidence":0.95,"timestamp_ms":153200}
```
```json
{"event":"form_correction","schema_version":1,"exercise":"squat",
 "error_code":"knees_collapsing_inward","severity":"warning","confidence":0.91,
 "timestamp_ms":153200}
```
```json
{"event":"visual_demo_required","schema_version":1,"exercise":"squat",
 "demo_id":"squat_knee_alignment_front","camera_view":"front"}
```

## coach

`coach.processEvent(event)` → `{instruction: {id, textKey, priority, visualDemoId?}}`.
`coach.getInstruction()` → current instruction or `null`.
Safety rules are evaluated first; no LLM output can bypass them.

## voice

`voice.speak({text, language, phraseId, priority})`, `voice.stop()`, `voice.setLanguage({language})`,
`voice.getStatus()`. Common phrases use bundled WAV assets; arbitrary text falls back to
localized templates (no network).

## visual

`visual.showDemo({demoId, slowMotion})`, `visual.hideDemo()`, `visual.replayDemo()`.

## storage

`storage.saveWorkout(session)`, `getWorkoutHistory({limit})`, `deleteWorkout({sessionId})`,
`exportData()`, `deleteAllData()`. All user payloads are AES-GCM encrypted before SQLite write.
