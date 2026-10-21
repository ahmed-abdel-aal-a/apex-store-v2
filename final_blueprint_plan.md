# خطة التنفيذ الشاملة (Final Blueprint & Roadmap) - الإصدار الأمني النهائي

تم تحديث هذه الخطة لتشمل كافة المتطلبات الهندسية الدقيقة وتأمين النظام ضد الحالات الاستثنائية والثغرات الأمنية (Security & Architecture)، مما يجعله مضاداً للرصاص بنسبة 100%.

## الميزات والتحديثات المحورية

### 1. تأمين مرفقات الخدمات الإضافية (Addon Uploads Security)
- **IDOR & Security Validation**: لمنع المتطفلين من ربط ملفات تعود لعملاء آخرين باستخدام `temp_file_id` مسروق أو مُخمن، سيتم تطبيق `Ownership Validation` صارم في الـ Backend. لن يتم قبول أي ملف مؤقت إلا إذا كان متطابقاً مع الـ `session_id` الحالي أو الـ `user_id` الموثق.
- **Architecture Flow (Cart vs Checkout)**: تم تعديل البنية لتصبح السلة هي المركز الحقيقي. الـ `temp_file_id` الخاص بالخدمات الإضافية سيُرسل للـ Backend **بمجرد إضافة المنتج للسلة**، وسيتم ربطه وتخزينه في جدول `cart_item_addons`. هذا يضمن عدم ضياع الملف المرفق حتى لو أغلق العميل المتصفح وعاد في اليوم التالي لإتمام الدفع.
- **Storage Bloat (Orphaned Files)**: لمنع تراكم الملفات المهملة في مجلد `temp_uploads` واستهلاك مساحة السيرفر إذا تخلى العميل عن السلة، سيتم برمجة **Cron Job** ضمن الـ `Backend Core` يعمل أوتوماتيكياً كل ليلة لحذف الملفات التي لم تكتمل دورتها وتجاوزت 48 ساعة.

### 2. توحيد السلة والهجرة الآمنة (Unified Cart & Merge Strategy)
- **Detailed Printing Invoice Safety**: منتجات الطباعة بفواتيرها التفصيلية وتسعيراتها تُخزن *بالفعل* حالياً في الـ Backend. لذلك، عملية الهجرة ستنقل فقط *المنتجات العادية* لتندمج مع نفس الـ Session. 
- **Merge Conflict Resolution**: للمنتجات العادية، ستقوم دالة الـ Migrate بجمع الكميات (Summation) للمنتجات المتطابقة وليس استبدالها (Overwrite)، مع مراعاة الحد الأقصى للمخزون (Stock Limits). 

### 3. الأداء وحماية واجهة المستخدم (Optimistic UI & Rollback)
- **API Debouncing & Sync Lock**: التعديلات على السلة ستكون فورية (Optimistic Update) مع تأخير 500 ملي ثانية (Debounce). لحماية النظام من الـ Race Condition، سيتم تطبيق `Sync Lock` (حالة Loading) يمنع العميل من الضغط على زر Checkout لمنع الإرسال الخاطئ.
- **Rollback Mechanism**: سيتم الاحتفاظ بحالة السلة السابقة (Previous State) قبل أي تعديل للتراجع فوراً إذا عاد طلب الـ API بالرفض (مثلاً: المخزون لا يكفي)، مع عرض رسالة خطأ للعميل.

### 4. تدفق الدفع وحماية الشحن والتدقيق المالي (Checkout & Financial Audit)
- **Synchronous Fallback**: في صفحة الـ Checkout، إذا فشل API شركة الشحن أو تأخر، سيسقط فوراً على **تسعيرة ثابتة احتياطية (Static Fallback Rate)**.
- **Financial Audit Flag**: عند حدوث الـ Fallback، سيتم تخزين حقل `is_fallback_shipping: true` في جدول `orders` للمراجعات المالية.
- **Asynchronous Waybill**: وظيفة إصدار البوليصة ستعمل في الخلفية لتجنب تعطيل المستخدم في واجهة الدفع.

### 5. مزامنة الـ Webhooks (Out-of-Order & Idempotency)
- **Timestamp-Based Idempotency**: سيقوم مسار الـ Webhook بمقارنة الـ `Timestamp` الوارد من شركة الشحن مع حقل `latest_shipping_update_at` لتجاهل الحالات القديمة زمنياً ومنع التكرار والإشعارات المزعجة.

---

## خارطة الطريق للتنفيذ (Implementation Roadmap)

### المرحلة الأولى: البنية التحتية الخلفية (Backend Core)
1. تحديث جداول قاعدة البيانات:
   - `orders` (بحقول `is_fallback_shipping` و `latest_shipping_update_at`).
   - `cart_item_addons` و `order_item_addons` (بحقل `file_path`).
2. إنشاء `CleanTempUploadsJob` وربطه بالـ Scheduler لتنظيف السيرفر دورياً (Storage Bloat fix).
3. تحديث `CartController` و `CartService`:
   - لإنشاء دالة الهجرة `migrate()` مع الـ Merge Strategy.
   - لتعديل دالة `addToCart` لتقبل الـ `temp_file_id` للإضافات وتوثيق ملكيته (IDOR Validation).
4. تصميم الـ `ShippingProviderInterface` و `ShippingFactory` ليدعم التسعير الاحتياطي.
5. إنشاء مسار الـ Webhook وتطبيق الـ Security Middleware ومنطق الـ Idempotency.
6. تعديل `CheckoutController` ليتعامل مع الملفات التي تم نقلها للسلة بذكاء.

### المرحلة الثانية: الواجهة الأمامية (Storefront Cart)
1. تعديل `AppContext.tsx` وتطبيق الـ API Debouncing، إدارة حالات الـ Optimistic UI، والـ Sync Lock.
2. برمجة منطق سحب السلة القديمة للمنتجات العادية وإرسالها لمسار الهجرة ثم مسحها.
3. تحديث مسار الإضافة للسلة ليُرسل الـ `temp_file_id` للـ Backend بدلاً من الاحتفاظ به لحين الـ Checkout.
4. تعديل واجهة `CartDrawer` لعرض الاستجابة القادمة من الـ API بشكل سليم وموحد.

### المرحلة الثالثة: إتمام الطلب (Checkout Finalization)
1. تعديل `checkout/page.tsx` ليعتمد على السلة الموحدة مع الـ Sync Lock.
2. تعديل الـ Payload المُرسل ليتضمن `item_type` و `cart_item_id` فقط (لأن الإضافات ستكون مسجلة مسبقاً في السلة).
3. اختبار الدورة كاملة (E2E Testing).
