import 'dart:js_interop';

@JS('window.promptTaskManagerInstall')
external JSPromise<JSBoolean> _promptTaskManagerInstall();

Future<bool> installHomeScreenShortcut() async =>
    (await _promptTaskManagerInstall().toDart).toDart;
