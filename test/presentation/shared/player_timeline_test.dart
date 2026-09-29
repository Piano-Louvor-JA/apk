library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/player_timeline.dart';

void main() {
  testWidgets('exibe posição e duração formatadas e seek ao soltar', (
    tester,
  ) async {
    final positions = StreamController<Duration>.broadcast();
    final durations = StreamController<Duration>.broadcast();
    Duration? sought;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTimeline(
            positionStream: positions.stream,
            durationStream: durations.stream,
            onSeek: (d) async => sought = d,
          ),
        ),
      ),
    );

    positions.add(const Duration(minutes: 1, seconds: 5));
    durations.add(const Duration(minutes: 3, seconds: 20));
    await tester.pumpAndSettle();

    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('03:20'), findsOneWidget);

    // Arrasta o slider até o fim e solta: seek para ~duração total.
    final sliderCenter = tester.getCenter(find.byType(Slider));
    final sliderRight = tester.getTopRight(find.byType(Slider));
    await tester.dragFrom(
      sliderCenter,
      Offset(sliderRight.dx - sliderCenter.dx, 0),
    );
    await tester.pumpAndSettle();

    expect(sought, isNotNull);
    expect(sought!.inSeconds, greaterThan(120)); // perto do fim (200s)
    await positions.close();
    await durations.close();
  });
}
