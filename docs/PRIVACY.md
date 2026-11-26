# Privacy and Offline Guarantee

## Data that never leaves the device

- Camera frames (raw or processed)
- Pose landmarks or world landmarks
- Audio recordings or speech command audio
- Workout history, repetitions, form events, coaching events
- User profile, language, voice preferences
- Model telemetry or inference stats

No cloud inference endpoint, analytics SDK, crash-upload SDK, remote database, or authentication
service is included in the application. The only network code in the repository is the explicit
`scripts/download_models.py` setup tool, which is run by the developer/user on a desktop before use.

## Data retained on device

| Data | Storage | Encryption |
|---|---|---|
| Preferences | `users` / `user_preferences` tables (SQLite) | AES-GCM payload via Android Keystore / iOS Keychain platform channel |
| Workout sessions and reps | `workout_sessions`, `workout_sets`, `workout_reps` | AES-GCM encrypted JSON payload columns |
| Form/coach events | `form_events`, `coach_events` | AES-GCM encrypted payload columns |
| Model metadata | `model_registry` | Plaintext metadata only (no user data) |
| Raw camera footage | **Not saved** | N/A |
| Audio recordings | **Not saved** | N/A |

Key handling: a device-bound AES-256-GCM key is generated in Android Keystore (or iOS Keychain).
Ciphertext is stored in SQLite; plaintext is only held in memory while a screen needs it.

## User controls

- Settings → **Export data**: writes an encrypted/plaintext JSON export to app-local storage for user transfer.
- Settings → **Delete all data**: clears all application tables and cached exports.
- Settings → **Model management**: install/verify/uninstall models. Updates are user-initiated only.

## Verification checklist (to run on a physical device with network disabled)

1. Enable airplane mode; confirm Wi-Fi and mobile data are off.
2. Complete a full workout (camera, tracking, reps, voice, demo, summary).
3. Inspect Android netstat / packet capture: no outbound connections from the app.
4. Confirm no camera/audio files were written to shared storage.
5. Delete data and confirm all tables are empty.
