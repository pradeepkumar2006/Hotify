import 'package:flutter/material.dart';

/// Global theme notifier that can be accessed from anywhere
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Helper function to toggle theme
void toggleTheme() {
  themeNotifier.value = themeNotifier.value == ThemeMode.light 
      ? ThemeMode.dark 
      : ThemeMode.light;
}
