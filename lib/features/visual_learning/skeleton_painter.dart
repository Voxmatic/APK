/// Real-time skeleton overlay drawn from native pose landmarks.
/// The front camera preview is mirrored, so x is flipped to match the user.
library;

import 'package:flutter/material.dart';

import '../exercise_intelligence/biomechanics.dart';

const _connections = <List<int>>[
  [0, 1],
  [1, 2],
  [2, 3],
  [3, 4],
  [1, 5],
  [5, 6],
  [6, 7],
  [1, 8],
  [8, 9],
  [9, 10],
  [0, 11],
  [0, 12],
  [11, 13],
  [13, 15],
  [12, 14],
  [14, 16],
  [11, 23],
  [12, 24],
  [23, 24],
  [23, 25],
  [25, 27],
  [24, 26],
  [26, 28],
];

class SkeletonPainter extends CustomPainter {
  const SkeletonPainter({
    required this.frame,
    required this.mirrored,
    this.highlightJoints = const {},
    this.showGhost = false,
  });

  final PoseFrame frame;
  final bool mirrored;
  final Set<int> highlightJoints;
  final bool showGhost;

  @override
  void paint(Canvas canvas, Size size) {
    if (!frame.hasFullBody) return;
    final bonePaint = Paint()
      ..color = const Color(0xFF20D6C2)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = const Color(0xFFB8FFF6);
    final highlightPaint = Paint()..color = const Color(0xFFFF5C3A);

    Offset toOffset(PoseLandmark lm) {
      final x = mirrored ? 1 - lm.x : lm.x;
      return Offset(x * size.width, lm.y * size.height);
    }

    for (final edge in _connections) {
      final a = frame.get(edge[0]);
      final b = frame.get(edge[1]);
      if (a == null || b == null) continue;
      if (a.visibility < 0.35 || b.visibility < 0.35) continue;
      canvas.drawLine(toOffset(a), toOffset(b), bonePaint);
    }

    for (var i = 0; i < frame.landmarks.length; i++) {
      final lm = frame.landmarks[i];
      if (lm.visibility < 0.35) continue;
      canvas.drawCircle(
        toOffset(lm),
        5.5,
        highlightJoints.contains(i) ? highlightPaint : jointPaint,
      );
    }

    if (showGhost) _drawGhost(canvas, size);
  }

  void _drawGhost(Canvas canvas, Size size) {
    final ghostPaint = Paint()
      ..color = const Color(0x806C7BFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    // A translucent reference skeleton offset to the right, representing the
    // ideal mid-rep posture. It is rendered from real landmark geometry.
    const ghostIndices = [11, 12, 23, 24, 25, 26, 27, 28];
    final points = <Offset>[];
    for (final i in ghostIndices) {
      final lm = frame.get(i);
      if (lm == null) return;
      final x = mirrored ? 1 - lm.x : lm.x;
      points.add(Offset(x * size.width + 40, lm.y * size.height + 12));
    }
    for (var i = 0; i + 1 < points.length; i += 2) {
      if (i + 1 < points.length)
        canvas.drawLine(points[i], points[i + 1], ghostPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter old) =>
      old.frame != frame ||
      old.mirrored != mirrored ||
      old.showGhost != showGhost;
}
