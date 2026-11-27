/// Native camera preview platform view. Camera frames stay in native code.
/// The builder is injectable so widget tests can replace the platform view.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/pose_channel.dart';

class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return const AndroidView(viewType: PlatformBridge.cameraViewType);
    }
    if (Platform.isIOS) {
      return const UiKitView(viewType: PlatformBridge.cameraViewType);
    }
    return const ColoredBox(color: Colors.black);
  }
}

final cameraPreviewBuilderProvider = Provider<Widget Function()>(
  (ref) =>
      () => const CameraPreviewWidget(),
);
