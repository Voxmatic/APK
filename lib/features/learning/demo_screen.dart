/// Local demonstration player with an asset-driven 3D ghost overlay.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/strings.dart';
import '../visual_learning/ghost_trainer.dart';
import '../workout/workout_controller.dart';

class DemoScreen extends ConsumerStatefulWidget {
  const DemoScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends ConsumerState<DemoScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  late final AnimationController _ghostClock;
  bool _videoReady = false;
  String _error = '';
  bool _showGhost = true;
  bool _slowMotion = false;

  @override
  void initState() {
    super.initState();
    _ghostClock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _ghostClock.addListener(() {
      if (mounted) setState(() {});
    });
    final asset = switch (widget.exerciseId) {
      'squat' => 'assets/exercises/videos/squat_front.mp4',
      'pushup' => 'assets/exercises/videos/pushup_side.mp4',
      _ => null,
    };
    if (asset == null) {
      _error = 'No demonstration video for ${widget.exerciseId}';
      return;
    }
    _video = VideoPlayerController.asset(asset)
      ..setLooping(true)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _videoReady = true);
            _video!.play();
          })
          .catchError((Object e) {
            if (mounted) setState(() => _error = e.toString());
          });
  }

  @override
  void dispose() {
    _ghostClock.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final ghost = ref.watch(ghostClipProvider(widget.exerciseId)).value;
    final timeMs = (_ghostClock.value * 3000).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.get('view_demo')} · ${s.get(widget.exerciseId)}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_videoReady)
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _video!.value.size.width,
                          height: _video!.value.size.height,
                          child: VideoPlayer(_video!),
                        ),
                      ),
                    if (_showGhost && ghost != null)
                      CustomPaint(
                        painter: GhostTrainerPainter(
                          clip: ghost,
                          timeMilliseconds: timeMs,
                          mirrored: widget.exerciseId == 'squat',
                          opacity: 0.75,
                        ),
                      ),
                    if (_error.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error, textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_video == null || !_videoReady) return;
                      _video!.value.isPlaying
                          ? _video!.pause()
                          : _video!.play();
                      setState(() {});
                    },
                    icon: Icon(
                      _video?.value.isPlaying ?? false
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  FilterChip(
                    label: const Text('3D ghost'),
                    selected: _showGhost,
                    onSelected: (value) => setState(() => _showGhost = value),
                  ),
                  FilterChip(
                    label: Text(s.get('demo_slow_motion')),
                    selected: _slowMotion,
                    onSelected: (value) async {
                      setState(() => _slowMotion = value);
                      if (_video != null && _videoReady) {
                        await _video!.setPlaybackSpeed(value ? 0.5 : 1.0);
                      }
                      _ghostClock.duration = value
                          ? const Duration(milliseconds: 6000)
                          : const Duration(seconds: 3);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
