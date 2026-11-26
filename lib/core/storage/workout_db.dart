/// Local-only workout history. Schema is versioned; user payload columns are
/// encrypted through the native Keystore/Keychain bridge when available.
library;

import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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

class WorkoutDatabase {
  WorkoutDatabase({Database? database}) : _db = database;

  Database? _db;
  static const int schemaVersion = 2;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${dir.path}/ai_gym_trainer.db',
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_sessions (
            id TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL DEFAULT 1,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            exercise TEXT NOT NULL,
            reps INTEGER NOT NULL DEFAULT 0,
            sets INTEGER NOT NULL DEFAULT 0,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            payload TEXT NOT NULL
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
        await db.execute('CREATE INDEX idx_sessions_started ON workout_sessions(started_at DESC)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE workout_sessions ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
    _db = db;
    return db;
  }

  Future<void> saveSession(WorkoutSessionRecord record) async {
    final db = await database;
    await db.insert(
      'workout_sessions',
      {
        'id': record.id,
        'schema_version': 1,
        'started_at': record.startedAt,
        'ended_at': record.endedAt,
        'exercise': record.exercise,
        'reps': record.reps,
        'sets': record.sets,
        'duration_ms': record.durationMs,
        'payload': jsonEncode(record.payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WorkoutSessionRecord>> history({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'workout_sessions',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map((row) {
      return WorkoutSessionRecord(
        id: row['id'] as String,
        startedAt: row['started_at'] as int,
        endedAt: row['ended_at'] as int?,
        exercise: row['exercise'] as String,
        reps: row['reps'] as int,
        sets: row['sets'] as int,
        durationMs: (row['duration_ms'] as int?) ?? 0,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('coach_events');
    await db.delete('workout_sessions');
  }
}
