import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:mio_notice/theme/app_theme.dart";

void main() {
  testWidgets("테마가 적용된 MaterialApp이 빌드된다", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMjcTheme(),
        home: const Scaffold(
          body: Center(child: Text("mjc")),
        ),
      ),
    );

    expect(find.text("mjc"), findsOneWidget);
  });
}
