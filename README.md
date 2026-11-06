# همراه تحصیلی | Smart Academic Advisor

اپلیکیشن Flutter فارسی و راست‌چین برای راهنمایی تحصیلی از ابتدایی تا کنکور، دانشگاه و پس از فارغ‌التحصیلی.

## قابلیت‌های شاخهٔ main

- داشبورد فارسی با انتخاب مقطع و موضوع راهنمایی
- راهنمای قاعده‌محور آفلاین + اتصال اختیاری به AI/backend
- برنامهٔ درسی: افزودن کار، تیک انجام، تایمر تمرکز ۲۵ دقیقه‌ای
- دفتر آزمون‌ها با تاریخ، شمارش معکوس و نمره
- یادداشت‌های محلی
- پروفایل و حذف داده‌های ذخیره‌شده
- ارزیابی سریع روش مطالعه
- backend پایتون و CI در GitHub Actions

## معماری کد

```
lib/
  main.dart                 # ورود + UI اصلی (متصل به سرویس‌ها)
  app.dart                  # MaterialApp و تم
  config/app_config.dart    # dart-define و ثابت‌ها
  models/                   # Exam, StudySession, ReviewCard, PlannerSnapshot
  services/
    local_store.dart        # SharedPreferences (کلیدهای سازگار قبلی)
    offline_advice.dart     # راهنمای قاعده‌محور
    advisor_api.dart        # AI مستقیم یا backend
  features/
    assessment/study_assessment_page.dart
```

ذخیره‌سازی محلی همان کلیدهای قبلی را نگه می‌دارد تا دادهٔ کاربران از بین نرود.

## اجرای اپ

```bash
flutter create --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

ساخت APK آزمایشی:

```bash
flutter build apk --debug
```

برای AI زنده، یا backend با `ADVISOR_API_BASE_URL`، یا Secretهای Actions برای تزریق کلید در بیلد آزمایشی. برای انتشار عمومی فقط کلید سمت سرور توصیه می‌شود.

```bash
flutter run --dart-define=ADVISOR_API_BASE_URL=https://your-api.example
```

## اجرای backend

جزئیات در [backend/README.md](backend/README.md).

```bash
cd backend
pip install -r requirements.txt
python -m unittest -v test_app.py
```

## محدودیت‌های فعلی

- backend روی میزبان عمومی مستقر نشده است.
- همگام‌سازی ابری و حساب کاربری وجود ندارد.
- برخی قابلیت‌های پیشرفتهٔ قبلی (مرور فاصله‌دار کامل، برنامهٔ تطبیقی خودکار، مربی سه‌مرحله‌ای غنی) در لایهٔ UI در حال تکمیل مجدد روی معماری جدید هستند؛ هستهٔ برنامه/آزمون/تایمر/یادداشت فعال است.
- ارزیابی مطالعه تشخیص علمی نیست.

## حریم خصوصی

پرسش‌ها فقط با پیکربندی backend از دستگاه خارج می‌شوند. اطلاعات حساس وارد نکنید.
