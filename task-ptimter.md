# ملف المهام التفصيلي: نظام الطباعة V14 (Fortress Edition)
**كل مهمة مكتوبة بحيث لو طفل قرأها يقدر ينفذها بدقة 100% بدون تفكير**

> [!IMPORTANT]
> **قواعد عامة (اقرأها قبل ما تلمس الكيبورد):**
> - **العملة:** الجنيه المصري (EGP) فقط. كل الأسعار تُخزن **بالقرش** كـ `BigInteger` في جداول الطباعة (يعني 50 جنيه = `5000`). وعند الحفظ في `cart_items` أو `order_items` الأساسية يتم القسمة على 100 لتصبح `Decimal` للحفاظ على التوافق.
> - **القياسات:** كل الأبعاد الفيزيائية تُخزن **بالمليمتر (mm)** (يعني 10 سم = `100`).
> - **الأسعار في الكود:** أي عملية حسابية سعرية في PHP تستخدم `bcmul()`, `bcadd()`, `bcsub()`, `bcdiv()` من مكتبة **BCMath**. ممنوع استخدام `*` أو `+` أو `-` أو `/` للأسعار نهائياً.
> - **النسب المئوية:** الخصومات والضرائب تُخزن بنظام **Basis Points** كـ Integer (يعني 14.5% = `1450`، تُقسم على `10000` بـ BCMath).
> - **التقريب:** بعد أي عملية حسابية بـ BCMath، يجب تطبيق **تقريب لأقرب قرش لأعلى (Ceil)** لصالح المطبعة باستخدام دالة `bcceil()` (التفاصيل في المرحلة 3).
> - **المسار:** كل ملفات الباك إند في `D:\important projects\apex-store-v2\backend`.

> [!CAUTION]
> **🚨 توجيه حرج وصارم جداً (CRITICAL DIRECTIVE):**
> **ممنوع منعاً باتاً كتابة أي حرف كود، أو تعديل أي ملف، أو تنفيذ أي أمر، دون تسجيله فوراً وبالتفصيل الممل في ملف الـ Changelog (سجل التغييرات).**
> **أي تجاوز لهذه القاعدة يعتبر خرقاً معمارياً مرفوضاً. تم التشديد المطلق على هذه النقطة!**

---

## المرحلة 1: Database Migrations (قواعد البيانات)

