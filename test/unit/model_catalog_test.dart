import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gym_trainer/core/models/model_catalog.dart';

void main() {
  test('bundled manifest verifies the exact pose artifact', () {
    final catalog = parseModelCatalog(
      File('assets/models/manifest.json').readAsStringSync(),
    );
    final pose = catalog.firstWhere((m) => m.id == 'pose_landmarker_lite');
    expect(pose.required, isTrue);
    expect(pose.license, 'Apache-2.0');
    expect(pose.sha256, isNotNull);
    final bytes = File('assets/models/${pose.filename}').readAsBytesSync();
    expect(bytes.length, pose.sizeBytes);
    expect(sha256Hex(bytes), pose.sha256);
    expect(checksumMatches(bytes, pose.sha256!), isTrue);
    expect(checksumMatches(bytes, '00' * 32), isFalse);
  });

  test('disk-space guard keeps a 64 MiB headroom', () {
    expect(
      hasDiskSpace(
        freeBytes: 100 * 1024 * 1024,
        requiredBytes: 40 * 1024 * 1024,
      ),
      isFalse,
    );
    expect(
      hasDiskSpace(
        freeBytes: 200 * 1024 * 1024,
        requiredBytes: 40 * 1024 * 1024,
      ),
      isTrue,
    );
    expect(hasDiskSpace(freeBytes: -1, requiredBytes: 1), isFalse);
  });

  test('byte formatting is deterministic', () {
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(0), 'unknown');
  });
}
