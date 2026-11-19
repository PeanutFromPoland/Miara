import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(412, 915)]) {
    testWidgets('Miara starts and opens every tab at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MiaraApp());
      expect(find.text('01 / BILANS DNIA'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final tab in ['Odkrywaj', 'Plan', 'Dziennik', 'Profil', 'Dziś']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Tab: $tab, size: $size',
        );
      }
    });
  }
}
