import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

VoidCallback listenReaderFullscreen(ValueChanged<bool> onChanged) {
  if (defaultTargetPlatform != TargetPlatform.macOS) return () {};
  const channel = MethodChannel('e_reader/window');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'fullscreenChanged' && call.arguments is bool) {
      onChanged(call.arguments as bool);
    }
  });
  return () => channel.setMethodCallHandler(null);
}

Future<void> setReaderFullscreen(bool enabled) async {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await const MethodChannel('e_reader/window')
        .invokeMethod<void>('setFullscreen', enabled);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await const MethodChannel('e_reader/chrome')
          .invokeMethod<void>('setReaderFullscreen', enabled);
    } on MissingPluginException {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
  } else {
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }
}
