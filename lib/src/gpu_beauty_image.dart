import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models.dart';

class GpuBeautyImage extends StatefulWidget {
  const GpuBeautyImage({
    super.key,
    required this.bytes,
    required this.preset,
    required this.level,
  });

  final Uint8List bytes;
  final BeautyPreset preset;
  final double level;

  @override
  State<GpuBeautyImage> createState() => _GpuBeautyImageState();
}

class _GpuBeautyImageState extends State<GpuBeautyImage> {
  static Future<ui.FragmentProgram>? _programFuture;
  late Future<_GpuBeautyResources> resources;

  @override
  void initState() {
    super.initState();
    resources = _loadResources();
  }

  @override
  void didUpdateWidget(covariant GpuBeautyImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      resources = _loadResources();
    }
  }

  Future<_GpuBeautyResources> _loadResources() async {
    _programFuture ??= ui.FragmentProgram.fromAsset(
      'assets/shaders/beauty.frag',
    );
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return _GpuBeautyResources(await _programFuture!, frame.image);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GpuBeautyResources>(
      future: resources,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Image.memory(
            widget.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                widget.bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              const ColoredBox(color: Color(0x10000000)),
            ],
          );
        }
        return CustomPaint(
          painter: _GpuBeautyPainter(
            resources: data,
            preset: widget.preset,
            level: widget.level,
          ),
        );
      },
    );
  }
}

class _GpuBeautyResources {
  const _GpuBeautyResources(this.program, this.image);
  final ui.FragmentProgram program;
  final ui.Image image;
}

class _GpuBeautyPainter extends CustomPainter {
  const _GpuBeautyPainter({
    required this.resources,
    required this.preset,
    required this.level,
  });

  final _GpuBeautyResources resources;
  final BeautyPreset preset;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = resources.program.fragmentShader();
    final parameters = switch (preset) {
      BeautyPreset.natural => (level * .62, level * .55, 0.0),
      BeautyPreset.smooth => (level, level * .36, 0.0),
      BeautyPreset.bright => (level * .42, level, 0.0),
      BeautyPreset.slim => (level * .55, level * .46, level),
    };
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, resources.image.width.toDouble())
      ..setFloat(3, resources.image.height.toDouble())
      ..setFloat(4, parameters.$1)
      ..setFloat(5, parameters.$2)
      ..setFloat(6, parameters.$3)
      ..setImageSampler(0, resources.image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _GpuBeautyPainter oldDelegate) {
    return oldDelegate.resources != resources ||
        oldDelegate.preset != preset ||
        oldDelegate.level != level;
  }
}