### `[x]` 1.1 إنشاء Migration: `create_printing_product_types_table`
- **الملف:** `database/migrations/2026_08_02_010000_create_printing_product_types_table.php`
- **الأعمدة بالترتيب:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->id();` | المعرف |
| 2 | `$table->string('name');` | اسم القسم (مثل: "كتب ومطبوعات ورقية") |
| 3 | `$table->text('description')->nullable();` | وصف القسم (اختياري) |
| 4 | `$table->string('icon')->nullable();` | اسم أيقونة Lucide (مثل: `BookOpen`) |
| 5 | `$table->boolean('is_active')->default(true);` | مفعل أو لا |
| 6 | `$table->boolean('allow_custom_name')->default(false);` | هل يسمح للعميل يكتب اسم منتج مخصص (مثل "رواية الأمل") |
| 7 | `$table->integer('sort_order')->default(0);` | ترتيب الظهور في الواجهة |
| 8 | `$table->timestamps();` | |
| 9 | `$table->softDeletes();` | حذف ناعم (عشان الطلبات القديمة متتكسرش) |

- **في الـ `down()`:** `Schema::dropIfExists('printing_product_types');`

---

### `[x]` 1.2 إنشاء Migration: `create_printing_types_table`
- **الملف:** `database/migrations/2026_08_02_010001_create_printing_types_table.php`
- **الأعمدة بالترتيب:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->id();` | |
| 2 | `$table->foreignId('printing_product_type_id')->constrained('printing_product_types')->cascadeOnDelete();` | ربط بالقسم الأب |
| 3 | `$table->string('name');` | اسم النوع (مثل: "ديجيتال") |
| 4 | `$table->text('description')->nullable();` | |
| 5 | `$table->enum('pricing_method', ['fixed', 'attributes_only', 'area']);` | **طريقة التسعير** |
| 6 | `$table->bigInteger('base_price_fixed')->default(0);` | سعر ثابت أساسي (بالقرش) |
| 7 | `$table->bigInteger('base_price_unit')->default(0);` | سعر للنسخة (بالقرش) |
| 8 | `$table->bigInteger('base_price_multiplier')->default(0);` | سعر يُضرب في المعامل (بالقرش) |
| 9 | `$table->integer('min_quantity')->default(1);` | أقل كمية مسموحة |
| 10 | `$table->integer('quantity_step')->default(1);` | مضاعفات الكمية (يعني 1 أو 50 أو 100) |
| 11 | `$table->bigInteger('min_chargeable_area')->default(0);` | الحد الأدنى للمساحة المحاسبية (mm²) |
| 12 | `$table->bigInteger('min_chargeable_price')->default(0);` | **الحد الأدنى للـ Subtotal قبل الضريبة (بالقرش)** |
| 13 | `$table->boolean('is_active')->default(true);` | |
| 14 | `$table->boolean('requires_upload')->default(false);` | هل يجبر رفع ملف |
| 15 | `$table->json('upload_categories')->nullable();` | فئات الملفات الأساسية المطلوبة `["cover", "inner_pages"]` |
| 16 | `$table->json('standard_roll_sizes')->nullable();` | مقاسات الرولات بالمم `[1200, 2400, 3200]` |
| 17 | `$table->integer('max_print_width')->nullable();` | أقصى عرض طباعة فيزيائي (mm) |
| 18 | `$table->integer('max_print_length')->nullable();` | أقصى طول طباعة فيزيائي (mm) |
| 19 | `$table->integer('bleed_margin')->default(0);` | هوامش القص (mm) |
| 20 | `$table->integer('safe_zone')->default(0);` | منطقة الأمان (mm) |
| 21 | `$table->integer('thickness_factor')->default(0);` | **[V14] معامل سمك المنتج النهائي بالمم (مثلاً: 3mm لرول بنر، أو 0 للكروت المسطحة). يُستخدم لحساب الوزن الحجمي بشكل عام لأي منتج سواء فيه صفحات أو لا.** |
| 22 | `$table->integer('base_production_days')->default(1);` | أيام الإنتاج الأساسية |
| 23 | `$table->integer('sort_order')->default(0);` | |
| 24 | `$table->timestamps();` | |
| 25 | `$table->softDeletes();` | |

> [!NOTE]
> **ملاحظة V14:** الوزن الحجمي يُحسب ديناميكياً في الـ `PrintPricingService` كالتالي:
> - **لو المنتج فيه صفحات (كتاب):** السماكة = `عدد الصفحات × thickness_factor` (حيث `thickness_factor` = سمك ورقة واحدة بالمم).
> - **لو المنتج مفيش فيه صفحات (بنر/كروت):** السماكة = `thickness_factor` مباشرة (يعني قيمة ثابتة مثلاً 3mm لسمك الرول أو 1mm للكارت).
> - **لو `thickness_factor = 0`:** النظام يتجاهل الوزن الحجمي ويعتمد على الوزن الفعلي فقط.

---

