import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildRenderedVideoPreview(String path) => _RenderedVideoPreview(path);

class _RenderedVideoPreview extends StatefulWidget {
  const _RenderedVideoPreview(this.path);
  final String path;

  @override
  State<_RenderedVideoPreview> createState() => _RenderedVideoPreviewState();
}

class _RenderedVideoPreviewState extends State<_RenderedVideoPreview> {
  late VideoPlayerController controller;
  late Future<void> initialization;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _RenderedVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      controller.dispose();
      _initialize();
    }
  }

  void _initialize() {
    controller = VideoPlayerController.file(File(widget.path));
    initialization = controller.initialize().then((_) {
      controller.setLooping(true);
      controller.addListener(_refreshPlaybackState);
      if (mounted) setState(() {});
    });
  }

  void _refreshPlaybackState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refreshPlaybackState);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Color(0xFF30455B),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Color(0xFF30455B),
              child: Center(
                child: Text(
                  '视频预览没有成功加载。',
                  style: TextStyle(color: Color(0xFFF6F0E5)),
                ),
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(controller),
                const Positioned(left: 14, top: 14, child: _MixedAudioBadge()),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xD92C2925),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            controller.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          },
                          tooltip: controller.value.isPlaying ? '暂停' : '播放',
                          color: const Color(0xFFF6F0E5),
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                        ),
                        Expanded(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFE36B42),
                              bufferedColor: Color(0xFF90877D),
                              backgroundColor: Color(0xFF5E5750),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => controller.setVolume(
                            controller.value.volume > 0 ? 0 : 1,
                          ),
                          tooltip: controller.value.volume > 0 ? '静音' : '打开声音',
                          color: const Color(0xFFF6F0E5),
                          icon: Icon(
                            controller.value.volume > 0
                                ? Icons.volume_up
                                : Icons.volume_off,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MixedAudioBadge extends StatelessWidget {
  const _MixedAudioBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD92C2925),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, size: 16, color: Color(0xFFFFC85B)),
            SizedBox(width: 6),
            Text(
              '原声 + BGM',
              style: TextStyle(
                color: Color(0xFFF6F0E5),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
