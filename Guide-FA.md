# پاک‌سازی ویندوز ۱۱: حذف برنامه‌های اضافی، کوپایلت و تبلیغات

## فایل‌ها

| فایل | کار |
|---|---|
| `Win11-Clean.ps1` | اسکریپت اصلی |
| `Run-Win11-Clean.bat` | برای اجرای آسان (دبل‌کلیک) |

هر دو فایل باید **در یک پوشه** باشند.

---

## طریقه اجرا

1. هر دو فایل را در یک پوشه بگذارید (مثلاً `Downloads`).
2. روی `Run-Win11-Clean.bat` **دبل‌کلیک** کنید.
   - اگر پیام آبی رنگ «Windows protected your PC» آمد: روی **More info** و بعد **Run anyway** بزنید.
3. پنجره «آیا اجازه می‌دهید؟» (UAC) می‌آید، **Yes** بزنید.
4. خلاصه کارها نشان داده می‌شود. حرف **Y** را بنویسید و **Enter** بزنید.
5. منتظر بمانید (۵ تا ۱۵ دقیقه). در آخر کمپیوتر را **ری‌استارت** کنید.

> اول یک **Restore Point** به نام `Before Win11-Clean` ساخته می‌شود تا هر وقت خواستید همه چیز را برگردانید.
> گزارش کامل کار در پوشه `C:\Win11-Clean\` ذخیره می‌شود.

---

## چه چیزهایی حذف یا خاموش می‌شود

### ۱. تبلیغات (مهم‌ترین بخش)
- پیشنهادها و تبلیغات **Start Menu** (بخش Recommended)
- تبلیغات و «Fun facts» در **صفحه قفل (Lock screen)**
- تبلیغات OneDrive و Microsoft 365 در **File Explorer**
- «Suggested content» در **Settings**
- اعلان‌های تبلیغاتی و «Tips and suggestions»
- صفحه «Finish setting up your device» بعد از آپدیت‌ها
- نصب خودکار بازی‌ها و برنامه‌های تبلیغاتی (Candy Crush و غیره)
- **Widgets** (اخبار MSN همراه با تبلیغ)
- نتایج **Bing** و «Search highlights» در جستجوی ویندوز
- **Advertising ID** (شناسه تبلیغاتی برای ردیابی شما)
- در **Edge**: اخبار MSN در New Tab، لینک‌های اسپانسری، Shopping، Rewards و پیشنهادها

### ۲. کوپایلت و هوش مصنوعی
- برنامه **Copilot** و دکمه آن در Taskbar
- **Microsoft 365 Copilot** (برنامه Office Hub)
- **Recall** و **Click to Do**
- قابلیت‌های AI در **Paint** و **Notepad**
- Copilot و نوار کناری (Sidebar) در **Edge**

### ۳. برنامه‌های غیرضروری
News، Weather، Bing Search، Tips، Get Help، Clipchamp، Teams، Solitaire،
Sticky Notes، To Do، People، Maps، Clock، Sound Recorder، Feedback Hub،
Phone Link، Movies & TV، Cortana، Power Automate، Dev Home، Quick Assist،
Family، OneNote، Journal، Mail و Calendar، Outlook جدید،
و برنامه‌های تبلیغاتی مثل Candy Crush، TikTok، Instagram، Facebook، Netflix،
Spotify، Disney+، Amazon، LinkedIn و غیره.

### ۴. اختیاری (در حالت پیش‌فرض روشن است)
- **OneDrive**
- برنامه‌های **Xbox** و Game Bar

### ۵. سرویس‌ها و ردیابی
- سرویس‌های غیرضروری: Telemetry (DiagTrack)، Retail Demo، Maps، Fax،
  Remote Registry، Insider، Parental Controls، Wallet، AllJoyn، و سرویس‌های Xbox
- تسک‌های زمان‌بندی‌شده که اطلاعات استفاده شما را به مایکروسافت می‌فرستند
- Activity History و ارسال اطلاعات تایپ و دست‌خط

---

## چه چیزهایی باقی می‌ماند (ضروری)

Microsoft Store، Calculator، Notepad، Photos، Paint، Snipping Tool، Camera،
Terminal، Media Player، **Windows Security (آنتی‌ویروس)**، Edge،
کدک‌های عکس و ویدیو، WhatsApp و Telegram (اگر نصب باشند).

**به این‌ها دست زده نمی‌شود:** Windows Update، Defender، پرینتر، بلوتوث،
وای‌فای، کیبورد فارسی/پشتو و زبان‌ها، جستجوی ویندوز، درایورها.

---

## تنظیمات (قبل از اجرا، اختیاری)

فایل `Win11-Clean.ps1` را با Notepad باز کنید. در بالای فایل این خطوط هستند:

```powershell
$RemoveOneDrive   = $true    # حذف OneDrive
$RemoveXbox       = $true    # حذف Xbox و Game Bar
$RemoveMailOutlook= $true    # حذف Mail و Outlook
$DisableTelemetry = $true    # کم کردن ارسال اطلاعات به مایکروسافت
$ApplyToNewUsers  = $true    # اعمال روی حساب‌های کاربری جدید
```

برای نگه داشتن هر کدام، `$true` را به `$false` تغییر دهید و ذخیره کنید.

---

## هشدارهای مهم ⚠️

1. **OneDrive:** اگر Desktop یا Documents شما با OneDrive همگام (Sync) است،
   قبل از اجرا روی پوشه OneDrive راست‌کلیک کرده و **Always keep on this device**
   را بزنید تا همه فایل‌ها روی کمپیوتر دانلود شوند. فایل‌های شما در فضای ابری
   (onedrive.com) پاک **نمی‌شوند**.
2. **بازی:** اگر از Xbox App یا Game Pass بازی می‌کنید، `$RemoveXbox = $false` بگذارید.
3. **Edge** بعد از اجرا پیام «Your browser is managed by your organization» نشان می‌دهد.
   این عادی است و فقط یعنی تنظیمات ضد تبلیغ فعال شده‌اند.
4. اگر از TikTok، Instagram، Netflix یا Spotify استفاده می‌کنید، بعداً می‌توانید
   از Microsoft Store دوباره نصب‌شان کنید.
5. در بعضی آپدیت‌های بزرگ ویندوز (مثلاً 24H2 به 25H2)، مایکروسافت ممکن است
   چند تنظیم را برگرداند. در آن صورت اسکریپت را **دوباره اجرا کنید**؛ هیچ ضرری ندارد.

---

## برگرداندن تغییرات

- **همه چیز:** دکمه Start را بزنید و `Create a restore point` را جستجو کنید.
  بعد **System Restore** و نقطه **Before Win11-Clean** را انتخاب کنید.
- **فقط یک برنامه:** آن را از **Microsoft Store** دوباره نصب کنید.