### `[x]` 1.3 إنشاء Migration: `create_printing_attributes_table`
- **الملف:** `database/migrations/2026_08_02_010002_create_printing_attributes_table.php`
- **الأعمدة بالترتيب:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->id();` | |
| 2 | `$table->foreignId('printing_type_id')->constrained('printing_types')->cascadeOnDelete();` | ربط بنوع الطباعة |
| 3 | `$table->string('name');` | الاسم البرمجي (مثل: `paper_size`) |
| 4 | `$table->string('label');` | الاسم الظاهر للعميل (مثل: "مقاس الورق") |
| 5 | `$table->enum('type', ['select', 'radio', 'checkbox', 'number', 'multiplier_number']);` | نوع الحقل |
| 6 | `$table->enum('step', ['specifications', 'finishing']);` | ينتمي لخطوة (المواصفات / التشطيبات) |
| 7 | `$table->boolean('is_required')->default(false);` | |
| 8 | `$table->integer('sort_order')->default(0);` | |
| 9 | `$table->integer('min_value')->nullable();` | أقل قيمة (لحقول الأرقام) |
| 10 | `$table->integer('max_value')->nullable();` | أكبر قيمة |
| 11 | `$table->json('conditional_rules')->nullable();` | قواعد الإظهار/الإخفاء الشرطية |
| 12 | `$table->string('linked_upload_category')->nullable();` | ربط بفئة ملف للتحقق (مثل: `inner_pages`) |
| 13 | `$table->boolean('is_dimension_width')->default(false);` | الفلاج الديناميكي: هل هذا الحقل هو العرض |
| 14 | `$table->boolean('is_dimension_length')->default(false);` | الفلاج الديناميكي: هل هذا الحقل هو الطول |
| 15 | `$table->timestamps();` | |
| 16 | `$table->softDeletes();` | **[تحديث أمني V14] لمنع ضياع بيانات الطلبات القديمة عند حذف الخاصية** |

- **إضافة أمنية في الـ Controller:** يجب تفعيل `Rule::unique` مع الـ `printing_type_id` لمنع تحديد أكثر من `is_dimension_width` أو `is_dimension_length` في نفس النوع.

---

### `[x]` 1.4 إنشاء Migration: `create_printing_attribute_values_table`
- **الملف:** `database/migrations/2026_08_02_010003_create_printing_attribute_values_table.php`
- **الأعمدة بالترتيب:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->id();` | |
| 2 | `$table->foreignId('printing_attribute_id')->constrained('printing_attributes')->cascadeOnDelete();` | ربط بالمتغير الأب |
| 3 | `$table->string('value');` | القيمة البرمجية (`a4`, `coated_150`) |
| 4 | `$table->string('label');` | القيمة الظاهرة ("A4", "كوشيه 150 جرام") |
| 5 | `$table->bigInteger('fixed_price')->default(0);` | سعر ثابت يُضاف مرة واحدة (بالقرش) |
| 6 | `$table->bigInteger('unit_price')->default(0);` | سعر يُضرب في الكمية فقط (بالقرش) - مثل الحلقات والدبابيس |
| 7 | `$table->bigInteger('multiplier_price')->default(0);` | سعر يُضرب في المعامل/المساحة (بالقرش) - مثل خامة البنر |
| 8 | `$table->decimal('weight', 8, 4)->default(0);` | الوزن الفعلي (بالجرام) |
| 9 | `$table->enum('weight_type', ['per_unit', 'per_sqm'])->default('per_unit');` | محدد حساب الوزن |
| 10 | `$table->json('tiered_prices')->nullable();` | أسعار متدرجة (كل الأسعار بداخله بالقرش) |
| 11 | `$table->integer('added_production_days')->default(0);` | أيام إنتاج إضافية |
| 12 | `$table->string('required_upload_category')->nullable();` | الرفع المشروط باختيار هذه القيمة |
| 13 | `$table->integer('sort_order')->default(0);` | |
| 14 | `$table->timestamps();` | |
| 15 | `$table->softDeletes();` | **[تحديث أمني V14] لمنع ضياع بيانات الطلبات القديمة عند الحذف** |

---

