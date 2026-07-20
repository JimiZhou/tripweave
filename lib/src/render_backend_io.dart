import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

import 'editing_agent_models.dart';
import 'models.dart';
import 'music_catalog.dart';
import 'render_backend_base.dart';

RenderBackend createRenderBackend() => const IoFfmpegRenderBackend();

class _VideoEncoder {
  const _VideoEncoder(this.name, this.hardware, this.arguments);

  final String name;
  final bool hardware;
  final List<String> arguments;
}

class IoFfmpegRenderBackend extends RenderBackend {
  const IoFfmpegRenderBackend();

  static final Map<String, _VideoEncoder> _renderEncoders = {};
  static Future<_VideoEncoder>? _cachedEncoder;

  static const _softwareDesktopEncoder = _VideoEncoder('libx264', false, [
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-crf',
    '22',
  ]);

  static const _softwareMobileEncoder = _VideoEncoder('mpeg4', false, [
    '-c:v',
    'mpeg4',
    '-q:v',
    '4',
  ]);

  Future<String?> _findBinary(String name) async {
    if (Platform.isAndroid || Platform.isIOS) return null;
    final executable = Platform.isWindows ? '$name.exe' : name;
    final candidates = <String>[
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
        '${File(Platform.resolvedExecutable).parent.path}'
            '${Platform.pathSeparator}$executable',
      if (Platform.isMacOS) '/opt/homebrew/bin/$name',
      if (Platform.isMacOS) '/usr/local/bin/$name',
      if (Platform.isLinux) '/usr/bin/$name',
      executable,
    ];
    for (final candidate in candidates) {
      if (candidate.contains(Platform.pathSeparator) &&
          !await File(candidate).exists()) {
        continue;
      }
      try {
        final result = await Process.run(candidate, ['-version']);
        if (result.exitCode == 0) return candidate;
      } catch (_) {
        // Continue through the allowlisted lookup locations.
      }
    }
    return null;
  }

  List<_VideoEncoder> _hardwareEncoderCandidates() {
    if (Platform.isMacOS || Platform.isIOS) {
      return const [
        _VideoEncoder('h264_videotoolbox', true, [
          '-c:v',
          'h264_videotoolbox',
          '-allow_sw',
          '0',
          '-realtime',
          '0',
          '-b:v',
          '8M',
          '-maxrate',
          '12M',
          '-bufsize',
          '16M',
          '-profile:v',
          'high',
        ]),
      ];
    }
    if (Platform.isAndroid) {
      return const [
        _VideoEncoder('h264_mediacodec', true, [
          '-c:v',
          'h264_mediacodec',
          '-b:v',
          '6M',
          '-profile:v',
          'high',
        ]),
      ];
    }
    if (Platform.isWindows) {
      return const [
        _VideoEncoder('h264_nvenc', true, [
          '-c:v',
          'h264_nvenc',
          '-preset',
          'p5',
          '-tune',
          'hq',
          '-rc',
          'vbr',
          '-cq',
          '22',
          '-b:v',
          '6M',
          '-maxrate',
          '10M',
          '-bufsize',
          '12M',
        ]),
        _VideoEncoder('h264_qsv', true, [
          '-c:v',
          'h264_qsv',
          '-preset',
          'medium',
          '-global_quality',
          '23',
        ]),
        _VideoEncoder('h264_amf', true, [
          '-c:v',
          'h264_amf',
          '-quality',
          'balanced',
          '-rc',
          'cqp',
          '-qp_i',
          '22',
          '-qp_p',
          '24',
        ]),
      ];
    }
    if (Platform.isLinux) {
      return const [
        _VideoEncoder('h264_nvenc', true, [
          '-c:v',
          'h264_nvenc',
          '-preset',
          'p5',
          '-tune',
          'hq',
          '-rc',
          'vbr',
          '-cq',
          '22',
          '-b:v',
          '6M',
        ]),
        _VideoEncoder('h264_qsv', true, [
          '-c:v',
          'h264_qsv',
          '-preset',
          'medium',
          '-global_quality',
          '23',
        ]),
      ];
    }
    return const [];
  }

  List<String> _encoderProbeArguments(_VideoEncoder encoder) => [
    '-hide_banner',
    '-loglevel',
    'error',
    '-f',
    'lavfi',
    '-i',
    'color=c=black:s=64x64:r=30:d=0.12',
    '-frames:v',
    '2',
    '-pix_fmt',
    'yuv420p',
    ...encoder.arguments,
    '-an',
    '-f',
    'null',
    '-',
  ];

