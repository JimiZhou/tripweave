import 'render_backend_base.dart';
import 'render_backend_stub.dart'
    if (dart.library.io) 'render_backend_io.dart'
    if (dart.library.js_interop) 'render_backend_web.dart'
    as implementation;

RenderBackend createRenderBackend() => implementation.createRenderBackend();
