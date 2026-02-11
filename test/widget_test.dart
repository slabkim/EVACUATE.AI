import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evacuateai/widgets/app_bottom_nav.dart';

void main() {
  testWidgets('Bottom nav menampilkan lima menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);
  });
}
