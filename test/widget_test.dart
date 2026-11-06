import 'dart:ui' show Size;

import 'package:flutter/material.dart' show AlertDialog, EditableText, FilledButton, OutlinedButton, Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_academic_advisor/main.dart';

Finder get _bodyScrollable => find.byType(Scrollable).first;

Finder get _plannerScrollable => find.byType(Scrollable).first;

Finder get _assessmentScrollable => find.descendant(
  of: find.byType(StudyAssessmentPage),
  matching: find.byType(Scrollable),
).first;

Finder get _dialogFields => find.descendant(
  of: find.byType(AlertDialog).last,
  matching: find.byType(EditableText),
);

Future<void> _pumpAdvisor(WidgetTester tester) async {
  // Exercise the app at a realistic phone viewport rather than the test
  // binding's wide desktop-like default size.
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const AcademicAdvisorApp());
  await tester.pumpAndSettle();
  // Allow the asynchronous SharedPreferences load to finish before interacting.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('shows academic stages and guidance form', (tester) async {
    await _pumpAdvisor(tester);
    expect(find.text('همراه تحصیلی'), findsOneWidget);
    expect(find.text('ابتدایی'), findsOneWidget);
    expect(find.text('کنکوری'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('از مشاور تحصیلی بپرس'), 400,
      scrollable: _bodyScrollable);
    await tester.pumpAndSettle();
    expect(find.text('از مشاور تحصیلی بپرس'), findsOneWidget);
  });

  testWidgets('submits a question and labels demo guidance', (tester) async {
    await _pumpAdvisor(tester);
    await tester.scrollUntilVisible(find.text('از مشاور تحصیلی بپرس'), 400,
      scrollable: _bodyScrollable);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'چطور درس بخوانم؟');
    await tester.ensureVisible(find.text('دریافت راهنمایی'));
    await tester.tap(find.text('دریافت راهنمایی'));
    await tester.pumpAndSettle();
    expect(find.text('راهنمای پیشنهادی'), findsOneWidget);
    expect(find.textContaining('راهنمای قاعده‌محور و عمومی است'), findsOneWidget);
  });

  testWidgets('guidance changes with the selected school stage', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('ابتدایی').first);
    await tester.scrollUntilVisible(find.text('از مشاور تحصیلی بپرس'), 400,
      scrollable: _bodyScrollable);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'چطور بهتر درس بخوانم؟');
    await tester.ensureVisible(find.text('دریافت راهنمایی'));
    await tester.tap(find.text('دریافت راهنمایی'));
    await tester.pumpAndSettle();
    expect(find.textContaining('پیشنهاد برای مقطع شما'), findsOneWidget);
    expect(find.textContaining('۱۰ تا ۱۵ دقیقه‌ای'), findsOneWidget);
  });

  testWidgets('study self-assessment calculates a guidance score', (tester) async {
    await _pumpAdvisor(tester);
    await tester.scrollUntilVisible(find.text('ارزیابی سریع روش مطالعه'), 300,
      scrollable: _bodyScrollable);
    await tester.ensureVisible(find.text('ارزیابی سریع روش مطالعه'));
    await tester.tap(find.text('ارزیابی سریع روش مطالعه'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('به‌سختی'), 300,
      scrollable: _assessmentScrollable);
    await tester.ensureVisible(find.text('به‌سختی'));
    await tester.tap(find.text('به‌سختی'));
    await tester.scrollUntilVisible(find.text('خیلی زود'), 300,
      scrollable: _assessmentScrollable);
    await tester.ensureVisible(find.text('خیلی زود'));
    await tester.tap(find.text('خیلی زود'));
    await tester.scrollUntilVisible(find.text('به‌ندرت'), 300,
      scrollable: _assessmentScrollable);
    await tester.ensureVisible(find.text('به‌ندرت'));
    await tester.tap(find.text('به‌ندرت'));
    await tester.scrollUntilVisible(find.text('اغلب سنگین است'), 300,
      scrollable: _assessmentScrollable);
    await tester.ensureVisible(find.text('اغلب سنگین است'));
    await tester.tap(find.text('اغلب سنگین است'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('نمایش جمع‌بندی'));
    await tester.tap(find.text('نمایش جمع‌بندی'));
    await tester.pumpAndSettle();
    expect(find.text('امتیاز راهنمایی: 2 از 8'), findsOneWidget);
    expect(find.textContaining('نمرهٔ هوش'), findsOneWidget);
  });

  testWidgets('exam tracker stores exam date and optional score locally', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('آزمون‌ها').last);
    await tester.pumpAndSettle();
    expect(find.text('هنوز آزمونی ثبت نشده است'), findsOneWidget);
    await tester.tap(find.text('افزودن آزمون یا امتحان'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'ریاضی');
    await tester.tap(find.text('ذخیره آزمون'));
    await tester.pumpAndSettle();
    expect(find.text('ریاضی'), findsWidgets);
    expect(find.textContaining('تا آزمون'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('study_exams'), contains('ریاضی'));
    await tester.tap(find.text('ساخت برنامهٔ مرور'));
    await tester.pumpAndSettle();
    expect(find.text('برنامهٔ درسی من'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('مرور خلاصه‌ها و نکته‌های ریاضی'), 300,
      scrollable: _plannerScrollable);
    expect(find.text('مرور خلاصه‌ها و نکته‌های ریاضی'), findsOneWidget);
    expect(find.text('حل چند سؤال تمرینی از ریاضی'), findsOneWidget);
    final taskPrefs = await SharedPreferences.getInstance();
    expect(taskPrefs.getStringList('study_tasks'), contains('تحلیل اشتباه‌ها و مرور نهایی ریاضی'));
  });

  testWidgets('study progress records minutes and subject confidence locally', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ثبت جلسهٔ مطالعه'), 300,
      scrollable: _plannerScrollable);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'ثبت جلسهٔ مطالعه').last);
    await tester.tap(find.widgetWithText(FilledButton, 'ثبت جلسهٔ مطالعه').last);
    await tester.pumpAndSettle();
    await tester.enterText(_dialogFields.at(0), 'ریاضی');
    await tester.enterText(_dialogFields.at(1), '35');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'ثبت مطالعه').last);
    await tester.tap(find.widgetWithText(FilledButton, 'ثبت مطالعه').last);
    await tester.pumpAndSettle();
    expect(find.text('ریاضی'), findsWidgets);
    expect(find.text('35 دقیقه · تسلط 3.0/5'), findsOneWidget);
    expect(find.text('35 دقیقه'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('study_sessions'), contains('ریاضی'));
  });

  testWidgets('bottom navigation opens the study plan page', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    expect(find.text('برنامهٔ درسی من'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('برنامهٔ هفت روز آینده'), 300,
      scrollable: _plannerScrollable);
    expect(find.text('برنامهٔ هفت روز آینده'), findsOneWidget);
    expect(find.text('دوشنبه'), findsWidgets);
    await tester.scrollUntilVisible(find.text('هنوز کاری ثبت نشده است'), 300,
      scrollable: _plannerScrollable);
    expect(find.text('هنوز کاری ثبت نشده است'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('مثلاً: مرور فصل دوم علوم'), 300,
      scrollable: _plannerScrollable);
    await tester.enterText(find.byType(EditableText).first, 'مرور فصل دوم علوم');
    await tester.tap(find.text('افزودن به برنامه'));
    await tester.pumpAndSettle();
    expect(find.text('مرور فصل دوم علوم'), findsOneWidget);
    expect(find.text('0 از 1 انجام‌شده'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('study_tasks'), contains('مرور فصل دوم علوم'));
    expect(find.text('بدون موعد'), findsOneWidget);
    expect(find.byTooltip('تنظیم موعد'), findsOneWidget);
    expect(find.textContaining('عقب‌افتاده:'), findsOneWidget);
  });

  testWidgets('planner exposes weekly report, spaced repetition and adaptive plan', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('گزارش هفتگی پیشرفت'), 300,
      scrollable: _plannerScrollable);
    expect(find.text('گزارش هفتگی پیشرفت'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('مرور فاصله‌دار و نقاط ضعف'), 300,
      scrollable: _plannerScrollable);
    expect(find.text('مرور فاصله‌دار و نقاط ضعف'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('نقشهٔ تسلط و اولویت یادگیری'), 300,
      scrollable: _plannerScrollable);
    expect(find.text('نقشهٔ تسلط و اولویت یادگیری'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ساخت برنامهٔ پیشنهادی'), 350,
      scrollable: _plannerScrollable);
    expect(find.text('ساخت برنامهٔ پیشنهادی'), findsOneWidget);
    expect(find.text('مربی آموزشی قدم‌به‌قدم'), findsOneWidget);
  });

  testWidgets('review cards save locally and support spaced review', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('افزودن سؤال برای مرور'), 300,
      scrollable: _plannerScrollable);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'افزودن سؤال برای مرور').last);
    await tester.tap(find.widgetWithText(OutlinedButton, 'افزودن سؤال برای مرور').last);
    await tester.pumpAndSettle();
    await tester.enterText(_dialogFields.at(0), 'زیست');
    await tester.enterText(_dialogFields.at(1), 'میتوکندری چه می‌کند؟');
    await tester.enterText(_dialogFields.at(2), 'در تولید انرژی سلول نقش دارد.');
    await tester.ensureVisible(find.text('ذخیره کارت'));
    await tester.tap(find.text('ذخیره کارت'));
    await tester.pumpAndSettle();
    expect(find.text('میتوکندری چه می‌کند؟'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('study_review_cards'), contains('میتوکندری'));
    await tester.ensureVisible(find.byTooltip('مرور سؤال').first);
    await tester.tap(find.byTooltip('مرور سؤال').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('نمایش پاسخ'));
    await tester.tap(find.text('نمایش پاسخ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('بلد بودم'));
    await tester.tap(find.text('بلد بودم'));
    await tester.pumpAndSettle();
    expect(prefs.getString('study_review_cards'), contains('"interval":"1"'));
  });

  testWidgets('adaptive study plan creates dated study tasks', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ساخت برنامهٔ پیشنهادی'), 350,
      scrollable: _plannerScrollable);
    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, 'ساخت برنامهٔ پیشنهادی').last, 350, scrollable: _plannerScrollable);
    await tester.tap(find.widgetWithText(FilledButton, 'ساخت برنامهٔ پیشنهادی').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'ساخت برنامه').last);
    await tester.tap(find.text('ساخت برنامه').last);
    await tester.pumpAndSettle();
    expect(find.text('برنامهٔ درسی من'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('مرور فعال'), 300,
      scrollable: _plannerScrollable);
    expect(find.textContaining('مرور فعال'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('study_tasks'), isNotEmpty);
    expect(prefs.getString('study_task_due_dates'), contains('مرور فعال'));
  });

  testWidgets('step tutor guides learner through three stages offline', (tester) async {
    await _pumpAdvisor(tester);
    await tester.tap(find.text('برنامه من').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('مربی آموزشی قدم‌به‌قدم'), 350,
      scrollable: _plannerScrollable);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'مربی آموزشی قدم‌به‌قدم').last);
    await tester.tap(find.widgetWithText(OutlinedButton, 'مربی آموزشی قدم‌به‌قدم').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'کسرها');
    await tester.ensureVisible(find.text('شروع یادگیری'));
    await tester.tap(find.text('شروع یادگیری'));
    await tester.pumpAndSettle();
    expect(find.text('گام ۱ · سرنخ'), findsOneWidget);
    await tester.ensureVisible(find.text('دیدن توضیح'));
    await tester.tap(find.text('دیدن توضیح'));
    await tester.pumpAndSettle();
    expect(find.text('گام ۲ · توضیح'), findsOneWidget);
    await tester.ensureVisible(find.text('بررسی یادگیری'));
    await tester.tap(find.text('بررسی یادگیری'));
    await tester.pumpAndSettle();
    expect(find.text('گام ۳ · بررسی یادگیری'), findsOneWidget);
  });
}
