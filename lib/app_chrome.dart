import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_language.dart';
import 'app_navigation.dart';

Future<void> hideSystemNavigation() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel('e_reader/chrome')
        .invokeMethod<void>('hideNavigation');
  } catch (_) {
    /* Non-Android widget tests have no native chrome channel. */
  }
}

class AppChrome extends StatefulWidget {
  const AppChrome({super.key, required this.child});
  final Widget child;
  @override
  State<AppChrome> createState() => _AppChromeState();
}

class _AppChromeState extends State<AppChrome> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => hideSystemNavigation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) hideSystemNavigation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> back() async {
    final navigator = AppNavigation.instance.navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) => Overlay.wrap(
    child: ValueListenableBuilder<bool>(
      valueListenable: AppNavigation.instance.fullscreen,
      builder: (context, _, _) => Column(
        children: [
          Expanded(child: widget.child),
          if (LanguageScope.of(context)?.hasSelection ?? true)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          key: const ValueKey('app-left-menu'),
                          tooltip: tr(context, 'Ana menü'),
                          icon: const Icon(Icons.menu),
                          onPressed: () =>
                              AppNavigation.instance.showMenu?.call(),
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          key: const ValueKey('app-home'),
                          tooltip: tr(context, 'Ana sayfa'),
                          icon: const Icon(Icons.home_outlined),
                          onPressed: () =>
                              AppNavigation.instance.showHome?.call(),
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          key: const ValueKey('app-back'),
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: back,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
