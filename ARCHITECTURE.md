# 🏗️ دليل المعمارية الشامل لمشروع Apex Store V2 (Print Express)
> **ملاحظة للمطور / نموذج الذكاء الاصطناعي (AI Prompt Context):**
> هذا المستند يحتوي على المعمارية الكاملة، مسارات الملفات، قواعد البيانات، ونقاط النهاية (APIs) لمشروع **Apex Store V2 (Print Express)**. استخدم هذا الدليل كمرجع شامل ومصدر موثوق (Single Source of Truth) لإجراء أي تعديلات، إضافة ميزات، أو معالجة أخطاء دون كسر التوافقية أو تخريب المعمارية الأساسية.

---

## 📌 1. نظرة عامة على المشروع (Project Overview)
**Apex Store V2** هو منصة تجارة إلكترونية متطورة متخصصة في خدمات الطباعة الرقمية المخصصة (Print Express) والتجارة الإلكترونية العامة، وتتكون المنظومة من 3 تطبيقات رئيسية متصلة معاً:

1. **`backend` (الباك إند):**
   - **التقنية:** Laravel 11 (PHP 8.2+)
   - **قاعدة البيانات:** SQLite (`backend/database/database.sqlite`)
   - **المصادقة والأمان:** Laravel Sanctum + Spatie Permission (Roles & Permissions)
   - **البورت الافتراضي:** `http://localhost:2080` (أو `http://127.0.0.1:2080`)
   - **المسؤولية:** توفير REST APIs، إدارة العمليات الحسابية المعقدة لتسعير الطباعة، إشراف الطلبات، السلات المتروكة، الشات المباشر، والتحقق الصارم من البيانات.

2. **`storefront` (المتجر الإلكتروني للعملاء):**
   - **التقنية:** Next.js 14.2 (App Router) + TypeScript + Tailwind CSS
   - **المكتبات الأساسية:** TanStack React Query, Framer Motion, Axios, Laravel Echo / Pusher, Lucide React
   - **البورت الافتراضي:** `http://localhost:2000`
   - **المسؤولية:** عرض المنتجات، محطة الطباعة الرقمية التفاعلية (Print Station) مع حاسبة أسعار لحظية، سلة المشتريات المتقدمة، الدفع، وتحسين محركات البحث والذكاء الاصطناعي (SEO & GEO).

3. **`dashboard` (لوحة تحكم الإدارة):**
   - **التقنية:** Next.js 15.1 (App Router مع Turbopack) + TypeScript + Tailwind CSS
   - **المكتبات الأساسية:** Radix UI, React Hook Form + Zod, TanStack Table, Recharts, Swr / React Query, Lucide React
   - **البورت الافتراضي:** `http://localhost:2050`
   - **المسؤولية:** لوحة إدارة متكاملة للمنتجات، الأقسام، متغيرات الطباعة، السلات المتروكة، إعدادات الدفع والشحن، خدمة العملاء والدردشة الحية، وإدارة السيو.

---

## ⚙️ 2. إعدادات المنافذ والبيئة (Ports & Environment Configs)

### 🔴 المنافذ المعتمدة (Port Mapping)
- **الباك إند (Laravel):** `2080`
- **المتجر (Storefront):** `2000`
- **لوحة التحكم (Dashboard):** `2050`

### 📄 ملفات البيئة الحساسة:

#### أ. `backend/.env`
```env
APP_NAME=Laravel
APP_URL=http://localhost:2080
FRONTEND_URL=http://localhost:2000
DASHBOARD_URL=http://localhost:2050
SANCTUM_STATEFUL_DOMAINS=localhost:2000,127.0.0.1:2000,localhost:2050,127.0.0.1:2050
DB_CONNECTION=sqlite
```
*(ملاحظة: ملف `config/cors.php` يعتمد كلياً على `FRONTEND_URL` و `DASHBOARD_URL` للسماح بالطلبات بدون مشاكل CORS).*

#### ب. `storefront/.env.local`
```env
NEXT_PUBLIC_API_URL=http://localhost:2080/api/v1
NEXT_PUBLIC_SITE_URL=http://localhost:2000
```

