# 📖 دليل المعمارية والتشغيل والإنتاج الشامل — Apex Store V2 (Print Express)

> **تاريخ التوثيق والتحديث:** 27 أكتوبر 2026  
> **حالة النظام:** مباشر ومستقر في الإنتاج بنسبة 100% (Production Live)  
> **المشروع:** متجر إلكتروني مخصص لخدمات الطباعة والتجارة الإلكترونية (Print Express)

---

## 🏗️ 1. المعمارية العامة للنظام (System Architecture)

يعتمد النظام على بنية تحتية ثلاثية الطبقات تعمل بتناغم تام على خادم cPanel تحت بيئة **CloudLinux** وخادم ويب **LiteSpeed Web Server**:

```text
                                [ زوار الموقع / المتصفحات ]
                                            │
                                            ▼
                           [ LiteSpeed Web Server (cPanel) ]
                                            │
         ┌──────────────────────────────────┼──────────────────────────────────┐
         │ (Reverse Proxy)                  │ (Reverse Proxy)                  │ (Native LSPHP 8.2)
         ▼                                  ▼                                  ▼
┌──────────────────┐               ┌──────────────────┐               ┌──────────────────┐
│  واجهة المتجر    │               │  لوحة التحكم     │               │   الباك إند      │
│  (Storefront)    │               │   (Dashboard)    │               │    (Backend)     │
│   Next.js 14     │               │   Next.js 15     │               │   Laravel 11     │
│   Port: 2000     │               │   Port: 2050     │               │   LSPHP Direct   │
│ (مدار بـ PM2     │               │ (مدار بـ PM2     │               │  (Zero PM2,      │
│  بنظام Standalone)│              │  بنظام Standalone)│              │   OPcache نشط)   │
└──────────────────┘               └──────────────────┘               └──────────────────┘
```

---

## 🌐 2. النطاقات والمسارات والمنافذ الرسمية (Domains & Directory Paths)

| الخدمة / التطبيق | النطاق الرسمي (Domain) | المسار الفعلي على السيرفر | المحرك وطريقة التشغيل | المنفذ الداخلي (Port) |
| :--- | :--- | :--- | :--- | :--- |
| **واجهة المتجر (Storefront)** | `https://printexpress.com.eg` | `/home/kyanfash/printexpress.com.eg` | PM2 -> Standalone Node.js 22 | `2000` |
| **لوحة التحكم (Dashboard)** | `https://admin.printexpress.com.eg` | `/home/kyanfash/admin.printexpress.com.eg` | PM2 -> Standalone Node.js 22 | `2050` |
| **الباك إند (Backend API)** | `https://api.printexpress.com.eg` | `/home/kyanfash/api.printexpress.com.eg` | LiteSpeed Native PHP (LSPHP 8.2) | `مباشر (بدون بورت)` |

> **قاعدة معمارية صارمة:**  
> جميع المجلدات تقع مباشرة داخل مسار المستخدم `/home/kyanfash/` خارج مجلد `public_html` لضمان العزل الأمني التام وسهولة إدارة المشاريع وتفريغ الصلاحيات.

---

## 🛡️ 3. إدارة العمليات وحماية الذاكرة (Anti-OOM & Watchdog)

### أ) ملف الإدارة الموحد (`/home/kyanfash/ecosystem.config.js`):
يُدير مشروعي `apex-storefront` (بورت 2000) و `apex-dashboard` (بورت 2050) فقط. تم وضع سقف صارم للذاكرة لحماية العمليات من القتل المفاجئ بواسطة **CloudLinux OOM Killer**:
- `max_memory_restart: '350M'`
- `node_args: '--max-old-space-size=256'`

### ب) الحارس الذكي التلقائي (`/home/kyanfash/watchdog.sh`):
سكربت مبرمج ومحمي بـ `trap`، يعمل كل 3 دقائق بالخلفية عبر Crontab:
```bash
*/3 * * * * /home/kyanfash/watchdog.sh >/dev/null 2>&1
```
- يفحص استجابة البورتات `2000` و `2050`: إذا وجد البورت مغلقاً (`000`) أو يرجع انهياراً (`>= 500`)، يعيد تشغيل التطبيق فوراً.
- إذا وجد محرك PM2 متوقفاً بالكامل (مثلاً بعد إعادة تشغيل السيرفر الفيزيائي)، يقوم بإعادة تشغيل المنظومة بالكامل من `ecosystem.config.js`.

