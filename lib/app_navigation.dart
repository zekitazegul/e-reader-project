import 'package:flutter/material.dart';

class AppNavigation {
  AppNavigation._();
  static final instance = AppNavigation._();
  final navigatorKey = GlobalKey<NavigatorState>();
  final fullscreen = ValueNotifier<bool>(false);
  Object? libraryOwner;
  VoidCallback? showBooks,
      showHome,
      showMenu,
      addBooks,
      chooseFolder,
      showSettings;
}
