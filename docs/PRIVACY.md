# Privacy and Offline Guarantee

## Data that never leaves the device

- Raw camera frames (never cross into Dart and never uploaded)
- Pose landmarks and world landmarks
- Audio recordings or speech-command audio (no ASR is bundled)
- Workout history, repetitions, form events, coaching events
- Language, voice and visualization preferences
- Model telemetry or inference stats

The workout path contains no cloud inference endpoint, analytics SDK,
crash-upload SDK, remote database, or authentication service. The optional
model manager makes explicit HTTPS requests **only** after the user enables
optional downloads and taps Install on a specific artifact. No request is made
at app start.

## Data retained on device

| Data | Storage | Encryption |
|---|---|---|
| Preferences (`language`, `voice`, plan, consent) | `SharedPreferences` | Plaintext non-sensitive settings |
| Workout session fields | `workout_sessions` SQLite table | Indexed metadata only |
| Workout JSON payload + form events | `encrypted_payload` column | AES-256-GCM envelope via Android Keystore / iOS Keychain |
| Model install paths and pinned hashes | `SharedPreferences` | Plaintext metadata, no user data |
| Raw camera footage | **Not saved** | N/A |
| Audio recordings | **Not saved** | N/A |

If secure encryption is unavailable, session persistence fails explicitly; the
app never writes the plaintext workout payload as a fallback.

## User controls

- Settings → **Export data**: writes a plaintext JSON export to app-local
  documents (explicit user action; the file stays on this device).
- Settings → **Delete all data**: clears all local workout rows and coach events.
- Settings → **Model manager**: enable consent, install/verify/remove optional
  artifacts. The bundled pose model cannot be removed.
- Settings → **Local AI / Speech**: shows the real status of optional features;
  nothing is enabled merely by opening the screen.

## Verification checklist (to run on a physical device with network disabled)

1. Enable airplane mode; confirm Wi-Fi and mobile data are off.
2. Complete onboarding, calibration, a full workout, voice coaching, demo and
   summary without network access.
3. Inspect Android netstat / packet capture: no outbound connections from the
   app during a workout.
4. Confirm no camera/audio files were written to shared storage.
5. Export, inspect, then delete data; confirm history is empty afterwards.

Status: **IMPLEMENTED**, device verification **BLOCKED** (no attached device).
