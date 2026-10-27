# 🚀 الدليل الشامل والنهائي لنشر وتشغيل Apex Store V2 (Print Express) على الهوست

**تاريخ التوثيق:** أكتوبر 2026  
**النطاقات الرسمية:**
- 🌐 المتجر (Storefront): `https://printexpress.com.eg`
- ⚙️ لوحة التحكم (Dashboard): `https://admin.printexpress.com.eg`
- 🔌 الـ API والباك إند (Backend): `https://printexpress.com.eg/api/v1/`

---

## 📦 1. مستودعات GitHub المعتمدة (GitHub Repositories)

- **حساب GitHub:** `ahmed-abdel-aal-a`
- **توكن الوصول (PAT):** `YOUR_GITHUB_TOKEN` (الموجود في `github.txt`)

1. **مستودع واجهة المتجر (Next.js 14):**
   `https://github.com/ahmed-abdel-aal-a/printexpress.com.eg.git`
   - يحتوي على الكود + ملفات الإنتاج المبنية (`.next`) + `.htaccess` للتحويل الفوري.
2. **مستودع لوحة التحكم (Next.js 15):**
   `https://github.com/ahmed-abdel-aal-a/admin.printexpress.com.eg.git`
   - يحتوي على الكود + ملفات الإنتاج المبنية (`.next`) + `.htaccess` للتحويل الفوري.
3. **مستودع الباك إند وقاعدة البيانات (Laravel 11):**
   `https://github.com/ahmed-abdel-aal-a/apex-backend.git`
   - يحتوي على كود الباك إند + الـ 80 Migration + ملف استيراد الداتابيز: `database/printexpress_production_data.sql`.

---

## 🗄️ 2. إنشاء قاعدة البيانات على الهوست (Database Setup)

### الطريقة الأولى: عبر Terminal السيرفر (MySQL CLI)
قم بتسجيل الدخول إلى SSH أو فتح Terminal في cPanel ونفّذ الأوامر التالية (استبدل كلمة المرور واسم القاعدة بما يناسبك):

```bash
mysql -u root -p
```
*(أو إذا كنت مستخدم عادي في cPanel اكتب `mysql -u cpanel_user -p`)*

ثم نفذ داخل MySQL:
```sql
CREATE DATABASE IF NOT EXISTS `printexp_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'printexp_usr'@'localhost' IDENTIFIED BY 'PrintExpress@2026_LiveSecure#99';
GRANT ALL PRIVILEGES ON `printexp_db`.* TO 'printexp_usr'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### الطريقة الثانية: من واجهة cPanel (بدون تيرمنال)
1. ادخل على **MySQL® Databases**.
2. **Create New Database:** اكتب اسم القاعدة وليكن `printexp_db`.
3. **Add New User:** أضف مستخدم وليكن `printexp_usr` وكلمة مرور قوية.
4. **Add User To Database:** اربط المستخدم بالقاعدة واختر **ALL PRIVILEGES**.

---

## 📥 3. سحب الأكواد وتثبيت المشاريع في مساراتها الرسمية

> [!NOTE]
> نظراً لأن cPanel أنشأ بالفعل مجلدات `~/printexpress.com.eg` و `~/admin.printexpress.com.eg`، يتم سحب الكود بداخلها مباشرة كالتالي:

### أ) سحب وتجهيز الباك إند (Laravel Backend):
```bash
cd ~
git clone https://YOUR_GITHUB_TOKEN@github.com/ahmed-abdel-aal-a/apex-backend.git apex-backend
cd ~/apex-backend

# نسخ إعدادات البيئة
cp .env.production.example .env

# تعديل بيانات الاتصال بقاعدة البيانات في .env:
# افتح الملف بـ nano .env وضع:
# DB_DATABASE=اسم_القاعدة
# DB_USERNAME=اسم_المستخدم
# DB_PASSWORD=كلمة_المرور

# توليد المفتاح وتثبيت الحزم (إن لزم)
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan storage:link

# استيراد قاعدة البيانات النظيفة بجميع المنتجات وتصنيفات الطباعة والمناطق (خطوة واحدة):
php artisan migrate --force
mysql -u printexp_usr -p printexp_db < database/printexpress_production_data.sql

# تسريع الكاش للإنتاج
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

---

### ب) سحب وتجهيز المتجر (Storefront - printexpress.com.eg):
```bash
cd ~/printexpress.com.eg
git pull origin main
```

---

### ج) سحب وتجهيز لوحة التحكم (Dashboard - admin.printexpress.com.eg):
```bash
cd ~/admin.printexpress.com.eg
git pull origin main
```

---

## ⚡ 4. تشغيل وإدارة التطبيقات (PM2 Ecosystem & LiteSpeed LSPHP)

### أ) الباك إند (Laravel 11) - يعمل تلقائياً عبر LiteSpeed LSPHP:
تم ربط النطاق الفرعي `api.printexpress.com.eg` مباشرة بالمجلد `/home/kyanfash/apex-backend/public`، ويعمل عبر محرك LiteSpeed PHP الأصلي (LSPHP) مع دعم كامل لـ OPcache وإدارة الموارد دون الحاجة لأي عمليات PM2.

### ب) المتجر ولوحة التحكم - يعملان عبر ملف الإدارة الموحد `~/ecosystem.config.js`:
```bash
# 1. إيقاف وحذف أي عمليات قديمة في PM2
pm2 delete all

# 2. تشغيل المتجر والداشبورد بالقيود الصارمة للذاكرة (350M Max RAM)
pm2 start /home/kyanfash/ecosystem.config.js

# 3. حفظ الحالة في PM2
pm2 save --force
```

---

## 🛡️ 5. الحارس التلقائي الدوري (Watchdog Script & Cron)

لحماية التطبيقات من السقوط أو الـ 503 وإعادتها للعمل فوراً عند إعادة تشغيل السيرفر الفيزيائي أو حدوث أي خلل:
```bash
# إعطاء صلاحية التنفيذ لسكربت الحارس
chmod +x /home/kyanfash/watchdog.sh

# إضافة الفحص الدوري كل 3 دقائق في Crontab بأمان
(crontab -l 2>/dev/null | grep -Fv "watchdog.sh"; echo "*/3 * * * * /home/kyanfash/watchdog.sh >/dev/null 2>&1") | crontab -
```

---

## 🔒 6. توجيه المسارات وشبكة الأمان (.htaccess)

الملفات تقوم بالآتي:
1. في `~/printexpress.com.eg/.htaccess`:
   - أي طلب يبدأ بـ `/api/` أو `/storage/` يتم تحويله لـ `https://api.printexpress.com.eg` (LSPHP).
   - بقية المتجر يتم تحويله للبورت `2000` (Next.js Storefront).
2. في `~/admin.printexpress.com.eg/.htaccess`:
   - أي طلب لـ `/api/` أو `/storage/` يتم تحويله لـ `https://api.printexpress.com.eg` (LSPHP).
   - بقية طلبات لوحة التحكم يتم تحويلها للبورت `2050` (Next.js Dashboard).

---

## 🔑 7. بيانات الدخول الافتراضية للوحة التحكم (Admin Credentials)

- **الرابط:** `https://admin.printexpress.com.eg`
- **البريد الإلكتروني:** `test@example.com`
- **كلمة المرور:** `password`
- **الدور والصلاحيات:** `Super Admin`
