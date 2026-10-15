import 'package:flutter/material.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_academic_advisor/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
    expect(find.textContaining('راهنمای قاعده‌محور و عمومی است'), findsOneWidget);
  });

  testWidgets('guidance changes with the selected school stage', (tester) async {
    await tester.pumpWidget(const AcademicAdvisorApp());
    await tester.tap(find.text('ابتدایی').first);
    await tester.enterText(find.byType(EditableText).first, 'چطور بهتر درس بخوانم؟');
    await tester.ensureVisible(find.text('دریافت راهنمایی'));
    await tester.tap(find.text('دریافت راهنمایی'));
    await tester.pumpAndSettle();
    expect(find.textContaining('پیشنهاد برای مقطع شما'), findsOneWidget);
    expect(find.textContaining('۱۰ تا ۱۵ دقیقه‌ای'), findsOneWidget);
  });

  testWidgets('study self-assessment calculates a guidance score', (tester) async {
    await tester.pumpWidget(const AcademicAdvisorApp());
    await tester.ensureVisible(find.text('ارزیابی سریع روش مطالعه'));
    await tester.tap(find.text('ارزیابی سریع روش مطالعه'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('به‌سختی'));
    await tester.tap(find.text('به‌سختی'));
    await tester.ensureVisible(find.text('خیلی زود'));
    await tester.tap(find.text('خیلی زود'));
    await tester.ensureVisible(find.text('به‌ندرت'));
    await tester.tap(find.text('به‌ندرت'));
    await tester.ensureVisible(find.text('اغلب سنگین است'));
    await tester.tap(find.text('اغلب سنگین است'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نمایش جمع‌بندی'));
    await tester.pumpAndSettle();
    expect(find.text('امتیاز راهنمایی: 2 از 8'), findsOneWidget);
    expect(find.textContaining('نمرهٔ هوش'), findsOneWidget);
  });

  testWidgets('bottom navigation opens the study plan page', (tester) async {
    await tester.pumpWidget(const AcademicAdvisorApp());
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    expect(find.text('برنامهٔ درسی من'), findsOneWidget);
    expect(find.text('هنوز کاری ثبت نشده است'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'مرور فصل دوم علوم');
    await tester.tap(find.text('افزودن به برنامه'));
    await tester.pumpAndSettle();
    expect(find.text('مرور فصل دوم علوم'), findsOneWidget);
    expect(find.text('0 از 1 انجام‌شده'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('study_tasks'), contains('مرور فصل دوم علوم'));
  });
}
