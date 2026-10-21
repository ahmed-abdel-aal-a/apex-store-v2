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
git init
git remote add origin https://YOUR_GITHUB_TOKEN@github.com/ahmed-abdel-aal-a/printexpress.com.eg.git
git fetch origin main
git checkout -f main

# تثبيت الحزم (الإنتاج فقط)
npm install --omit=dev
```

---

### ج) سحب وتجهيز لوحة التحكم (Dashboard - admin.printexpress.com.eg):
```bash
cd ~/admin.printexpress.com.eg
git init
git remote add origin https://YOUR_GITHUB_TOKEN@github.com/ahmed-abdel-aal-a/admin.printexpress.com.eg.git
git fetch origin main
git checkout -f main

# تثبيت الحزم (الإنتاج فقط)
npm install --omit=dev
```

---

## ⚡ 4. تشغيل التطبيقات في الخلفية على المنافذ الرسمية (PM2)

> التطبيقات مبنية وجاهزة (Pre-built)، فقط يتم تشغيلها بالبورتات المعتمدة:

```bash
# تثبيت PM2 عالمياً (إذا لم يكن مثبتاً)
npm install -g pm2

# 1. تشغيل الباك إند (Port: 2080)
cd ~/apex-backend
pm2 start "php artisan serve --host=127.0.0.1 --port=2080" --name "apex-backend"

# 2. تشغيل المتجر (Port: 2000)
cd ~/printexpress.com.eg
pm2 start "npm start -- -p 2000" --name "apex-storefront"

# 3. تشغيل لوحة التحكم (Port: 2050)
cd ~/admin.printexpress.com.eg
pm2 start "npm start -- -p 2050" --name "apex-dashboard"

# حفظ العمليات لتعمل تلقائياً عند إعادة تشغيل السيرفر
pm2 save
```

---

## 🔒 5. توجيه المسارات وشبكة الأمان (.htaccess)

الملفات موجودة بالفعل داخل المستودعات، وهي تقوم بالآتي:
1. في `~/printexpress.com.eg/.htaccess`:
   - أي مسار يبدأ بـ `/api/` يتم تحويله داخلياً وسريعاً للبورت `2080` (Laravel).
   - بقية المتجر يتم تحويله للبورت `2000` (Next.js Storefront).
2. في `~/admin.printexpress.com.eg/.htaccess`:
   - يتم تحويل كل طلبات لوحة التحكم للبورت `2050` (Next.js Dashboard).

---

## 🔑 6. بيانات الدخول الافتراضية للوحة التحكم (Admin Credentials)

- **الرابط:** `https://admin.printexpress.com.eg`
- **البريد الإلكتروني:** `test@example.com`
- **كلمة المرور:** `password`
- **الدور والصلاحيات:** `Super Admin`
