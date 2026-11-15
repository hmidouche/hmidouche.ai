import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamidouch_ai/main.dart';
import 'package:hamidouch_ai/image_page.dart';
import 'package:hamidouch_ai/edit_image_page.dart';

void main() {
  testWidgets('Chat exposes local model and image actions', (tester) async {
    await tester.pumpWidget(const HamidouchApp());
    expect(find.byTooltip('توليد الصور محليًا'), findsOneWidget);
    expect(find.byTooltip('اختيار نموذج محلي'), findsOneWidget);
  });
  testWidgets('External image edit requires source and consent', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditImagePage()));
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إرسال واستلام الصورة المعدّلة'));
    expect(button.onPressed, isNull);
    expect(find.text('حفظ الصورة المعدّلة PNG'), findsNothing);
  });
  testWidgets('Image generation is disabled until a model loads', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ImagePage()));
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'توليد الصورة محليًا'));
    expect(button.onPressed, isNull);
    expect(find.text('حفظ PNG'), findsNothing);
  });
}