---

## 🚀 4. القواعد الذهبية للبناء والنشر (Deployment Rules)

> [!CAUTION]
> **القاعدة الأولى (ممنوع منعاً باتاً تشغيل `npm run build` على السيرفر):**  
> سيرفرات cPanel المشتركة تحت CloudLinux تفرض قيوداً صارمة على الذاكرة والمعالج. تشغيل `npm run build` على السيرفر يستهلك ذاكرة تتجاوز 1GB إلى 2GB، مما يُفعّل الـ OOM Killer فوراً ويتسبب في تجميد السيرفر أو إسقاط المواقع وظهور أخطاء `503 Service Unavailable`.  
> **البيلد يتم دائماً وأبداً على جهاز المطور محلياً (Locally)، ودور السيرفر هو سحب الملفات الجاهزة فقط (`git pull` أو `git reset`).**

---

### خطوات البناء والتحديث المحلي (Local Build Workflow):

#### 1. للمتجر (`storefront`):
```powershell
cd storefront
# 1. التأكد من ملف .env وأن مسار الـ API يشير إلى:
# NEXT_PUBLIC_API_URL=https://api.printexpress.com.eg/api/v1
# INTERNAL_API_URL=https://api.printexpress.com.eg/api/v1

# 2. بناء المشروع محلياً
npm run build

# 3. نسخ ملفات الـ Standalone الإلزامية (منع أخطاء 404 و ChunkLoadError)
if (!(Test-Path ".next\standalone\.next")) { New-Item -ItemType Directory -Path ".next\standalone\.next" -Force }
Copy-Item -Recurse -Force ".next\static" ".next\standalone\.next\"
Copy-Item -Recurse -Force "public" ".next\standalone\"

# 4. رفع التحديثات مع مجلد .next الجاهز إلى GitHub
git add -A
git commit -m "feat: your update message"
git push origin main
```

#### 2. للوحة التحكم (`dashboard`):
```powershell
cd dashboard
# 1. التأكد من ملف .env وأن مسار الـ API يشير إلى:
# NEXT_PUBLIC_API_URL="https://api.printexpress.com.eg/api"
# INTERNAL_API_URL="https://api.printexpress.com.eg/api"

# 2. بناء المشروع محلياً
npm run build

# 3. نسخ ملفات الـ Standalone الإلزامية
if (!(Test-Path ".next\standalone\.next")) { New-Item -ItemType Directory -Path ".next\standalone\.next" -Force }
Copy-Item -Recurse -Force ".next\static" ".next\standalone\.next\"
Copy-Item -Recurse -Force "public" ".next\standalone\"

# 4. الرفع إلى GitHub
git add -A
git commit -m "feat: your update message"
git push origin main
```

#### 3. للباك إند (`backend`):
```powershell
cd backend
# إجراء التعديلات ورفعها مباشرة
git add -A
git commit -m "feat: your update message"
git push origin main
```

---

### خطوات السحب والتشغيل على السيرفر (Server SSH Deployment):

> [!TIP]
> استخدم دائماً `git reset --hard origin/main` بدلاً من `git pull` العادي لتفادي توقف السحب بسبب أي ملفات محلية أو تعارضات (Merge Conflicts) قد تكون حدثت على السيرفر.

```bash
# 1. تحديث المتجر
cd /home/kyanfash/printexpress.com.eg
git fetch origin main && git reset --hard origin/main
pm2 restart apex-storefront

# 2. تحديث لوحة التحكم
cd /home/kyanfash/admin.printexpress.com.eg
git fetch origin main && git reset --hard origin/main
pm2 restart apex-dashboard

# 3. تحديث الباك إند
cd /home/kyanfash/api.printexpress.com.eg
git fetch origin main && git reset --hard origin/main
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
```

---

## 🔒 5. قواعد توجيه المسارات وشبكة الأمان (.htaccess)

### أ) ملف `.htaccess` للمتجر (`/home/kyanfash/printexpress.com.eg/.htaccess`):
```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /

    # 1. تمرير مسارات الـ API والـ Storage داخلياً إلى الباك إند (Proxy صامت بدون Redirect)
    RewriteRule ^api/(.*)$ https://api.printexpress.com.eg/api/$1 [P,L]
    RewriteRule ^storage/(.*)$ https://api.printexpress.com.eg/storage/$1 [P,L]

    # 2. تمرير باقي طلبات المتجر لمحرك Node Standalone (منفذ 2000)
    RewriteCond %{REQUEST_URI} !^/api
    RewriteCond %{REQUEST_URI} !^/storage
    RewriteRule ^(.*)$ http://127.0.0.1:2000/$1 [P,L]
</IfModule>
```