  Future<bool> _probeEncoder(
    _VideoEncoder encoder, {
    required bool useNativeKit,
    String? ffmpeg,
  }) async {
    try {
      if (useNativeKit) {
        final session = await FFmpegKit.executeWithArguments(
          _encoderProbeArguments(encoder),
        );
        return ReturnCode.isSuccess(await session.getReturnCode());
      }
      if (ffmpeg == null) return false;
      final result = await Process.run(ffmpeg, _encoderProbeArguments(encoder));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<_VideoEncoder> _selectVideoEncoder({
    required bool useNativeKit,
    String? ffmpeg,
  }) {
    if (Platform.environment['TRIPWEAVE_DISABLE_HARDWARE'] == '1') {
      return Future.value(
        useNativeKit || Platform.isMacOS
            ? _softwareMobileEncoder
            : _softwareDesktopEncoder,
      );
    }
    return _cachedEncoder ??= _discoverVideoEncoder(
      useNativeKit: useNativeKit,
      ffmpeg: ffmpeg,
    );
  }

  Future<_VideoEncoder> _discoverVideoEncoder({
    required bool useNativeKit,
    String? ffmpeg,
  }) async {
    for (final encoder in _hardwareEncoderCandidates()) {
      if (await _probeEncoder(
        encoder,
        useNativeKit: useNativeKit,
        ffmpeg: ffmpeg,
      )) {
        return encoder;
      }
    }
    return useNativeKit || Platform.isMacOS
        ? _softwareMobileEncoder
        : _softwareDesktopEncoder;
  }

  Future<bool> _hasAudioStream(String path) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final session = await FFprobeKit.executeWithArguments([
        '-v',
        'error',
        '-select_streams',
        'a:0',
        '-show_entries',
        'stream=index',
        '-of',
        'csv=p=0',
        path,
      ]);
      return ReturnCode.isSuccess(await session.getReturnCode()) &&
          (await session.getOutput())?.trim().isNotEmpty == true;
    }
    final ffprobe = await _findBinary('ffprobe');
    if (ffprobe == null) return false;
    final result = await Process.run(ffprobe, [
      '-v',
      'error',
      '-select_streams',
      'a:0',
      '-show_entries',
      'stream=index',
      '-of',
      'csv=p=0',
      path,
    ]);
    return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
  }

