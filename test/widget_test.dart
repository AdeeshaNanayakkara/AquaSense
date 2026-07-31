// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pump state boolean parsing test', () {
    bool parsePumpState(dynamic val) {
      if (val is bool) return val;
      if (val is num) return val == 1;
      if (val is String) {
        final lower = val.trim().toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'on';
      }
      return false;
    }

    expect(parsePumpState(true), true);
    expect(parsePumpState(false), false);
    expect(parsePumpState(1), true);
    expect(parsePumpState(0), false);
    expect(parsePumpState('true'), true);
    expect(parsePumpState('false'), false);
    expect(parsePumpState('1'), true);
    expect(parsePumpState('0'), false);
    expect(parsePumpState(null), false);
  });
}
