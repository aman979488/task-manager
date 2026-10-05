import 'home_screen_shortcut_stub.dart'
    if (dart.library.js_interop) 'home_screen_shortcut_web.dart'
    as platform;

Future<bool> installHomeScreenShortcut() =>
    platform.installHomeScreenShortcut();
