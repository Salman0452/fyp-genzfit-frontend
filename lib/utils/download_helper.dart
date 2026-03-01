/// Conditional import: uses dart:html on web, stub on all other platforms.
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
