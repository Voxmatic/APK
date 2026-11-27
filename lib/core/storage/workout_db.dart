/// Local-only workout history. User payloads are AES-256-GCM encrypted through
/// the platform Keystore/Keychain bridge before they touch SQLite.
library;

import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../platform/pose_channel.dart';

class WorkoutSessionRecord {
  const WorkoutSessionRecord({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.exercise,
    required this.reps,
    required this.sets,
    required this.durationMs,
    required this.payload,
  });

  final String id;
  final int startedAt;
  final int? endedAt;
  final String exercise;
  final int reps;
  final int sets;
  final int durationMs;
  final Map<String, dynamic> payload;
}

abstract interface class WorkoutStore {
  Future<void> saveSession(WorkoutSessionRecord record);
  Future<List<WorkoutSessionRecord>> history({int limit = 50});
  Future<void> deleteAll();
  Future<String> exportJson();
}

/// Encrypt/decrypt a JSON payload. Implementations must never log plaintext.
abstract interface class PayloadCipher {
  Future<Map<String, dynamic>> encrypt(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> decrypt(Map<String, dynamic> envelope);
}

/// Android Keystore / iOS Keychain backed cipher. Failure is explicit: the app
/// must not silently write unencrypted user data instead.
class NativePayloadCipher implements PayloadCipher {
  NativePayloadCipher(this._bridge);

  final PlatformBridge _bridge;

  @override
  Future<Map<String, dynamic>> encrypt(Map<String, dynamic> payload) async {
    final envelope = await _bridge.encrypt(jsonEncode(payload));
    if (envelope == null ||
        envelope['ct'] is! String ||
        envelope['iv'] is! String ||
        envelope['alg'] != 'AES-256-GCM') {
      throw StateError(
        'Secure storage unavailable; workout was not persisted unencrypted.',
      );
    }
    return envelope;
  }

  @override
  Future<Map<String, dynamic>> decrypt(Map<String, dynamic> envelope) async {
    final plain = await _bridge.decrypt(envelope);
    if (plain == null)
      throw StateError('Encrypted workout payload could not be decrypted.');
    final decoded = jsonDecode(plain);
    if (decoded is! Map<String, dynamic>)
      throw StateError('Invalid decrypted workout payload.');
    return decoded;
  }
}

/// Test-only cipher. It is never selected in production code.
class IdentityPayloadCipher implements PayloadCipher {
  const IdentityPayloadCipher();

  @override
  Future<Map<String, dynamic>> encrypt(Map<String, dynamic> payload) async => {
    'schema_version': 1,
    'alg': 'IDENTITY_TEST_ONLY',
    'payload': payload,
  };

  @override
  Future<Map<String, dynamic>> decrypt(Map<String, dynamic> envelope) async =>
      Map<String, dynamic>.from(envelope['payload'] as Map? ?? const {});
}

class WorkoutDatabase implements WorkoutStore {
  WorkoutDatabase({Database? database, this._cipher}) : _db = database;

  Database? _db;
  final PayloadCipher? _cipher;
  static const int schemaVersion = 3;

  PayloadCipher get cipher => _cipher ?? NativePayloadCipher(PlatformBridge());

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${dir.path}/ai_gym_trainer.db',
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE workout_sessions ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE workout_sessions ADD COLUMN encrypted_payload TEXT',
          );
        }
      },
    );
    _db = db;
    return db;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE workout_sessions (
        id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL DEFAULT 2,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        exercise TEXT NOT NULL,
        reps INTEGER NOT NULL DEFAULT 0,
        sets INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        payload TEXT,
        encrypted_payload TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE coach_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schema_version INTEGER NOT NULL DEFAULT 1,
        session_id TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sessions_started ON workout_sessions(started_at DESC)',
    );
  }

  @override
  Future<void> saveSession(WorkoutSessionRecord record) async {
    final db = await database;
    final envelope = await cipher.encrypt(record.payload);
    await db.insert('workout_sessions', {
      'id': record.id,
      'schema_version': 2,
      'started_at': record.startedAt,
      'ended_at': record.endedAt,
      'exercise': record.exercise,
      'reps': record.reps,
      'sets': record.sets,
      'duration_ms': record.durationMs,
      'payload': null,
      'encrypted_payload': jsonEncode(envelope),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<WorkoutSessionRecord>> history({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'workout_sessions',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    final records = <WorkoutSessionRecord>[];
    for (final row in rows) {
      Map<String, dynamic> payload;
      final encrypted = row['encrypted_payload'] as String?;
      try {
        payload = encrypted == null
            ? jsonDecode(row['payload'] as String? ?? '{}')
                  as Map<String, dynamic>
            : await cipher.decrypt(
                jsonDecode(encrypted) as Map<String, dynamic>,
              );
      } on Object catch (e) {
        payload = {'decryption_error': e.toString()};
      }
      records.add(
        WorkoutSessionRecord(
          id: row['id'] as String,
          startedAt: (row['started_at'] as num).toInt(),
          endedAt: (row['ended_at'] as num?)?.toInt(),
          exercise: row['exercise'] as String,
          reps: (row['reps'] as num).toInt(),
          sets: (row['sets'] as num).toInt(),
          durationMs: (row['duration_ms'] as num?)?.toInt() ?? 0,
          payload: payload,
        ),
      );
    }
    return records;
  }

  @override
  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('coach_events');
    await db.delete('workout_sessions');
  }

  @override
  Future<String> exportJson() async {
    final rows = await history(limit: 100000);
    return jsonEncode({
      'schema_version': 2,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'note': 'Plaintext export explicitly requested by the user; stays on this device.',
      'sessions': rows
          .map(
            (r) => {
              'id': r.id,
              'started_at': r.startedAt,
              'ended_at': r.endedAt,
              'exercise': r.exercise,
              'reps': r.reps,
              'sets': r.sets,
              'duration_ms': r.durationMs,
              'payload': r.payload,
            },
          )
          .toList(),
    });
  }
}

/// In-memory store used by widget/integration tests and by desktop previews.
class MemoryWorkoutStore implements WorkoutStore {
  MemoryWorkoutStore({this.cipher});

  /// When supplied, every write exercises the real cipher contract before the
  /// in-memory row is stored. Production never selects this implementation.
  final PayloadCipher? cipher;
  final List<WorkoutSessionRecord> _records = [];

  @override
  Future<void> saveSession(WorkoutSessionRecord record) async {
    final payload = cipher == null
        ? record.payload
        : await cipher!.decrypt(await cipher!.encrypt(record.payload));
    _records.removeWhere((r) => r.id == record.id);
    _records.add(
      WorkoutSessionRecord(
        id: record.id,
        startedAt: record.startedAt,
        endedAt: record.endedAt,
        exercise: record.exercise,
        reps: record.reps,
        sets: record.sets,
        durationMs: record.durationMs,
        payload: payload,
      ),
    );
  }

  @override
  Future<List<WorkoutSessionRecord>> history({int limit = 50}) async =>
      List.unmodifiable(_records.reversed.take(limit));

  @override
  Future<void> deleteAll() async => _records.clear();

  @override
  Future<String> exportJson() async => jsonEncode({
    'schema_version': 2,
    'sessions': _records
        .map((r) => {'exercise': r.exercise, 'reps': r.reps})
        .toList(),
  });
}