### `[x]` 1.5 إنشاء Migration: `create_printing_volume_discounts_table`
- **الملف:** `database/migrations/2026_08_02_010004_create_printing_volume_discounts_table.php`
- **الأعمدة بالترتيب:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->id();` | |
| 2 | `$table->foreignId('printing_type_id')->constrained('printing_types')->cascadeOnDelete();` | |
| 3 | `$table->integer('min_qty');` | أقل كمية في الشريحة |
| 4 | `$table->integer('max_qty');` | أكبر كمية في الشريحة |
| 5 | `$table->integer('discount_basis_points');` | **الخصم كعدد صحيح (1050 = 10.5%) ويُقسم على 10000 بـ BCMath** |
| 6 | `$table->integer('added_production_days')->default(0);` | أيام إضافية للكميات الكبيرة |
| 7 | `$table->timestamps();` | |

- **إضافة [تحديث أمني V14]:** `$table->unique(['printing_type_id', 'min_qty', 'max_qty'], 'vol_discount_unique');` لمنع تداخل الشرائح في الـ DB. يجب أيضاً تطبيق Validation منطقي في الـ Controller لضمان عدم وجود تداخل (Overlapping) أو أن يكون الحد الأدنى أكبر من الأقصى.

---

### `[x]` 1.6 إنشاء Migration: `create_printing_price_audit_log_table`
- **الملف:** `database/migrations/2026_08_02_010005_create_printing_price_audit_log_table.php`
- **الأعمدة بالترتيب:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->id();` | |
| 2 | `$table->string('auditable_type');` | اسم الموديل (`PrintingType`, `PrintingAttributeValue`) |
| 3 | `$table->unsignedBigInteger('auditable_id');` | معرف السجل |
| 4 | `$table->string('field_name');` | اسم العمود (`unit_price`) |
| 5 | `$table->text('old_value')->nullable();` | القيمة القديمة |
| 6 | `$table->text('new_value')->nullable();` | القيمة الجديدة |
| 7 | `$table->unsignedBigInteger('changed_by');` | ID المدير |
| 8 | `$table->timestamps();` | |
| 9 | `$table->index(['auditable_type', 'auditable_id']);` | **Index مركب** |

---