#### ج. `dashboard/.env`
```env
NEXT_PUBLIC_API_URL="http://127.0.0.1:2080/api"
```

---

## 🗂️ 3. الهيكل المعماري والمسارات (Directory Tree & Architecture)

```
apex-store-v2/
├── backend/                  # Laravel 11 REST API Application
│   ├── app/
│   │   ├── Http/
│   │   │   ├── Controllers/  # متحكمات الـ API للأدمن والمتجر
│   │   │   ├── Middleware/   # حماية الجلسات، التوكن، والـ CORS
│   │   │   └── Requests/     # قواعد التحقق الصارمة (Form Requests)
│   │   ├── Models/           # نماذج Eloquent (39 موديل)
│   │   └── Services/         # خدمات الأعمال (Pricing, Upload, Shipping)
│   ├── config/               # ملفات الإعداد (cors.php, sanctum.php, etc.)
│   ├── database/
│   │   ├── migrations/       # ملفات ترحيل جداول قاعدة البيانات
│   │   └── seeders/          # بيانات البداية وحسابات الأدمن
│   └── routes/
│       ├── api.php           # جميع نقاط النهاية (148 مسار API)
│       └── channels.php      # قنوات البث المباشر (Pusher WebSockets)
│
├── storefront/               # Next.js 14 Customer Front-End
│   ├── app/
│   │   ├── layout.tsx        # الـ Layout الرئيسي مع حقن الـ Schema العام
│   │   ├── page.tsx          # الصفحة الرئيسية
│   │   ├── sitemap.ts        # خريطة الموقع الديناميكية (SEO)
│   │   ├── robots.ts         # ملف الروبوتات وتوجيهات الذكاء الاصطناعي (GEO)
│   │   ├── product/[id]/     # صفحة المنتج الفردية مع React Cache & JSON-LD
│   │   ├── shop/             # متجر المنتجات، الفلاتر، والتصنيفات
│   │   ├── print-station/    # محطة الطباعة المخصصة التفاعلية
│   │   ├── cart/             # إدارة السلة والخدمات الإضافية
│   │   ├── checkout/         # إتمام الطلب ومناطق الشحن
│   │   └── blog/             # مقالات المتجر والـ SEO
│   ├── components/           # مكونات الواجهة القابلة لإعادة الاستخدام
│   └── lib/
│       ├── api.ts            # استدعاءات API موحدة للمتجر
│       ├── cartApi.ts        # واجهة برمجية متخصصة لعمليات السلة
│       └── utils.ts          # دوال الترجمة ومساعدات التنسيق
│
└── dashboard/                # Next.js 15 Admin Dashboard
    ├── app/
    │   ├── products/         # إدارة المنتجات (بسيطة، متغيرة، وسيو)
    │   ├── printing/         # إدارة إعدادات وخوارزميات الطباعة
    │   ├── orders/           # متابعة الطلبات وحالاتها
    │   ├── abandoned-carts/  # إدارة السلات المتروكة واستردادها
    │   ├── customers/        # بيانات العملاء وسجل التصفح
    │   ├── chat/             # مركز المحادثات المباشرة مع العملاء
    │   ├── blog/             # إدارة المقالات
    │   └── settings/         # بوابات الدفع، الشحن، وإعدادات المتجر
    ├── components/
    │   ├── SEOFields.tsx     # مكون السيو مع معاينة جوجل المباشرة
    │   ├── Sidebar.tsx       # القائمة الجانبية للتنقل
    │   └── TopBar.tsx        # الشريط العلوي والإشعارات
    └── lib/
        ├── api.ts            # تهيئة Axios للوحة التحكم
        └── services/         # استدعاءات API مقسمة حسب الوحدات
```

---

## 🗄️ 4. معمارية قاعدة البيانات والنماذج (Database Models)

قاعدة البيانات تحتوي على 39 نموذجاً موزعة وظيفياً كالتالي:

### 1. التجارة الإلكترونية العامة (Core E-Commerce)
- **`Product`**: يدعم نوعين (`simple`, `variable`)، حقول المخزون، والسيو المتقدم:
  - `seo_title`, `seo_description`, `meta_keywords`, `canonical_url`, `og_image`, `is_indexable` (boolean), `schema_markup` (json).
- **`ProductVariant`**: متغيرات المنتج (مقاسات، ألوان، أسعار مستقلة، كميات).
- **`Category`**: تصنيفات المنتجات وتدعم السيو والـ Slugs الفريدة.
- **`Attribute` & `AttributeValue`**: السمات والخصائص العامة.
- **`AddonGroup` & `ProductAddon`**: مجموعات الخدمات الإضافية الملحقة بالمنتجات.
- **`StockReservation`**: حجز المخزون المؤقت أثناء عملية الـ Checkout لمنع البيع الزائد.

### 2. محرك الطباعة الرقمية (Print Station System)
نظام فريد لشركة Print Express لحساب تكلفة الطباعة بدقة متناهية:
- **`PrintingType`**: نوع الطباعة (ورق، كروت، كتب، دروع، إلخ).
- **`PrintingProductType`**: منتج الطباعة المحدد.
- **`PrintingAttribute` & `PrintingAttributeValue`**: خيارات الطباعة (نوع الورق، السلوفان، التجليد، المقاس).
- **`PrintingVolumeDiscount`**: خصومات الكمية المتدرجة للطباعة.
- **`PrintingPriceAuditLog`**: سجل تتبع أسعار الطباعة وتعديلاتها.

### 3. السلة والطلبات (Cart & Orders)
- **`Cart` & `CartItem` & `CartItemAddon`**: سلة هجينة تدعم الزوار (عبر `session_id`) وتتحول تلقائياً لحساب العميل عند تسجيل الدخول (`/cart/migrate`).
- **`CartContactHistory`**: التقاط جهات اتصال السلات غير المكتملة للتسويق.
- **`AbandonedCartsSetting`**: قواعد وإعدادات متابعة السلات المتروكة.
- **`Order` & `OrderItem` & `OrderItemAddon`**: إدارة الفواتير والمشتريات.

### 4. العملاء والتفاعل (Customers & Tracking)
- **`Customer`**: حسابات العملاء مع دعم تسجيل الدخول الاجتماعي (`CustomerSocialAccount`).
- **`CustomerBrowsingHistory`**: سجل تتبع حركة العميل لتحسين التوصيات ومبيعات الـ Up-sell.
- **`ChatConversation` & `ChatMessage`**: المحادثات الفورية بين العميل وفريق الدعم.

### 5. إدارة المنصة والمحتوى (Platform & Content)
- **`BlogPost`**: المقالات وتدعم الحقول الكاملة للـ SEO & GEO.
- **`PaymentGateway`**: بوابات الدفع الإلكتروني (مثل Kashier، الدفع عند الاستلام).
- **`ShippingCompany` & `ShippingZone`**: شركات ومناطق الشحن وتكاليفها.
- **`User`**: مدراء لوحة التحكم والصلاحيات (Spatie Roles).

---

## 🔌 5. خريطة مسارات الـ API الرئيسية (API Routes Map)

تستخدم الباك إند بادئة `/api/v1/` وتنقسم إلى قطاعين رئيسيين:

### أ. مسارات المتجر العام (`/api/v1/storefront/`)
- `GET /products` & `GET /products/{id}`: جلب المنتجات مع التصنيفات والمتغيرات.
- `GET /categories`: قائمة الأقسام النشطة.
- `POST /cart`: إنشاء أو جلب سلة المشتريات.
- `POST /cart/items`: إضافة منتج عادي أو مخصص إلى السلة.
- `POST /cart/migrate`: دمج سلة الزائر مع سلة المستخدم المسجل.
- `POST /checkout`: معالجة الطلب وحجز المخزون وتحديد بوابة الدفع.
- `POST /print/calculate-price`: حاسبة أسعار الطباعة اللحظية بناءً على الأبعاد والمواصفات والكمية.
- `POST /print/chunk-upload`: رفع ملفات التصاميم والـ PDF ذات الأحجام الكبيرة بنظام الـ Chunks.
- `POST /track`: تسجيل نشاط العميل وسجل التصفح.

