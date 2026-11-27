/// Verified model registry. The manifest is the single source of truth; no
/// model is substituted silently and every optional download is user-initiated.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.group,
    required this.filename,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.version,
    required this.license,
    required this.source,
    required this.required,
    this.note = '',
  });

  final String id;
  final String group;
  final String filename;
  final String url;
  final String? sha256;
  final int? sizeBytes;
  final String version;
  final String license;
  final String source;
  final bool required;
  final String note;

  bool get isBundled => id == 'pose_landmarker_lite';

  static ModelDescriptor fromJson(Map<String, dynamic> json) => ModelDescriptor(
    id: json['id'] as String,
    group: json['group'] as String,
    filename: json['filename'] as String,
    url: json['url'] as String,
    sha256: json['sha256'] as String?,
    sizeBytes: (json['size_bytes'] as num?)?.toInt(),
    version: json['version'] as String? ?? '',
    license: json['license'] as String? ?? '',
    source: json['source'] as String? ?? '',
    required: json['required'] == true,
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'group': group,
    'filename': filename,
    'url': url,
    'sha256': sha256,
    'size_bytes': sizeBytes,
    'version': version,
    'license': license,
    'source': source,
    'required': required,
    'note': note,
  };
}

/// Parses the bundled catalog without any network access.
List<ModelDescriptor> parseModelCatalog(String jsonText) {
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  final models = decoded['models'] as List<dynamic>;
  return models
      .map((e) => ModelDescriptor.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

Future<List<ModelDescriptor>> loadBundledCatalog() async {
  final text = await rootBundle.loadString('assets/models/manifest.json');
  return parseModelCatalog(text);
}

/// Pure checksum helper so verification is unit-testable without a device.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

bool checksumMatches(List<int> bytes, String expected) =>
    sha256Hex(bytes) == expected.trim().toLowerCase();

/// Reject a download when the device cannot hold the artifact plus headroom.
bool hasDiskSpace({required int freeBytes, required int requiredBytes}) =>
    freeBytes > 0 && freeBytes >= requiredBytes + (64 * 1024 * 1024);

String formatBytes(int bytes) {
  if (bytes <= 0) return 'unknown';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

Uint8List concatChunks(List<List<int>> chunks) =>
    Uint8List.fromList(chunks.expand((c) => c).toList());