### `[x]` 1.7 إنشاء Migration: `add_printing_columns_to_order_items_table`
- **الملف:** `database/migrations/2026_08_02_010006_add_printing_columns_to_order_items_table.php`
- **في الـ `up()`:** `Schema::table('order_items', function (Blueprint $table) { ... });`
- **الأعمدة المضافة:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->string('item_type')->default('standard');` | `standard` أو `printing` |
| 2 | `$table->foreignId('printing_type_id')->nullable()->constrained('printing_types')->nullOnDelete();` | |
| 3 | `$table->string('custom_product_name')->nullable();` | اسم مخصص (مثل "رواية الأمل") |
| 4 | `$table->json('printing_options')->nullable();` | Snapshot كامل وقت الطلب |
| 5 | `$table->json('uploaded_files')->nullable();` | روابط الملفات مصنفة |
| 6 | `$table->string('file_status')->default('not_applicable');` | `not_applicable`, `pending_upload`, `processing`, `approved`, `rejected` |
| 7 | `$table->text('file_rejection_reason')->nullable();` | |
| 8 | `$table->date('estimated_delivery_date')->nullable();` | |
| 9 | `$table->integer('tax_basis_points_snapshot')->default(0);` | **تجميد الضريبة كـ Basis Points** |
| 10 | `$table->foreignId('source_order_item_id')->nullable()->constrained('order_items')->nullOnDelete();` | للربط بطلب سابق (Reorder) |

- **في الـ `down()`:** حذف كل الأعمدة بالاسم.

---

### `[x]` 1.8 إنشاء Migration: `add_printing_columns_to_cart_items_table`
- **الملف:** `database/migrations/2026_08_02_010007_add_printing_columns_to_cart_items_table.php`
- **في الـ `up()`:** `Schema::table('cart_items', function (Blueprint $table) { ... });`
- **الأعمدة المضافة:**

| # | الكود بالظبط | الوصف |
|---|---|---|
| 1 | `$table->string('item_type')->default('standard');` | |
| 2 | `$table->foreignId('printing_type_id')->nullable()->constrained('printing_types')->nullOnDelete();` | |
| 3 | `$table->string('custom_product_name')->nullable();` | |
| 4 | `$table->json('printing_options')->nullable();` | |
| 5 | `$table->json('uploaded_files')->nullable();` | |
| 6 | `$table->string('file_status')->default('not_applicable');` | **نفس الحالات لتتبع فحص الملف في السلة** |
| 7 | `$table->text('file_rejection_reason')->nullable();` | **[تحديث أمني V14] لضمان عمل Job الفحص دون أخطاء** |
| 8 | `$table->integer('tax_basis_points_snapshot')->default(0);` | **تجميد الضريبة في السلة عشان السعر مايتغيرش على العميل** |
| 9 | `$table->timestamp('quote_expires_at')->nullable();` | تاريخ انتهاء صلاحية السعر |

- **تعديل آمن للـ FK على `product_id` (تحديث V14):**
  بدلاً من التعديل المباشر الذي قد يُسقط القيد، يتم تنفيذه بشكل آمن:
  ```php
  $table->dropForeign(['product_id']);
  $table->foreignId('product_id')->nullable()->change();
  $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
  ```
- **في الـ `down()`:** حذف كل الأعمدة بالاسم وإرجاع قيد `product_id`.

---

## المرحلة 2: Eloquent Models

### `[x]` 2.1 إنشاء Model: `PrintingProductType`
- **الملف:** `app/Models/PrintingProductType.php`
- `use SoftDeletes;`
- `$fillable`: `['name', 'description', 'icon', 'is_active', 'allow_custom_name', 'sort_order']`
- `$casts`: `['is_active' => 'boolean', 'allow_custom_name' => 'boolean']`
- **العلاقة:** `printingTypes()` → `hasMany(PrintingType::class)`

### `[x]` 2.2 إنشاء Model: `PrintingType`
- **الملف:** `app/Models/PrintingType.php`
- `use SoftDeletes;`
- `$fillable`: كل الأعمدة ما عدا `id`, `timestamps`, `deleted_at` (شاملة `thickness_factor`).
- `$casts`: `['is_active' => 'boolean', 'requires_upload' => 'boolean', 'upload_categories' => 'array', 'standard_roll_sizes' => 'array']`
- **العلاقات:**
  - `productType()` → `belongsTo(PrintingProductType::class, 'printing_product_type_id')`
  - `attributes()` → `hasMany(PrintingAttribute::class)`
  - `volumeDiscounts()` → `hasMany(PrintingVolumeDiscount::class)`

### `[x]` 2.3 إنشاء Model: `PrintingAttribute`
- **الملف:** `app/Models/PrintingAttribute.php`
- `use SoftDeletes;` **[تحديث أمني V14]**
- `$fillable`: كل الأعمدة ما عدا `id`, `timestamps`, `deleted_at`.
- `$casts`: `['is_required' => 'boolean', 'conditional_rules' => 'array', 'is_dimension_width' => 'boolean', 'is_dimension_length' => 'boolean']`
- **العلاقات:**
  - `printingType()` → `belongsTo(PrintingType::class)`
  - `values()` → `hasMany(PrintingAttributeValue::class)`

### `[x]` 2.4 إنشاء Model: `PrintingAttributeValue`
- **الملف:** `app/Models/PrintingAttributeValue.php`
- `use SoftDeletes;` **[تحديث أمني V14]**
- `$fillable`: كل الأعمدة ما عدا `id`, `timestamps`, `deleted_at`.
- `$casts`: `['tiered_prices' => 'array']`
- **العلاقة:** `attribute()` → `belongsTo(PrintingAttribute::class, 'printing_attribute_id')`

### `[x]` 2.5 إنشاء Model: `PrintingVolumeDiscount`
- **الملف:** `app/Models/PrintingVolumeDiscount.php`
- `$fillable`: `['printing_type_id', 'min_qty', 'max_qty', 'discount_basis_points', 'added_production_days']`
- **العلاقة:** `printingType()` → `belongsTo(PrintingType::class)`

### `[x]` 2.6 إنشاء Model: `PrintingPriceAuditLog`
- **الملف:** `app/Models/PrintingPriceAuditLog.php`
- `$fillable`: كل الأعمدة ما عدا `id`, `timestamps`.
- **العلاقة:** `auditable()` → `morphTo()`

### `[x]` 2.7 تعديل Model: `OrderItem`
- **الملف:** `app/Models/OrderItem.php`
- **[إصلاح باج قديم V14]:** إضافة `'variant_id', 'total'` للـ `$fillable` لضمان عدم ضياع بيانات الطلبات العادية.
- **إضافة للـ `$fillable`:** كل الأعمدة الجديدة من المرحلة 1.7.
- **إضافة `$casts`:** `'printing_options' => 'array'`, `'uploaded_files' => 'array'`, `'estimated_delivery_date' => 'date'`.
- **علاقة جديدة:** `printingType()` → `belongsTo(PrintingType::class)`
- **علاقة جديدة:** `sourceOrderItem()` → `belongsTo(OrderItem::class, 'source_order_item_id')`

### `[x]` 2.8 تعديل Model: `CartItem`
- **الملف:** `app/Models/CartItem.php`
- **[إصلاح معماري V14]:** استدعاء المسار المفقود للـ Factory بإضافة `use Illuminate\Database\Eloquent\Factories\HasFactory;` في الأعلى.
- **إضافة `$casts`:** `'printing_options' => 'array'`, `'uploaded_files' => 'array'`, `'quote_expires_at' => 'datetime'`.
- **علاقة جديدة:** `printingType()` → `belongsTo(PrintingType::class)`

---

## المرحلة 3: Backend Services & Jobs (قلب المنطق V14)

### `[x]` 3.1 دالة مساعدة: `bcceil()` (حل فخ التقريب)
- **المشكلة:** `bcdiv('109', '10', 0)` تعطي `10` مش `11`. لأن `bcdiv` بتقص الكسر ومبتقربوش!
- **الحل:** إنشاء دالة Helper اسمها `bcceil` في ملف `app/Helpers/MoneyHelper.php`:
```php
/**
 * تقريب لأقرب عدد صحيح لأعلى دائماً (لصالح المطبعة).
 */
