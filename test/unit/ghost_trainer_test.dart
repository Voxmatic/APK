import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gym_trainer/features/visual_learning/ghost_trainer.dart';

GhostClip load(String path) => GhostClip.fromJson(
  jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
);

void main() {
  test('squat ghost interpolates authored 3D keyframes and loops', () {
    final clip = load('assets/exercises/animations/squat_3d.json');
    expect(clip.exercise, 'squat');
    expect(clip.joints.length, 14);
    expect(clip.edges.every((e) => e.length == 2), isTrue);
    final start = clip.poseAtMilliseconds(0);
    final middle = clip.poseAtMilliseconds(500);
    final looped = clip.poseAtMilliseconds(3000);
    expect(start.length, 14);
    expect(start[0][1], greaterThan(middle[0][1]));
    expect(looped[0][1], closeTo(start[0][1], 0.001));
    final halfway = clip.poseAtMilliseconds(250);
    expect(halfway[0][1], lessThan(start[0][1]));
    expect(halfway[0][1], greaterThan(middle[0][1]));
  });

  test('push-up ghost asset is present and valid', () {
    final clip = load('assets/exercises/animations/pushup_3d.json');
    expect(clip.exercise, 'pushup');
    expect(clip.view, 'side');
    expect(clip.keyframes.length, 3);
    expect(
      clip.poseAtMilliseconds(1500)[0][1],
      lessThan(clip.poseAtMilliseconds(0)[0][1]),
    );
  });
}
