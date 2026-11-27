/// Explicit, user-controlled model installation. Every download comes from the
/// URL in the signed-off manifest, is size-checked before it starts and is
/// SHA-256 verified before it is registered. Nothing is fetched at app start.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/workout/workout_controller.dart';
import 'model_catalog.dart';

class InstallResult {
  const InstallResult({
    required this.ok,
    this.path = '',
    this.sha256 = '',
    this.sizeBytes = 0,
    this.error = '',
  });

  final bool ok;
  final String path;
  final String sha256;
  final int sizeBytes;
  final String error;
}

/// Network + filesystem boundary. Injectable so checksum and abort paths are
/// unit-testable without downloading hundreds of megabytes.
class ModelInstaller {
  ModelInstaller({
    http.Client? client,
    Future<String> Function()? documentsPath,
  }) : _client = client ?? http.Client(),
       _documentsPath =
           documentsPath ??
           (() async => (await getApplicationDocumentsDirectory()).path);

  final http.Client _client;
  final Future<String> Function() _documentsPath;

  Future<InstallResult> install(
    ModelDescriptor descriptor, {
    required int freeBytes,
    void Function(int received, int? total)? onProgress,
    Future<void> Function(String sha256)? onHashPinned,
  }) async {
    final expected = descriptor.sizeBytes ?? 0;
    if (expected > 0 &&
        !hasDiskSpace(freeBytes: freeBytes, requiredBytes: expected)) {
      return const InstallResult(ok: false, error: 'disk_space_low');
    }
    final uri = Uri.tryParse(descriptor.url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return const InstallResult(ok: false, error: 'invalid_model_url');
    }

    final dir = Directory('${await _documentsPath()}/models');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${descriptor.filename.split('/').last}');
    final sink = file.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var received = 0;
    try {
      final request = http.Request('GET', uri);
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        await sink.close();
        await _safeDelete(file);
        return InstallResult(ok: false, error: 'http_${response.statusCode}');
      }
      final total = response.contentLength;
      if (total != null &&
          total > 0 &&
          !hasDiskSpace(freeBytes: freeBytes, requiredBytes: total)) {
        await sink.close();
        await _safeDelete(file);
        return const InstallResult(ok: false, error: 'disk_space_low');
      }
      await for (final chunk in response.stream) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
      hasher.close();
      final actual = digestSink.value.toString();

      if (descriptor.sha256 != null &&
          actual != descriptor.sha256!.trim().toLowerCase()) {
        await _safeDelete(file);
        return const InstallResult(ok: false, error: 'checksum_mismatch');
      }
      if (descriptor.sizeBytes != null && descriptor.sizeBytes != received) {
        await _safeDelete(file);
        return const InstallResult(ok: false, error: 'size_mismatch');
      }
      if (descriptor.sha256 == null) {
        await onHashPinned?.call(actual);
      }
      return InstallResult(
        ok: true,
        path: file.path,
        sha256: actual,
        sizeBytes: received,
      );
    } on Object catch (e) {
      try {
        await sink.close();
      } on Object {
        // Already closed.
      }
      await _safeDelete(file);
      return InstallResult(ok: false, error: 'download_failed: $e');
    }
  }

  Future<bool> remove(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // Best effort; the next install overwrites the partial artifact.
    }
  }
}

class ModelState {
  const ModelState({
    this.catalog = const [],
    this.installed = const {},
    this.progress = const {},
    this.errors = const {},
    this.loading = false,
  });

  final List<ModelDescriptor> catalog;
  final Map<String, String> installed;
  final Map<String, double> progress;
  final Map<String, String> errors;
  final bool loading;

  bool isInstalled(String id) => installed.containsKey(id);
}

class ModelManager extends Notifier<ModelState> {
  late final ModelInstaller _installer;

  @override
  ModelState build() {
    _installer = ModelInstaller();
    return const ModelState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final catalog = await loadBundledCatalog();
    final prefs = await SharedPreferences.getInstance();
    final installed = <String, String>{};
    for (final model in catalog) {
      if (model.isBundled) {
        installed[model.id] = 'bundled:${model.filename}';
        continue;
      }
      final path = prefs.getString('model_path_${model.id}');
      if (path != null && File(path).existsSync()) installed[model.id] = path;
    }
    state = state.copyWith(
      catalog: catalog,
      installed: installed,
      loading: false,
    );
  }

  Future<bool> install(
    ModelDescriptor descriptor, {
    required bool consent,
  }) async {
    if (!descriptor.required && !consent) {
      state = state.copyWith(
        errors: {...state.errors, descriptor.id: 'consent_required'},
      );
      return false;
    }
    final bridge = ref.read(platformBridgeProvider);
    final free = await bridge.freeStorageBytes();
    final result = await _installer.install(
      descriptor,
      freeBytes: free,
      onProgress: (received, total) {
        final fraction = total == null || total <= 0 ? 0.0 : received / total;
        state = state.copyWith(
          progress: {
            ...state.progress,
            descriptor.id: fraction.clamp(0.0, 1.0),
          },
        );
      },
      onHashPinned: (sha) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('model_sha_${descriptor.id}', sha);
      },
    );
    if (!result.ok) {
      state = state.copyWith(
        errors: {...state.errors, descriptor.id: result.error},
      );
      return false;
    }
    final registered = await bridge.registerModelFile(
      id: descriptor.id,
      path: result.path,
    );
    if (!registered.ok) {
      state = state.copyWith(
        errors: {...state.errors, descriptor.id: 'registration_failed'},
      );
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_path_${descriptor.id}', result.path);
    await prefs.setString('model_sha_${descriptor.id}', result.sha256);
    state = state.copyWith(
      installed: {...state.installed, descriptor.id: result.path},
      errors: {...state.errors}..remove(descriptor.id),
      progress: {...state.progress}..remove(descriptor.id),
    );
    return true;
  }

  Future<void> remove(ModelDescriptor descriptor) async {
    if (descriptor.isBundled) return;
    final path = state.installed[descriptor.id];
    if (path == null) return;
    await _installer.remove(path);
    final bridge = ref.read(platformBridgeProvider);
    await bridge.deleteModelFile(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('model_path_${descriptor.id}');
    final installed = {...state.installed}..remove(descriptor.id);
    state = state.copyWith(installed: installed);
  }

  void clearError(String id) {
    final errors = {...state.errors}..remove(id);
    state = state.copyWith(errors: errors);
  }
}

extension ModelStateX on ModelState {
  ModelState copyWith({
    List<ModelDescriptor>? catalog,
    Map<String, String>? installed,
    Map<String, double>? progress,
    Map<String, String>? errors,
    bool? loading,
  }) => ModelState(
    catalog: catalog ?? this.catalog,
    installed: installed ?? this.installed,
    progress: progress ?? this.progress,
    errors: errors ?? this.errors,
    loading: loading ?? this.loading,
  );
}

final modelManagerProvider = NotifierProvider<ModelManager, ModelState>(
  ModelManager.new,
);

/// Minimal sink for chunked SHA-256 calculation (crypto 3.x does not export its
/// own DigestSink publicly).
class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}