function bcceil(string $value): string
{
    if (strpos($value, '.') !== false) {
        $parts = explode('.', $value);
        if (isset($parts[1]) && bccomp($parts[1], '0') > 0) {
            return bcadd($parts[0], '1', 0);
        }
        return $parts[0];
    }
    return $value;
}
```
- **قاعدة صارمة:** بعد أي عملية حسابية نهائية، مرر الناتج على `bcceil()`.

---

### `[x]` 3.2 إنشاء Service: `PrintPricingService`
- **الملف:** `app/Services/PrintPricingService.php`
- **القاعدة الأولى:** هذه الخدمة تُستدعى لحظة إنشاء الـ Payment Intent. **تتجاهل تماماً** أي أرقام مرسلة من الواجهة وتقرأ الأسعار من الداتابيز مباشرة.

#### الخوارزمية بالترتيب الصارم (خطوة بخطوة):

**الخطوة 0: تحديد طريقة التسعير (Pricing Method Branching)**

> [!CAUTION]
> **ممنوع** تطبيق نفس المعادلة على كل أنواع المنتجات. لازم التفريع حسب `pricing_method`:

```
if pricing_method === 'fixed':
    Subtotal = base_price_fixed
             + Sum(fixed_options)
             + (Sum(unit_options) × Qty)
             + (Sum(multiplier_options) × multiplier_value × Qty)
    // ⚠️ لا يوجد ضرب في المساحة نهائياً!

elseif pricing_method === 'attributes_only':
    Subtotal = Sum(fixed_options)
             + (Sum(unit_options) × Qty)
             + (Sum(multiplier_options) × multiplier_value × Qty)
    // ⚠️ لا يوجد base_price ولا مساحة!

elseif pricing_method === 'area':
    Area_mm2 = width_mm × length_mm
    Effective_Area = max(Area_mm2, min_chargeable_area)
    Area_m2 = bcdiv(Effective_Area, '1000000', 4)  // تحويل لمتر مربع
    Subtotal = base_price_fixed
             + (Sum(unit_options) × Qty)
             + (Sum(multiplier_options) × Area_m2 × Qty)
    // ⚠️ الـ unit_options لا تُضرب في المساحة أبداً!
