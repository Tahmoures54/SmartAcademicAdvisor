# همراه تحصیلی | Smart Academic Advisor

اپلیکیشن آموزشی فارسی و راست‌چین برای برنامه‌ریزی درسی، پیگیری آزمون‌ها، یادداشت‌ها، مرور فاصله‌دار و دریافت راهنمایی تحصیلی از مقطع ابتدایی تا دانشگاه.

> وضعیت پروژه: در حال توسعه. موفقیت CI به‌تنهایی به معنی آماده‌بودن برای انتشار عمومی نیست.

## قابلیت‌های فعلی

- راهنمای آموزشی قاعده‌محور و آفلاین
- اتصال اختیاری به سرویس راهنمایی هوشمند از طریق backend
- برنامه‌ریز درسی و ثبت پیشرفت مطالعه
- تایمر تمرکز، آزمون‌ها و یادداشت‌های محلی
- کارت‌های مرور و مرور فاصله‌دار
- ارزیابی روش مطالعه و پیشنهاد اولویت‌های یادگیری
- رابط فارسی و راست‌چین

## فناوری‌ها

- Flutter / Dart برای Android
- SharedPreferences برای نگهداری محلی داده‌ها
- Flask و Gunicorn برای API اختیاری هوش مصنوعی
- SQLite یا پایگاه داده ابری در نسخه فعلی استفاده نمی‌شود؛ داده‌های برنامه روی دستگاه باقی می‌مانند.

## پیش‌نیازها

- Flutter 3.32 یا جدیدتر (نسخه stable توصیه می‌شود)
- Dart 3.6 یا جدیدتر
- JDK 17 و Android SDK برای ساخت Android
- Python 3.11 یا جدیدتر فقط برای backend

## شروع سریع برنامه

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

برای ساخت APK آزمایشی:

```bash
flutter build apk --debug
```

## راهنمای اتصال هوش مصنوعی

برنامه فقط از طریق backend سمت سرور به ارائه‌دهنده مدل متصل می‌شود. **کلید AI را هرگز در Flutter، `--dart-define`، فایل‌های مخزن یا APK قرار ندهید.** اگر backend پیکربندی نشده باشد یا در دسترس نباشد، برنامه از راهنمای آفلاین استفاده می‌کند.

آدرس backend را با متغیر `ADVISOR_API_BASE_URL` در زمان اجرا یا ساخت تنظیم کنید:

```bash
flutter run --dart-define=ADVISOR_API_BASE_URL=https://your-api.example
```

برای توسعه محلی، backend را طبق [راهنمای backend](backend/README.md) اجرا و از آدرس محلی استفاده کنید. آدرس عمومی باید HTTPS باشد.

## اجرای backend محلی

```bash
python -m venv .venv
# Windows PowerShell:
.venv\\Scripts\\Activate.ps1
# Linux/macOS:
# source .venv/bin/activate

pip install -r backend/requirements.txt
```

سپس در PowerShell:

```powershell
$env:AI_API_KEY="YOUR_PROVIDER_KEY"
$env:AI_BASE_URL="https://api.deepseek.com"
$env:AI_MODEL="deepseek-chat"
python backend/app.py
```

در Linux/macOS متغیرهای محیطی را پیش از اجرای `python backend/app.py` صادر کنید. کلید واقعی فقط در محیط backend قرار می‌گیرد؛ فایل `.env` را commit نکنید.

- `GET /health`: بررسی زنده‌بودن سرویس
- `GET /ready`: آمادگی سرویس؛ فقط با کلید و تنظیمات معتبر HTTPS پاسخ 200 می‌دهد
- `POST /api/advice`: دریافت راهنمایی آموزشی

## معماری مخزن

- `lib/config/`: پیکربندی و گزینه‌های ثابت برنامه
- `lib/models/`: مدل‌های داده
- `lib/services/`: ذخیره‌سازی محلی، راهنمای آفلاین و API مشاور
- `lib/features/`: قابلیت‌های مستقل رابط کاربری
- `backend/`: API واسط و تست‌های آن
- `docs/`: مستندات محصول و پیش‌نویس حریم خصوصی
- `scripts/`: ابزارهای پیکربندی ساخت Android
- `.github/workflows/`: بررسی کیفیت، ساخت APK و انتشار امضاشده

## بررسی کیفیت و CI

Workflow اصلی موارد زیر را بررسی می‌کند:

1. قالب‌بندی Dart (در حال حاضر هشداردهنده تا ثبت اصلاح قالب‌بندی در مخزن)
2. تحلیل ایستا و تست‌های Flutter
3. بررسی Ruff و تست‌های backend
4. ساخت تصویر Docker و APK آزمایشی

برای مشاهده وضعیت، به [GitHub Actions](https://github.com/Tahmoures54/SmartAcademicAdvisor/actions) مراجعه کنید.

## استقرار و انتشار

- الگوی استقرار آزمایشی Render در `render.yaml` قرار دارد؛ هنوز به معنی استقرار واقعی سرویس نیست.
- کلید ارائه‌دهنده باید در بخش Secrets میزبان backend ثبت شود.
- Workflow انتشار Android به‌صورت دستی اجرا می‌شود و به چهار GitHub Secret امضای APK نیاز دارد: `ANDROID_KEYSTORE_BASE64`، `ANDROID_KEYSTORE_PASSWORD`، `ANDROID_KEY_ALIAS` و `ANDROID_KEY_PASSWORD`.
- کلید امضای دائمی باید خارج از مخزن و با پشتیبان امن نگهداری شود.
- پیش‌نویس سیاست حریم خصوصی در `docs/PRIVACY_POLICY_DRAFT_FA.md` است و قبل از انتشار باید با میزبان و ارائه‌دهنده واقعی تطبیق داده شود.
- چک‌لیست انتشار در [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) قرار دارد.

## محدودیت‌های مهم پیش از انتشار عمومی

محدودکننده فعلی درخواست backend در حافظه همان پردازه است و بین چند نمونه یا پس از راه‌اندازی مجدد مشترک نیست. پیش از دسترسی عمومی باید محدودسازی مشترک (مانند Redis) یا احراز هویت و همچنین سقف هزینه و هشدار مصرف ارائه‌دهنده تنظیم شود. تست روی دستگاه واقعی، بررسی حریم خصوصی و امضای نهایی نیز باقی است.

## مجوز

MIT
