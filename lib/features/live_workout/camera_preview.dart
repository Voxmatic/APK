/// Native camera preview platform view. Camera frames stay in native code.
library;

import 'dart:io';

import 'package:flutter/material.dart';

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