```

**الخطوة 1: تطبيق الحد الأدنى (على الـ Subtotal قبل الضريبة)**
```
Subtotal = max(Subtotal, min_chargeable_price)
```
> [!CAUTION]
> **الحد الأدنى يُطبق قبل الضريبة وليس بعدها!**

**الخطوة 2: تطبيق خصم الكمية (Volume Discount)**
```
$discountRaw = bcdiv(bcmul($subtotal, $discountBasisPoints), '10000', 4);
$discountAmount = bcceil($discountRaw);
$afterDiscount = bcsub($subtotal, $discountAmount);
```

**الخطوة 3: تطبيق الضريبة (Tax - Basis Points)**
```
$taxRaw = bcdiv(bcmul($afterDiscount, $taxBasisPoints), '10000', 4);
$taxAmount = bcceil($taxRaw);
$finalTotal = bcadd($afterDiscount, $taxAmount);
```

**الخطوة 4: حساب الأوزان (تصحيح وحدة الكيلوجرام)**
- **الوزن الفعلي (Physical Weight):**
  - للـ `per_unit`: `totalWeight = Sum(weight × qty)`.
  - للـ `per_sqm`: يجب استخدام نفس `$areaM2`.
  - **يُحول إلى كيلوجرام** بالقسمة على 1000: `Physical_Weight_KG`.
- **الوزن الحجمي (Volumetric Weight):**
  - لو `thickness_factor > 0` وفيه صفحات → السماكة = `العدد × thickness_factor` (mm).
  - لو مفيش صفحات → السماكة = `thickness_factor` (mm).
  - `Volumetric_Weight_KG = (width_mm × length_mm × thickness_mm) / 5000000` (الناتج كجم).
  - `Billable_Weight_KG = max(Physical_Weight_KG, Volumetric_Weight_KG)`.

**الخطوة 5: التوافق المالي (Pricing Compatibility) - [تحديث V14]**
- يتم تحويل `finalTotal` من قرش إلى جنيه بالقسمة على 100 قبل حفظه كـ `Decimal` في جدول `order_items` و `cart_items` ليتوافق مع النظام الأساسي:
  `$finalPriceInEGP = bcdiv($finalTotal, '100', 2);`

---

### `[x]` 3.3 إنشاء Job: `ValidatePrintFileJob` (Async Pre-Payment Sandbox)
- **الملف:** `app/Jobs/ValidatePrintFileJob.php`

> [!CAUTION]
> **حماية من PDF Bomb:** لازم الـ Job يتحدد له حدود صارمة:
> ```php
> public $timeout = 120;       // أقصى مدة 120 ثانية
> public $maxExceptions = 1;   // لو فشل مرة، يموت
> public $tries = 1;           // لا يُعاد المحاولة
> ```
> وكمان أمر الـ Ghostscript نفسه يتنفذ بـ `Process::timeout(60)` ويستخدم فلاج `-dSAFER`.

- **دورة العمل الكاملة:**
  1. العميل يرفع الملف من السلة → يتخزن في S3.
  2. الواجهة تُرسل request للـ API.
  3. الباك إند يرسل `ValidatePrintFileJob` للـ Queue.
  4. الـ Job يفحص بـ Sandbox.
  5. **لو نجح:** يُحدّث `cart_items.file_status` → `approved` ويرسل WebSocket Event.
  6. **لو فشل:** يُحدّث `file_status` → `rejected` ويكتب سبب الرفض ويرسل Event.

---

### `[x]` 3.4 إعداد البنية التحتية للـ WebSocket (Broadcasting) - [مهمة V14]
- **الهدف:** تجهيز الباك إند لإرسال Events للواجهة.
- تثبيت Laravel Reverb أو Pusher من الصفر لأن النظام لا يحتوي عليه.
- إعداد الـ Configuration في `config/broadcasting.php` وتحديث `.env`.
- إنشاء Event `PrintFileValidationCompleted` يُطبق واجهة `ShouldBroadcast`.

### `[x]` 3.5 مرونة الواجهة: HTTP Polling كبديل للـ WebSocket
- **الحل المزدوج للواجهة:**
  1. تستمع للـ Event من Laravel Echo كأولوية.
  2. **وفي نفس الوقت:** تعمل HTTP Polling كل 5 ثوانٍ (`GET /api/print/file-status`).
  3. أول ما ترجع `approved` عبر أي طريقة، يتوقف الـ Polling ويُفتح الدفع.

### `[x]` 3.6 متطلبات النظام الأساسية - [مهمة V14]
- إضافة `ext-bcmath` إلى مصفوفة الـ `require` في `composer.json` لتفعيل مكتبة الرياضيات الدقيقة.

---

## المرحلة 4: تشغيل الـ Migrations والتحقق

### `[x]` 4.1 تشغيل `php artisan migrate`
- يجب ألا يظهر أي Error.

### `[x]` 4.2 تشغيل `php artisan migrate:rollback` ثم `php artisan migrate`
- التأكد أن الـ `down()` بتاعة كل Migration شغالة صح.

---

## المرحلة 5: Backend API Controllers

### `[x]` 5.1 إنشاء Controller: `PrintingProductTypeController` (CRUD كامل)
### `[x]` 5.2 إنشاء Controller: `PrintingTypeController` (CRUD + إدارة الخيارات)
### `[x]` 5.3 إنشاء Controller: `PrintingAttributeController` (CRUD + الترتيب)
### `[x]` 5.4 إنشاء Controller: `PrintingAttributeValueController` (CRUD + الأسعار)
### `[x]` 5.5 تعديل `CheckoutController` (تحديث العصب - V14)]
- تجاوز نظام الفحص الخاص بالمخزون (Inventory Check/Decrement) وضرورة وجود `product_id` للمنتجات التي نوعها `printing` للسماح بإتمام عمليات الدفع.

---

## المرحلة 6: Frontend - Dashboard (مرحلة لاحقة)

### `[x]` 6.1 صفحة إدارة أقسام المطبوعات (CRUD)
- استخدام `@tanstack/react-query` لجلب البيانات للتوافق مع قسم المنتجات الحالي بدلاً من SWR.
### `[x]` 6.2 صفحة إدارة أنواع الطباعة + منشئ الخيارات الديناميكي
### `[x]` 6.3 مكون مراجعة الملفات المرفوعة (Approve / Reject + سبب الرفض)

---

## المرحلة 7: Frontend - Storefront (مرحلة لاحقة)

### `[ ]` 7.1 استبدال `mockApi.ts` بجلب ديناميكي من الـ API
### `[ ]` 7.2 تحديث `usePrintConfig.ts` للعمل مع البيانات الديناميكية
### `[ ]` 7.3 تحديث `DynamicOptions.tsx` لبناء الحقول ديناميكياً
### `[ ]` 7.4 تحديث `FinishingOptions.tsx` لبناء التشطيبات ديناميكياً
### `[ ]` 7.5 مكون الرفع المجزأ المصنف (Categorized Chunked Uploader)
### `[ ]` 7.6 إضافة EDD (تاريخ التسليم المتوقع) للفاتورة الحية
### `[ ]` 7.7 التأكد من ظهور العملة "ج.م" في جميع الحسابات
### `[ ]` 7.8 تنفيذ WebSocket Listener (عبر Laravel Echo) + HTTP Polling لزر الدفع

---

## ملخص العدد الإجمالي

| النوع | العدد |
|---|---|
| Migration جديدة | **8** |
| Model جديد | **6** |
| Model معدل | **2** |
| Helper (bcceil) | **1** |
| Service | **1** (PrintPricingService) |
| Job | **1** (ValidatePrintFileJob) |
| Controller (مرحلة لاحقة) | **5** |
| صفحات Dashboard (مرحلة لاحقة) | **3** |
| مكونات Storefront (مرحلة لاحقة) | **8** |