### ب. مسارات لوحة التحكم (`/api/v1/admin/`) - *تتطلب Sanctum Token*
- `GET|POST /admin/products`: إدارة المنتجات مع رفع الصور وحفظ السيو.
- `POST /admin/products/bulk-delete`: حذف جماعي مع إزالة الصور من وسائط التخزين.
- `GET|POST /admin/printing-types`: ضبط أنواع الطباعة ومصفوفة الأسعار.
- `GET|PUT /admin/settings/payment/gateways/{code}`: ضبط بوابات الدفع.
- `GET|PUT /admin/settings/shipping/companies/{code}`: ضبط شركات ومناطق الشحن.
- `GET /admin/abandoned-carts`: استعراض السلات المتروكة وإعادة استهدافها.

---

## 🚀 6. مميزات معمارية السيو والذكاء الاصطناعي (SEO & GEO Specs)

تم تصميم النظام ليكون متوافقاً 100% مع محركات بحث الجيل القادم وروبوتات الذكاء الاصطناعي:
1. **React Cache Deduping:**
   في `storefront/app/product/[id]/page.tsx`، يتم استدعاء دالة جلب بيانات المنتج عبر `React.cache()` لضمان عدم تكرار طلب الـ API بين `generateMetadata` ومكون الصفحة.
2. **Dynamic JSON-LD Schema:**
   يتم توليد مخطط `Product` و `WebSite` تلقائياً مع ربط السعر وحالة التوفر بالمخزون لحظياً.
3. **XSS Sanitization في الـ JSON-LD:**
   يتم تعقيم كل كود Schema محقون برمجياً عبر استبدال وسوم فتح الـ HTML:
   ```typescript
   const safeJsonLd = JSON.stringify(finalSchema).replace(/</g, '\\u003c');
   ```
4. **GEO Explicit Directives:**
   في `storefront/app/robots.ts` تم إعطاء أذونات صريحة لروبوتات:
   `ChatGPT-User`, `OAI-SearchBot`, `PerplexityBot`, `Anthropic-ai`, `Claude-Web`, `Google-Extended`.
5. **Strict URL Validation:**
   الباك إند يرفض في الـ Validation حفظ أي روابط غير كاملة للـ Canonical URL ويشترط `starts_with:http://,https://`.

---

## 🛠️ 7. أوامر التشغيل السريع (Developer Cheat Sheet)

```bash
# 1. تشغيل الباك إند (Laravel Backend - Port 2080)
cd backend
php artisan serve --port=2080

# 2. تشغيل متجر العملاء (Storefront - Port 2000)
cd storefront
npm run dev

# 3. تشغيل لوحة التحكم (Dashboard - Port 2050)
cd dashboard
npm run dev

# 4. تحديث قاعدة البيانات
cd backend
php artisan migrate

# 5. الدخول للوحة التحكم الافتراضي:
# الرابط: http://localhost:2050
# الإيميل: admin@apex-store.test
# الباسورد: password
```

---

## ⚠️ 8. إرشادات وقواعد هندسية صارمة للمطورين (Golden Rules)
1. **ممنوع تغيير الـ Ports:** حافظ دائماً على (Storefront: `2000`, Dashboard: `2050`, Backend: `2080`).
2. **حماية التجاوب (Responsive Layouts):** أي تعديل على واجهات المستخدم في Tailwind يجب أن يحافظ على الشاشات الصغيرة والكبيرة (`sm:`, `md:`, `lg:`).
3. **التحقق المزدوج (Validation):** لا تعتمد على تحقق الفرونت إند فقط؛ أي حقل جديد في قاعدة البيانات يجب تحديثه في `StoreProductRequest` و `UpdateProductRequest` وفي `$fillable` و `$casts`.
4. **تزامن CORS:** إذا قمت بتغيير أي نطاق أو بورت، يجب تحديث `backend/.env` في المتغيرين `FRONTEND_URL` و `DASHBOARD_URL`.
