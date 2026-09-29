library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/app/theme/app_animations.dart';

void main() {
  group('InteractionProfile', () {
    test('dynamic tem duration 280ms', () {
      expect(
        InteractionProfile.dynamic.duration,
        const Duration(milliseconds: 280),
      );
    });

    test('soft tem duration 450ms (padrão)', () {
      expect(
        InteractionProfile.soft.duration,
        const Duration(milliseconds: 450),
      );
    });

    test('mist tem duration 520ms', () {
      expect(
        InteractionProfile.mist.duration,
        const Duration(milliseconds: 520),
      );
    });

    test('dynamic usa Curves.easeOutBack', () {
      expect(InteractionProfile.dynamic.curve, Curves.easeOutBack);
    });

    test('soft usa Curves.easeInOutCubic', () {
      expect(InteractionProfile.soft.curve, Curves.easeInOutCubic);
    });

    test('mist usa Curves.easeOutQuart', () {
      expect(InteractionProfile.mist.curve, Curves.easeOutQuart);
    });
  });

  group('DockAnimation', () {
    test('hoverScale = 1.25', () {
      expect(DockAnimation.hoverScale, 1.25);
    });

    test('hoverLift = -4', () {
      expect(DockAnimation.hoverLift, -4);
    });

    test('duration = 300ms', () {
      expect(DockAnimation.duration, const Duration(milliseconds: 300));
    });
  });
}