  @override
  Future<String?> availability() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return null;
    }
    return await _findBinary('ffmpeg') == null
        ? '没有找到 FFmpeg。桌面端可安装 FFmpeg，或在发行版中随应用打包。'
        : null;
  }

  @override
  Future<Uint8List?> extractVideoFrame(MediaItem asset) async {
    if (asset.kind != MediaKind.video) return null;
    final workspace = await Directory.systemTemp.createTemp('tripweave-frame-');
    final extension = asset.name.contains('.')
        ? asset.name.substring(asset.name.lastIndexOf('.')).toLowerCase()
        : '.mp4';
    final input = asset.hasLocalSource
        ? File(asset.sourcePath!)
        : File('${workspace.path}/input$extension');
    final output = File('${workspace.path}/frame.jpg');
    if (!asset.hasLocalSource) {
      await input.writeAsBytes(asset.bytes, flush: true);
    }
    if (!await input.exists()) {
      throw StateError('素材文件已经不可用，请重新导入 ${asset.name}。');
    }
    final args = [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-ss',
      '1',
      '-i',
      input.path,
      '-frames:v',
      '1',
      '-vf',
      'scale=512:-2',
      '-q:v',
      '4',
      output.path,
    ];
    if (Platform.isAndroid || Platform.isIOS) {
      final session = await FFmpegKit.executeWithArguments(args);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return null;
    } else {
      final ffmpeg = await _findBinary('ffmpeg');
      if (ffmpeg == null) return null;
      final result = await Process.run(ffmpeg, args);
      if (result.exitCode != 0) return null;
    }
    return await output.exists() ? output.readAsBytes() : null;
  }

  @override
  Future<String> render({
    required AgentEditPlan plan,
    required List<MediaItem> assets,
    Uint8List? musicBytes,
    void Function(double progress)? onProgress,
  }) async {
    final useNativeKit = Platform.isAndroid || Platform.isIOS;
    final ffmpeg = useNativeKit ? null : await _findBinary('ffmpeg');
    if (!useNativeKit && ffmpeg == null) {
      throw StateError('没有找到可执行的 FFmpeg。');
    }
    final workspace = await Directory.systemTemp.createTemp('tripweave-agent-');
    final assetById = {for (final asset in assets) asset.id: asset};
    final inputs = <String>[];
    final filters = <String>[];

    final dimensions = switch (plan.ratio) {
      VlogRatio.portrait => (720, 1280),
      VlogRatio.landscape => (1280, 720),
      VlogRatio.square => (960, 960),
    };

    for (var index = 0; index < plan.clips.length; index++) {
      final clip = plan.clips[index];
      final asset = assetById[clip.mediaId];
      if (asset == null) throw StateError('剪辑计划引用了不存在的素材。');
      final safeExtension = asset.name.contains('.')
          ? asset.name.substring(asset.name.lastIndexOf('.')).toLowerCase()
          : asset.kind == MediaKind.image
          ? '.jpg'
          : '.mp4';
      final input = asset.hasLocalSource
          ? File(asset.sourcePath!)
          : File('${workspace.path}/input-$index$safeExtension');
      if (!asset.hasLocalSource) {
        await input.writeAsBytes(asset.bytes, flush: true);
      }
      if (!await input.exists()) {
        throw StateError('素材文件已经不可用，请重新导入 ${asset.name}。');
      }
      final seconds = (clip.durationMs / 1000).toStringAsFixed(3);
      if (asset.kind == MediaKind.image) {
        inputs.addAll(['-loop', '1', '-t', seconds, '-i', input.path]);
      } else {
        inputs.addAll([
          '-ss',
          (clip.startMs / 1000).toStringAsFixed(3),
          '-t',
          seconds,
          '-i',
          input.path,
        ]);
      }
      filters.add(
        '[$index:v]scale=${dimensions.$1}:${dimensions.$2}:'
        'force_original_aspect_ratio=increase,'
        'crop=${dimensions.$1}:${dimensions.$2},setsar=1,fps=30,'
        'format=yuv420p,trim=duration=$seconds,setpts=PTS-STARTPTS[v$index]',
      );
      final hasSourceAudio =
          asset.kind == MediaKind.video && await _hasAudioStream(input.path);
      if (hasSourceAudio) {
        filters.add(
          '[$index:a]atrim=duration=$seconds,asetpts=PTS-STARTPTS,'
          'aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[a$index]',
        );
      } else {
        filters.add(
          'anullsrc=channel_layout=stereo:sample_rate=48000,'
          'atrim=duration=$seconds,asetpts=PTS-STARTPTS[a$index]',
        );
      }
    }

    final musicData = musicBytes ?? await MusicCatalog.loadBytes(plan.musicId);
    final musicFile = File('${workspace.path}/music.mp3');
    await musicFile.writeAsBytes(musicData, flush: true);
    inputs.addAll(['-stream_loop', '-1', '-i', musicFile.path]);

    final concatInputs = List.generate(
      plan.clips.length,
      (index) => '[v$index][a$index]',
    ).join();
    filters.add(
      '$concatInputs concat=n=${plan.clips.length}:v=1:a=1[outv][sourcea]',
    );
    final totalSeconds = (plan.totalDurationMs / 1000).toStringAsFixed(3);
    final fadeOut = (plan.totalDurationMs / 1000 - 2)
        .clamp(0.0, double.infinity)
        .toStringAsFixed(3);
    filters.add(
      '[${plan.clips.length}:a]volume=0.18,'
      'atrim=duration=$totalSeconds,asetpts=PTS-STARTPTS,'
      'afade=t=in:st=0:d=1.2,afade=t=out:st=$fadeOut:d=2[music];'
      '[sourcea]volume=0.95[source];'
      '[source][music]amix=inputs=2:duration=first:dropout_transition=2[aout]',
    );
    final output = File('${workspace.path}/tripweave-agent.mp4');
    final selected = await _selectVideoEncoder(
      useNativeKit: useNativeKit,
      ffmpeg: ffmpeg,
    );
    final fallback = useNativeKit
        ? _softwareMobileEncoder
        : _softwareDesktopEncoder;
    final attempts = selected.hardware ? [selected, fallback] : [selected];
    Object? lastFailure;
    for (final encoder in attempts) {
      if (await output.exists()) await output.delete();
      final args = <String>[
        '-hide_banner',
        '-loglevel',
        'error',
        if (!useNativeKit) ...['-progress', 'pipe:1', '-nostats'],
        '-y',
        ...inputs,
        '-filter_complex',
        filters.join(';'),
        '-map',
        '[outv]',
        '-map',
        '[aout]',
        '-pix_fmt',
        'yuv420p',
        ...encoder.arguments,
        '-c:a',
        'aac',
        '-b:a',
        '160k',
        '-shortest',
        '-movflags',
        '+faststart',
        output.path,
      ];
      try {
        if (useNativeKit) {
          await _executeNativeRender(
            args: args,
            output: output,
            totalDurationMs: plan.totalDurationMs,
            onProgress: onProgress,
          );
        } else {
          await _executeDesktopRender(
            ffmpeg: ffmpeg!,
            args: args,
            output: output,
            totalDurationMs: plan.totalDurationMs,
            onProgress: onProgress,
          );
        }
        _renderEncoders[output.path] = encoder;
        onProgress?.call(1);
        return output.path;
      } catch (exception) {
        lastFailure = exception;
        if (encoder.hardware) {
          _cachedEncoder = Future.value(fallback);
        }
      }
    }
    throw StateError('FFmpeg 硬件编码与安全回退均失败：$lastFailure');
  }

  Future<void> _executeNativeRender({
    required List<String> args,
    required File output,
    required int totalDurationMs,
    void Function(double progress)? onProgress,
  }) async {
    final completer = Completer<void>();
    Object? failure;
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          failure = StateError(
            'FFmpeg Kit 渲染失败：${await session.getAllLogsAsString()}',
          );
        }
        completer.complete();
      },
      null,
      (statistics) {
        if (totalDurationMs > 0) {
          onProgress?.call(
            (statistics.getTime() / totalDurationMs).clamp(0.0, .99),
          );
        }
      },
    );
    await completer.future;
    if (failure != null || !await output.exists()) {
      throw failure ?? StateError('FFmpeg Kit 没有生成输出文件。');
    }
  }

  Future<void> _executeDesktopRender({
    required String ffmpeg,
    required List<String> args,
    required File output,
    required int totalDurationMs,
    void Function(double progress)? onProgress,
  }) async {
    final process = await Process.start(ffmpeg, args);
    final errors = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(errors.write)
        .asFuture<void>();
    final expectedMicroseconds = totalDurationMs * 1000;
    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('out_time_ms=')) {
        final value = int.tryParse(line.substring('out_time_ms='.length));
        if (value != null && expectedMicroseconds > 0) {
          onProgress?.call((value / expectedMicroseconds).clamp(0.0, .99));
        }
      }
    }
    final exitCode = await process.exitCode;
    await stderrDone;
    if (exitCode != 0 || !await output.exists()) {
      throw StateError('FFmpeg 渲染失败：$errors');
    }
  }

  @override
  Future<String> validate(String outputPath) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final session = await FFprobeKit.executeWithArguments([
        '-v',
        'error',
        '-show_entries',
        'format=duration,size:stream=codec_name,width,height,r_frame_rate',
        '-of',
        'json',
        outputPath,
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        throw StateError(
          'FFprobe Kit 验证失败：${await session.getAllLogsAsString()}',
        );
      }
      return _withEncoderMetadata(
        outputPath,
        await session.getOutput() ?? '{}',
      );
    }
    final ffprobe = await _findBinary('ffprobe');
    if (ffprobe == null) throw StateError('没有找到可执行的 FFprobe。');
    final result = await Process.run(ffprobe, [
      '-v',
      'error',
      '-show_entries',
      'format=duration,size:stream=codec_name,width,height,r_frame_rate',
      '-of',
      'json',
      outputPath,
    ]);
    if (result.exitCode != 0) {
      throw StateError('FFprobe 验证失败：${result.stderr}');
    }
    return _withEncoderMetadata(outputPath, result.stdout.toString());
  }

  String _withEncoderMetadata(String outputPath, String probeJson) {
    final payload = jsonDecode(probeJson) as Map<String, dynamic>;
    final encoder = _renderEncoders[outputPath];
    payload['tripweave'] = {
      'encoder': encoder?.name ?? 'unknown',
      'hardware': encoder?.hardware ?? false,
    };
    return jsonEncode(payload);
  }
}
