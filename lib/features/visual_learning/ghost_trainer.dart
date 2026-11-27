/// Asset-driven 3D ghost trainer. Keyframes are authored joint positions in
/// metres; depth (z) is projected with a slow yaw so the reference actually
/// rotates instead of being a copy of the user's landmarks.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GhostClip {
  const GhostClip({
    required this.exercise,
    required this.view,
    required this.loopSeconds,
    required this.joints,
    required this.edges,
    required this.highlightJoints,
    required this.keyframes,
  });

  final String exercise;
  final String view;
  final double loopSeconds;
  final List<String> joints;
  final List<List<int>> edges;
  final Set<int> highlightJoints;
  final List<GhostKeyframe> keyframes;

  static GhostClip fromJson(Map<String, dynamic> json) {
    final frames = (json['keyframes'] as List<dynamic>).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return GhostKeyframe(
        t: (map['t'] as num).toDouble(),
        positions: (map['positions'] as List<dynamic>)
            .map(
              (p) => (p as List<dynamic>)
                  .map((v) => (v as num).toDouble())
                  .toList(),
            )
            .toList(),
      );
    }).toList();
    return GhostClip(
      exercise: json['exercise'] as String? ?? '',
      view: json['view'] as String? ?? 'front',
      loopSeconds: (json['loop_seconds'] as num?)?.toDouble() ?? 3,
      joints: (json['joints'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      edges: (json['edges'] as List<dynamic>)
          .map(
            (e) => (e as List<dynamic>).map((v) => (v as num).toInt()).toList(),
          )
          .toList(),
      highlightJoints: (json['highlight_joints'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toSet(),
      keyframes: frames,
    );
  }

  /// Linear interpolation between the two surrounding authored keyframes.
  List<List<double>> poseAtMilliseconds(int milliseconds) {
    if (keyframes.isEmpty) return const [];
    final loopMs = (loopSeconds * 1000).round().clamp(1, 60000);
    final t = (milliseconds % loopMs) / 1000.0;
    var i = 0;
    while (i + 1 < keyframes.length && keyframes[i + 1].t < t) {
      i++;
    }
    final a = keyframes[i];
    final b = keyframes[math.min(i + 1, keyframes.length - 1)];
    final span = b.t - a.t;
    final f = span <= 0 ? 0.0 : ((t - a.t) / span).clamp(0.0, 1.0);
    return List.generate(a.positions.length, (j) {
      final pa = a.positions[j];
      final pb = b.positions.length > j ? b.positions[j] : pa;
      return List.generate(pa.length, (k) => pa[k] + (pb[k] - pa[k]) * f);
    });
  }
}

class GhostKeyframe {
  const GhostKeyframe({required this.t, required this.positions});

  final double t;
  final List<List<double>> positions;
}

Future<GhostClip?> loadGhostClip(String exerciseId) async {
  final path = switch (exerciseId) {
    'squat' => 'assets/exercises/animations/squat_3d.json',
    'pushup' => 'assets/exercises/animations/pushup_3d.json',
    _ => null,
  };
  if (path == null) return null;
  final decoded =
      jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
  return GhostClip.fromJson(decoded);
}

final ghostClipProvider = FutureProvider.family<GhostClip?, String>(
  (ref, exerciseId) => loadGhostClip(exerciseId),
);

class GhostTrainerPainter extends CustomPainter {
  const GhostTrainerPainter({
    required this.clip,
    required this.timeMilliseconds,
    this.yaw = 0.35,
    this.mirrored = false,
    this.opacity = 0.85,
  });

  final GhostClip clip;
  final int timeMilliseconds;
  final double yaw;
  final bool mirrored;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = clip.poseAtMilliseconds(timeMilliseconds);
    if (positions.isEmpty) return;
    final scale = math.min(size.width / 1.15, size.height / 1.95) * 0.88;
    final centerX = size.width / 2;
    final bottom = size.height * 0.94;
    final cos = math.cos(yaw);
    final sin = math.sin(yaw);

    Offset project(List<double> p) {
      final x = mirrored ? -p[0] : p[0];
      final depth = p.length > 2 ? p[2] : 0.0;
      final rotatedX = x * cos - depth * sin;
      final screenX = centerX + rotatedX * scale;
      final screenY = bottom - (p[1] * cos + depth * sin * 0.18) * scale;
      return Offset(screenX, screenY);
    }

    for (final edge in clip.edges) {
      if (edge.length != 2) continue;
      final aIndex = edge[0];
      final bIndex = edge[1];
      if (aIndex >= positions.length || bIndex >= positions.length) continue;
      final a = project(positions[aIndex]);
      final b = project(positions[bIndex]);
      final depth =
          (positions[aIndex].length > 2 ? positions[aIndex][2] : 0) +
          (positions[bIndex].length > 2 ? positions[bIndex][2] : 0);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Color.fromRGBO(
            132,
            126,
            255,
            (opacity * (0.55 + depth * 0.2)).clamp(0.2, 1.0),
          )
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < positions.length; i++) {
      final point = project(positions[i]);
      canvas.drawCircle(
        point,
        clip.highlightJoints.contains(i) ? 6.5 : 4.5,
        Paint()
          ..color = Color.fromRGBO(
            clip.highlightJoints.contains(i) ? 255 : 192,
            clip.highlightJoints.contains(i) ? 210 : 196,
            255,
            opacity,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GhostTrainerPainter old) =>
      old.clip != clip ||
      old.timeMilliseconds != timeMilliseconds ||
      old.yaw != yaw ||
      old.mirrored != mirrored ||
      old.opacity != opacity;
}
