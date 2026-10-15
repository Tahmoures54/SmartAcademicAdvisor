import 'package:flutter/material.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_academic_advisor/main.dart';

void main() {
  testWidgets('shows academic stages and guidance form', (tester) async {
    await tester.pumpWidget(const AcademicAdvisorApp());
    expect(find.text('همراه تحصیلی'), findsOneWidget);
    expect(find.text('ابتدایی'), findsOneWidget);
    expect(find.text('کنکوری'), findsOneWidget);
    expect(find.text('از مشاور تحصیلی بپرس'), findsOneWidget);
  });

  testWidgets('submits a question and labels demo guidance', (tester) async {
    await tester.pumpWidget(const AcademicAdvisorApp());
    await tester.enterText(find.byType(EditableText).first, 'چطور درس بخوانم؟');
    await tester.ensureVisible(find.text('دریافت راهنمایی'));
    await tester.tap(find.text('دریافت راهنمایی'));
    await tester.pumpAndSettle();
    expect(find.text('راهنمای پیشنهادی'), findsOneWidget);
    expect(find.textContaining('هنوز به سرویس هوش مصنوعی متصل نیست'), findsOneWidget);
  });

  testWidgets('bottom navigation opens the study plan page', (tester) async {
    await tester.pumpWidget(const AcademicAdvisorApp());
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    expect(find.text('برنامهٔ درسی من'), findsOneWidget);
    expect(find.text('این بخش در حال توسعه است؛ فعلاً اطلاعاتی ذخیره نمی‌شود.'), findsOneWidget);
  });
}
