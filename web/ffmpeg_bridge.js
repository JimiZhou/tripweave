(() => {
  let ffmpeg;
  let loading;

  const fromBase64 = (value) => {
    const binary = atob(value);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return bytes;
  };

  const toBase64 = (bytes) => {
    let binary = "";
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
    }
    return btoa(binary);
  };

  const ensureLoaded = async () => {
    if (ffmpeg?.loaded) return ffmpeg;
    if (!loading) {
      loading = (async () => {
        ffmpeg = new self.FFmpegWASM.FFmpeg();
        await ffmpeg.load({
          coreURL: new URL("ffmpeg/ffmpeg-core.js", document.baseURI).href,
          wasmURL: new URL("ffmpeg/ffmpeg-core.wasm", document.baseURI).href,
        });
        return ffmpeg;
      })();
    }
    return loading;
  };

  const renderWithFfmpeg = async (requestJson, progressCallback) => {
    const request = JSON.parse(requestJson);
    const engine = await ensureLoaded();
    const inputArgs = [];
    const filters = [];
    const createdFiles = [];
    const decoder = new TextDecoder();

    const progress = ({ progress: value }) => {
      if (typeof progressCallback === "function") {
        progressCallback(Math.max(0, Math.min(0.99, value || 0)));
      }
    };
    engine.on("progress", progress);

    try {
      for (let i = 0; i < request.inputs.length; i += 1) {
        const input = request.inputs[i];
        const name = `input-${i}.${input.extension}`;
        createdFiles.push(name);
        await engine.writeFile(name, fromBase64(input.base64));
        const seconds = (input.durationMs / 1000).toFixed(3);
        if (input.kind === "image") {
          inputArgs.push("-loop", "1", "-t", seconds, "-i", name);
        } else {
          inputArgs.push(
            "-ss",
            (input.startMs / 1000).toFixed(3),
            "-t",
            seconds,
            "-i",
            name,
          );
        }
        filters.push(
          `[${i}:v]scale=${request.width}:${request.height}:force_original_aspect_ratio=increase,` +
            `crop=${request.width}:${request.height},setsar=1,fps=30,format=yuv420p,setpts=PTS-STARTPTS[v${i}]`,
        );

        let hasAudio = false;
        if (input.kind === "video") {
          const probe = `probe-${i}.txt`;
          createdFiles.push(probe);
          await engine.ffprobe([
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=index",
            "-of",
            "csv=p=0",
            name,
            "-o",
            probe,
          ]);
          try {
            hasAudio = decoder.decode(await engine.readFile(probe)).trim().length > 0;
          } catch (_) {
            hasAudio = false;
          }
        }
        if (hasAudio) {
          filters.push(
            `[${i}:a]atrim=duration=${seconds},asetpts=PTS-STARTPTS,` +
              `aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[a${i}]`,
          );
        } else {
          filters.push(
            `anullsrc=channel_layout=stereo:sample_rate=48000,atrim=duration=${seconds},` +
              `asetpts=PTS-STARTPTS[a${i}]`,
          );
        }
      }

      const musicName = "music.mp3";
      const outputName = "tripweave-output.mp4";
      createdFiles.push(musicName, outputName);
      await engine.writeFile(musicName, fromBase64(request.musicBase64));
      inputArgs.push("-stream_loop", "-1", "-i", musicName);

      const concat = request.inputs.map((_, i) => `[v${i}][a${i}]`).join("");
      filters.push(`${concat}concat=n=${request.inputs.length}:v=1:a=1[outv][sourcea]`);
      const totalSeconds = (request.totalDurationMs / 1000).toFixed(3);
      const fadeOut = Math.max(0, request.totalDurationMs / 1000 - 2).toFixed(3);
      filters.push(
        `[${request.inputs.length}:a]volume=0.18,atrim=duration=${totalSeconds},asetpts=PTS-STARTPTS,` +
          `afade=t=in:st=0:d=1.2,afade=t=out:st=${fadeOut}:d=2[music];` +
          `[sourcea]volume=0.95[source];[source][music]amix=inputs=2:duration=first:dropout_transition=2[aout]`,
      );

      const exitCode = await engine.exec([
        ...inputArgs,
        "-filter_complex",
        filters.join(";"),
        "-map",
        "[outv]",
        "-map",
        "[aout]",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-crf",
        "26",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-shortest",
        "-movflags",
        "+faststart",
        outputName,
      ]);
      if (exitCode !== 0) throw new Error(`ffmpeg.wasm exited with ${exitCode}`);
      const output = await engine.readFile(outputName);
      progressCallback?.(1);
      return JSON.stringify({
        dataUrl: `data:video/mp4;base64,${toBase64(output)}`,
        duration: request.totalDurationMs / 1000,
        size: output.byteLength,
        width: request.width,
        height: request.height,
        encoder: "ffmpeg-wasm-libx264",
        hardware: false,
        engine: "ffmpeg.wasm",
      });
    } finally {
      engine.off("progress", progress);
      for (const name of createdFiles) {
        try {
          await engine.deleteFile(name);
        } catch (_) {
          // Best-effort cleanup of the in-memory wasm file system.
        }
      }
    }
  };

  const waitForEvent = (target, event, errorEvent = "error") =>
    new Promise((resolve, reject) => {
      const clean = () => {
        target.removeEventListener(event, done);
        target.removeEventListener(errorEvent, failed);
      };
      const done = () => {
        clean();
        resolve();
      };
      const failed = () => {
        clean();
        reject(new Error(`Media element failed while waiting for ${event}`));
      };
      target.addEventListener(event, done, { once: true });
      target.addEventListener(errorEvent, failed, { once: true });
    });

  const nextAnimationFrame = () =>
    new Promise((resolve) => requestAnimationFrame(resolve));

  const mimeForInput = (input) => {
    const extension = String(input.extension || "").toLowerCase();
    if (input.kind === "image") {
      if (extension === "png") return "image/png";
      if (extension === "webp") return "image/webp";
      return "image/jpeg";
    }
    if (extension === "webm") return "video/webm";
    if (extension === "mov") return "video/quicktime";
    return "video/mp4";
  };

  const drawCover = (context, source, width, height) => {
    const sourceWidth = source.videoWidth || source.naturalWidth || source.width;
    const sourceHeight = source.videoHeight || source.naturalHeight || source.height;
    if (!sourceWidth || !sourceHeight) return;
    const scale = Math.max(width / sourceWidth, height / sourceHeight);
    const cropWidth = width / scale;
    const cropHeight = height / scale;
    const sourceX = (sourceWidth - cropWidth) / 2;
    const sourceY = (sourceHeight - cropHeight) / 2;
    context.fillStyle = "black";
    context.fillRect(0, 0, width, height);
    context.drawImage(
      source,
      sourceX,
      sourceY,
      cropWidth,
      cropHeight,
      0,
      0,
      width,
      height,
    );
  };

  const preferredMp4MimeType = () => {
    const candidates = [
      "video/mp4;codecs=avc1.42E01E,mp4a.40.2",
      "video/mp4;codecs=avc1.42E01E",
      "video/mp4",
    ];
    return candidates.find((value) => MediaRecorder.isTypeSupported(value)) || "";
  };

  const supportsHardwareWebRender = async (request) => {
    if (
      self.tripweaveDisableHardware === true ||
      typeof document === "undefined" ||
      typeof MediaRecorder !== "function" ||
      typeof VideoEncoder !== "function" ||
      typeof AudioContext !== "function" ||
      typeof HTMLCanvasElement.prototype.captureStream !== "function" ||
      !preferredMp4MimeType()
    ) {
      return false;
    }
    const support = await VideoEncoder.isConfigSupported({
      codec: "avc1.42001f",
      width: request.width,
      height: request.height,
      bitrate: 8_000_000,
      framerate: 30,
      latencyMode: "realtime",
      hardwareAcceleration: "prefer-hardware",
    });
    return support.supported === true;
  };

  const prepareBrowserInput = async (input, audioContext, destination) => {
    const bytes = fromBase64(input.base64);
    const blob = new Blob([bytes], { type: mimeForInput(input) });
    const url = URL.createObjectURL(blob);
    if (input.kind === "image") {
      const image = new Image();
      image.src = url;
      if (typeof image.decode === "function") {
        await image.decode();
      } else {
        await waitForEvent(image, "load");
      }
      return { input, source: image, url, audioNode: null };
    }

    const video = document.createElement("video");
    video.src = url;
    video.preload = "auto";
    video.playsInline = true;
    video.disablePictureInPicture = true;
    await waitForEvent(video, "loadedmetadata");
    const startSeconds = Math.max(0, input.startMs / 1000);
    if (Math.abs(video.currentTime - startSeconds) > 0.01) {
      video.currentTime = Math.min(startSeconds, Math.max(0, video.duration - 0.05));
      await waitForEvent(video, "seeked");
    }
    const sourceNode = audioContext.createMediaElementSource(video);
    const gain = audioContext.createGain();
    gain.gain.value = 0.95;
    sourceNode.connect(gain).connect(destination);
    return { input, source: video, url, audioNode: sourceNode };
  };

  const renderWithBrowserHardware = async (requestJson, progressCallback) => {
    const request = JSON.parse(requestJson);
    if (!(await supportsHardwareWebRender(request))) {
      throw new Error("Browser H.264 hardware pipeline is unavailable");
    }

    const startedAt = performance.now();
    const canvas = document.createElement("canvas");
    canvas.width = request.width;
    canvas.height = request.height;
    const context = canvas.getContext("2d", { alpha: false, desynchronized: true });
    if (!context) throw new Error("Canvas renderer is unavailable");

    const audioContext = new AudioContext({ sampleRate: 48000, latencyHint: "playback" });
    await audioContext.resume();
    const destination = audioContext.createMediaStreamDestination();
    const prepared = [];
    const urls = [];
    let musicSource;
    try {
      for (const input of request.inputs) {
        const item = await prepareBrowserInput(input, audioContext, destination);
        prepared.push(item);
        urls.push(item.url);
      }

      const musicBytes = fromBase64(request.musicBase64);
      const musicBuffer = await audioContext.decodeAudioData(
        musicBytes.buffer.slice(
          musicBytes.byteOffset,
          musicBytes.byteOffset + musicBytes.byteLength,
        ),
      );
      musicSource = audioContext.createBufferSource();
      musicSource.buffer = musicBuffer;
      musicSource.loop = true;
      const musicGain = audioContext.createGain();
      const audioStart = audioContext.currentTime + 0.04;
      const durationSeconds = request.totalDurationMs / 1000;
      const fadeOutStart = Math.max(0, durationSeconds - 2);
      musicGain.gain.setValueAtTime(0, audioStart);
      musicGain.gain.linearRampToValueAtTime(0.18, audioStart + Math.min(1.2, durationSeconds));
      musicGain.gain.setValueAtTime(0.18, audioStart + fadeOutStart);
      musicGain.gain.linearRampToValueAtTime(0, audioStart + durationSeconds);
      musicSource.connect(musicGain).connect(destination);

      const canvasStream = canvas.captureStream(0);
      const canvasVideoTrack = canvasStream.getVideoTracks()[0];
      const combinedStream = new MediaStream([
        ...canvasStream.getVideoTracks(),
        ...destination.stream.getAudioTracks(),
      ]);
      const mimeType = preferredMp4MimeType();
      const chunks = [];
      const recorder = new MediaRecorder(combinedStream, {
        mimeType,
        videoBitsPerSecond: 8_000_000,
        audioBitsPerSecond: 160_000,
      });
      const stopped = new Promise((resolve, reject) => {
        recorder.addEventListener("dataavailable", (event) => {
          if (event.data?.size) chunks.push(event.data);
        });
        recorder.addEventListener("stop", resolve, { once: true });
        recorder.addEventListener("error", () => reject(recorder.error), { once: true });
      });

      drawCover(context, prepared[0].source, request.width, request.height);
      recorder.start(250);
      canvasVideoTrack.requestFrame?.();
      musicSource.start(audioStart);
      let completedMs = 0;
      for (const item of prepared) {
        const durationMs = item.input.durationMs;
        if (item.input.kind === "video") {
          await item.source.play();
        }
        const clipStartedAt = performance.now();
        const frameCount = Math.max(1, Math.ceil((durationMs * 30) / 1000));
        for (let frame = 0; frame < frameCount; frame += 1) {
          const targetElapsed = (frame * 1000) / 30;
          while (performance.now() - clipStartedAt < targetElapsed) {
            await nextAnimationFrame();
          }
          const elapsed = performance.now() - clipStartedAt;
          drawCover(context, item.source, request.width, request.height);
          canvasVideoTrack.requestFrame?.();
          progressCallback?.(
            Math.max(0, Math.min(0.99, (completedMs + Math.min(elapsed, durationMs)) / request.totalDurationMs)),
          );
        }
        while (performance.now() - clipStartedAt < durationMs) {
          await nextAnimationFrame();
        }
        if (item.input.kind === "video") item.source.pause();
        completedMs += durationMs;
      }
      canvasVideoTrack.requestFrame?.();
      await nextAnimationFrame();
      recorder.stop();
      await stopped;
      musicSource.stop();
      combinedStream.getTracks().forEach((track) => track.stop());

      const outputBlob = new Blob(chunks, { type: mimeType });
      const output = new Uint8Array(await outputBlob.arrayBuffer());
      if (!output.byteLength) throw new Error("Browser encoder returned an empty file");
      progressCallback?.(1);
      return JSON.stringify({
        dataUrl: `data:video/mp4;base64,${toBase64(output)}`,
        duration: request.totalDurationMs / 1000,
        size: output.byteLength,
        width: request.width,
        height: request.height,
        encoder: "browser-h264-hardware",
        hardware: true,
        engine: "WebCodecs capability + MediaRecorder",
        elapsedMs: Math.round(performance.now() - startedAt),
        mimeType,
      });
    } finally {
      for (const item of prepared) {
        if (item.input.kind === "video") item.source.pause();
      }
      if (musicSource) {
        try {
          musicSource.stop();
        } catch (_) {
          // It may already be stopped after a successful render.
        }
      }
      urls.forEach((url) => URL.revokeObjectURL(url));
      await audioContext.close();
    }
  };

  self.tripweaveRender = async (requestJson, progressCallback) => {
    try {
      return await renderWithBrowserHardware(requestJson, progressCallback);
    } catch (hardwareError) {
      console.info("TripWeave hardware render unavailable; using ffmpeg.wasm fallback", hardwareError);
      return renderWithFfmpeg(requestJson, progressCallback);
    }
  };

  self.tripweaveExtractFrame = async (requestJson) => {
    const request = JSON.parse(requestJson);
    const engine = await ensureLoaded();
    const inputName = `frame-input.${request.extension}`;
    const outputName = "frame-output.jpg";
    try {
      await engine.writeFile(inputName, fromBase64(request.base64));
      const exitCode = await engine.exec([
        "-ss",
        "1",
        "-i",
        inputName,
        "-frames:v",
        "1",
        "-vf",
        "scale=512:-2",
        "-q:v",
        "4",
        outputName,
      ]);
      if (exitCode !== 0) return "";
      return toBase64(await engine.readFile(outputName));
    } finally {
      for (const name of [inputName, outputName]) {
        try {
          await engine.deleteFile(name);
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  };
})();
