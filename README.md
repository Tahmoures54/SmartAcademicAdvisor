# همراه تحصیلی | Smart Academic Advisor

اپلیکیشن Flutter فارسی و راست‌چین برای راهنمایی تحصیلی از ابتدایی تا کنکور، دانشگاه و پس از فارغ‌التحصیلی.

## قابلیت‌های شاخهٔ main

- داشبورد با انتخاب مقطع و موضوع راهنمایی
- راهنمای قاعده‌محور آفلاین + اتصال اختیاری AI/backend
- برنامهٔ درسی: کارها، تیک انجام، تایمر تمرکز ۲۵ دقیقه‌ای
- دفتر آزمون‌ها با تاریخ، شمارش معکوس و نمره
- یادداشت‌های محلی
- پروفایل و حذف داده‌های ذخیره‌شده
- ارزیابی سریع روش مطالعه
- backend پایتون و CI در GitHub Actions

## معماری

```
lib/
  main.dart                 # ورود + UI کامل (متصل به سرویس‌ها)
  app.dart                  # MaterialApp و تم
  config/app_config.dart
  models/                   # Exam, StudySession, ReviewCard, PlannerSnapshot
  services/
    local_store.dart        # SharedPreferences با کلیدهای سازگار قبلی
    offline_advice.dart
    advisor_api.dart
  features/
    assessment/study_assessment_page.dart
```

## اجرا

```bash
flutter create --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

```bash
flutter build apk --debug
```

برای AI زنده:

```bash
flutter run --dart-define=ADVISOR_API_BASE_URL=https://your-api.example
```

یا Secretهای `AI_API_KEY` در Actions برای بیلد آزمایشی. برای انتشار عمومی فقط کلید سمت سرور توصیه می‌شود.

## Backend

جزئیات در [backend/README.md](backend/README.md).

```bash
cd backend && pip install -r requirements.txt && python -m unittest -v test_app.py
```

## محدودیت‌ها

- backend عمومی هنوز deploy نشده است.
- همگام‌سازی ابری وجود ندارد.
- ارزیابی مطالعه تشخیص علمی نیست.