### ب) ملف `.htaccess` للوحة التحكم (`/home/kyanfash/admin.printexpress.com.eg/.htaccess`):
```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /

    # 1. تمرير مسارات الـ API والـ Storage داخلياً إلى الباك إند
    RewriteRule ^api/(.*)$ https://api.printexpress.com.eg/api/$1 [P,L]
    RewriteRule ^storage/(.*)$ https://api.printexpress.com.eg/storage/$1 [P,L]

    # 2. تمرير باقي طلبات الداشبورد لمحرك Node Standalone (منفذ 2050)
    RewriteCond %{REQUEST_URI} !^/api
    RewriteCond %{REQUEST_URI} !^/storage
    RewriteRule ^(.*)$ http://127.0.0.1:2050/$1 [P,L]
</IfModule>
```

### ج) ملف `.htaccess` للباك إند (`/home/kyanfash/api.printexpress.com.eg/.htaccess`):
```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /

    # حماية ملفات البيئة والإعدادات الحساسة
    RewriteRule ^\.env - [F,L,NC]
    RewriteRule ^storage/logs/ - [F,L,NC]

    # توجيه كافة الطلبات لمجلد public/index.php الخاص بـ Laravel
    RewriteCond %{REQUEST_URI} !^/public/
    RewriteRule ^(.*)$ public/$1 [L]
</IfModule>
```

---

## 🧠 6. سجل الدروس المستفادة والأخطاء الإنتاجية الحرجة (Post-Mortem Lessons)

فيما يلي توثيق تحليلي دقيق للأخطاء التي وقعت أثناء فصل ونقل الباك إند إلى ساب دومين مستقل، مع تفصيل أسبابها التقنية وكيفية تفاديها مستقبلاً:

### ⚠️ الدرس الأول: فخ الـ 301 Redirect وقوانين الـ CORS الصارمة
- **الظاهرة والأعراض:**
  - ظهور خطأ في كونسول المتصفح عند فتح الداشبورد:
    `Response to preflight request doesn't pass access control check: Redirect is not allowed for a preflight request.`
  - فشل تحميل الكوبونات والمنتجات والإحصائيات وظهور "Failed to fetch".
- **السبب التقني:**
  - عند استخدام أمر تحويل مثل `RewriteRule ^api/(.*)$ https://api... [R=301,L]`، المتصفح قبل إرسال الطلب الفعلي يرسل أولاً طلب فحص أمني `OPTIONS Preflight Request`.
  - معايير شبكة الويب (W3C CORS Specification) تنص صراحة على أن **أي استجابة تحويل (301, 302, 307) لطلب الـ Preflight تُعتبر خرقاً أمنياً وتُلغى العملية فوراً**.
- **الحل:**
  - عدم استخدام `[R=301]` لمسارات الـ API إطلاقاً.
  - إما جعل الكود يتصل مباشرة بالنطاق الرسمي للـ API (`https://api.printexpress.com.eg`)، أو استخدام الـ Reverse Proxy الداخلي الصامت `[P,L]` في ملفات `.htaccess`.

---

### ⚠️ الدرس الثاني: تحويل طلبات الـ POST إلى GET وأخطاء 404 المضللة
- **الظاهرة والأعراض:**
  - ظهور أخطاء `404 Not Found` على مسارات مثل:
    `GET https://api.printexpress.com.eg/api/v1/storefront/cart 404`
    `GET https://api.printexpress.com.eg/api/v1/storefront/chat/conversations 404`
    رغم أن الكود البرمجي يرسل طلباً من نوع `POST`.
- **السبب التقني:**
  - معيار بروتوكول HTTP الكلاسيكي يفرض على المتصفحات عند تلقي كود تحويل `301 Moved Permanently` أو `302 Found` أن تعيد إرسال الطلب بعنوانه الجديد كطلب **`GET`**.
  - وبما أن مسارات السلة والمحادثات في Laravel معرفة كـ `Route::post(...)` فقط، رد الخادم بـ `404 Not Found` لعدم وجود مسار يقبل `GET`.
