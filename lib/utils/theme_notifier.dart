import 'package:flutter/material.dart';

/// Global theme notifier that can be accessed from anywhere
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Global accent color notifier
final ValueNotifier<Color> accentColorNotifier = ValueNotifier<Color>(const Color(0xFFE5B3B3));

/// Helper function to toggle theme
void toggleTheme() {
  themeNotifier.value = themeNotifier.value == ThemeMode.light 
      ? ThemeMode.dark 
      : ThemeMode.light;
}

/// Helper function to update accent color
void updateAccentColor(Color color) {
  accentColorNotifier.value = color;
}
