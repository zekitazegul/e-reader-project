import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function() listenReaderFullscreen(void Function(bool) onChanged) {
  final listener = ((web.Event event) => onChanged(
    web.document.fullscreenElement != null,
  )).toJS;
  web.document.addEventListener('fullscreenchange', listener);
  return () => web.document.removeEventListener('fullscreenchange', listener);
}

Future<void> setReaderFullscreen(bool enabled) async {
  if (enabled && web.document.fullscreenElement == null) {
    await web.document.documentElement!.requestFullscreen().toDart;
  } else if (!enabled && web.document.fullscreenElement != null) {
    await web.document.exitFullscreen().toDart;
  }
}