- **الحل:**
  - ضبط الـ Frontend للاتصال مباشرة بالـ API الجديد دون المرور بأي وسيط تحويل.

---

### ⚠️ الدرس الثالث: انقطاع بورت 8000 وظهور شاشة "المنتج غير موجود"
- **الظاهرة والأعراض:**
  - ظهور صفحة سوداء تحتوي على عبارة حمراء: "المنتج غير موجود"، وتعليق قسم الـ Print Station في دوران لودنج مستمر (Spinner).
- **السبب التقني:**
  - في صفحات المتجر، يقوم خادم Next.js في الـ SSR بجلب تفاصيل المنتج عبر دالة `fetchProductById`.
  - كان كود `lib/api.ts` يحتوي على قيمة احتياطية مبرمجة يدوياً (Hardcoded Fallback):
    `return process.env.INTERNAL_API_URL || 'http://127.0.0.1:8000/api/v1';`
  - عند إغلاق بورت `8000` وتشغيل لارافيل عبر LSPHP، فشلت طلبات الخادم فوراً بـ `ECONNREFUSED`، فرجعت الدالة بـ `null` وعرضت الصفحة شاشة الخطأ.
- **الحل:**
  - تصحيح كافة قيم الـ Fallbacks في الكود المصدري في ملفات `lib/api.ts` لتشير للساب دومين الجديد `https://api.printexpress.com.eg`.

---

### ⚠️ الدرس الرابع: تعارضات Git على السيرفر وسقوط المنافذ بـ 503
- **الظاهرة والأعراض:**
  - توقف المتجر والداشبورد بالكامل وظهور صفحة LiteSpeed:
    `503 Service Unavailable: The server is temporarily busy, try again later!`
- **السبب التقني:**
  - عند تعديل ملفات يدوياً على السيرفر (مثل `.htaccess` أو `.env`)، يصبح الـ Working Tree على السيرفر غير نظيف (Dirty).
  - عند تشغيل `git pull origin main`، يرفض Git إتمام السحب لمنع الكتابة فوق الملفات المعدلة محلياً، فيفشل التحديث بصمت.
  - محاولة تشغيل عمليات بناء ثقيلة أو إعادة تشغيل PM2 بملفات مكسورة يسقط العمليات ويغلق البورتات `2000` و `2050`.
- **الحل:**
  - استخدام أمر المطابقة القسرية النظيفة دائماً:
    `git fetch origin main && git reset --hard origin/main`
  - تشغيل PM2 من ملف الإدارة الموحد:
    `pm2 delete all && pm2 start /home/kyanfash/ecosystem.config.js && pm2 save --force`

---

## 🩺 7. أوامر المتابعة والفحص السريع (Health Check Cheat Sheet)

```bash
# 1. التحقق من حالة عمليات PM2 واستخدام الذاكرة (يجب ألا تتعدى 350M)
pm2 status

# 2. متابعة السجلات الحية عند وجود أي استفسار
pm2 logs apex-storefront --lines 30
pm2 logs apex-dashboard --lines 30

# 3. فحص استجابة الخوادم محلياً من داخل السيرفر (Curl Ports)
curl -I http://127.0.0.1:2000
curl -I http://127.0.0.1:2050

# 4. فحص النطاقات الحية والتأكد من إرجاع كود 200 OK
curl -I https://printexpress.com.eg
curl -I https://admin.printexpress.com.eg/login
curl -I https://api.printexpress.com.eg
```

---

## 🔑 8. بيانات الدخول والاعتمادات الرسمية (System Credentials)

- **رابط لوحة التحكم:** `https://admin.printexpress.com.eg`
- **حساب الإدارة:** `test@example.com`
- **كلمة المرور:** `password`
- **الصلاحية:** `Super Admin`
- **مستخدم السيرفر (cPanel / SSH):** `kyanfash`
- **مستودعات GitHub المعتمدة:**
  - واجهة المتجر: `https://github.com/ahmed-abdel-aal-a/printexpress.com.eg.git`
  - لوحة التحكم: `https://github.com/ahmed-abdel-aal-a/admin.printexpress.com.eg.git`
  - الباك إند: `https://github.com/ahmed-abdel-aal-a/apex-backend.git`
  - المستودع المجمع: `https://github.com/ahmed-abdel-aal-a/apex-store-v2.git`
