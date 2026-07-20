import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/src/theme.dart';

void main() {
  test('light surfaces default to readable dark text', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.light);
    expect(theme.textTheme.displayMedium?.color, TripColors.ink);
    expect(theme.textTheme.bodyMedium?.color, TripColors.ink);
    expect(theme.textTheme.labelLarge?.color, TripColors.ink);
  });
}
