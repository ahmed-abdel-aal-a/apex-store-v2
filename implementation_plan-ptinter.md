# خطة التنفيذ الشاملة: النظام الديناميكي للطباعة (Print Station) V14
**نسخة الحصن (Fortress Edition) - سد كل الثغرات الحسابية والأمنية**

> [!IMPORTANT]
> يعالج هذا الإصدار (V14) الثغرات القاتلة المكتشفة في المراجعة الأخيرة لضمان استقرار النظام بنسبة 100%:
> 1. **فخ التقريب:** إضافة `bcceil()` بدلاً من التقريب العادي لضمان التقريب لأعلى دائماً لصالح المطبعة.
> 2. **تجاهل محدد التسعير:** تفريع الخوارزمية بـ if/else حسب `pricing_method`.
> 3. **قنبلة الـ PDF:** فرض Timeout و Memory Limit على الـ Queue Job.
> 4. **كارثة الضريبة والحد الأدنى:** تطبيق `min_chargeable_price` على الـ Subtotal **قبل** الضريبة.
> 5. **شلل الوزن الحجمي:** إضافة `thickness_factor` بدلاً من الأبعاد الثابتة ليعمل على كل المنتجات، مع توحيد وحدة القياس (الكيلوجرام).
> 6. **هشاشة السلة:** إضافة `tax_basis_points_snapshot` للـ `cart_items` + HTTP Polling كبديل للـ WebSocket.
> 7. **حماية التناسق (Data Integrity):** إضافة SoftDeletes لجداول الخيارات لتجنب فقدان بيانات الطلبات القديمة، وحماية خصومات الكمية من التداخل.
> 8. **توافق الأسعار (Pricing Compatibility):** الحسابات المعقدة تتم بالقرش (BigInteger) ولكن تُحفظ في سلة المشتريات والطلبات بالجنيه (Decimal) لضمان التوافق مع النظام القديم وعدم كسر لوحة التحكم.

---

## القسم الأول: بنية قواعد البيانات الكاملة

### الجدول 1: `printing_product_types`
- `id`, `name`, `description`, `icon`, `is_active`, `allow_custom_name`, `sort_order`, `softDeletes`

### الجدول 2: `printing_types`
| العمود | النوع | الوصف |
|---|---|---|
| `pricing_method` | `enum('fixed', 'attributes_only', 'area')` | محدد التسعير |
| `base_price_fixed/unit/multiplier` | `bigInteger, default: 0` | بالقرش |
| `min_chargeable_area` | `bigInteger, default: 0` | mm² |
| `min_chargeable_price` | `bigInteger, default: 0` | **الحد الأدنى للـ Subtotal قبل الضريبة (بالقرش)** |
| `max_print_width/length` | `integer, nullable` | mm |
| `bleed_margin/safe_zone` | `integer, default: 0` | mm |
| `thickness_factor` | `integer, default: 0` | **[V14] معامل السمك بالمم لحساب الوزن الحجمي لأي منتج** |

### الجدول 3-4: `printing_attributes` & `printing_attribute_values`
- الفلاجات الديناميكية: `is_dimension_width`, `is_dimension_length` (مع إضافة Validation لمنع تكرارهم لنفس النوع).
- الأسعار: `fixed_price`, `unit_price`, `multiplier_price` (بالقرش).
- الوزن: `weight` (جرام)، `weight_type` (`per_unit`, `per_sqm`).
- **تحديث أمني:** تم إضافة `softDeletes` للجدولين لضمان عدم ضياع تفاصيل الطلبات السابقة عند الحذف.

### الجدول 5: `printing_volume_discounts`
- `discount_basis_points` (`integer`) بدلاً من النسبة العشرية.
- **تحديث أمني:** إضافة قيود لمنع تداخل الشرائح (Overlapping) ولمنع `min_qty > max_qty`.

### تعديلات `order_items` و `cart_items`:
- `tax_basis_points_snapshot` في **كلا الجدولين** لتجميد الضريبة.
- `file_status` في **كلا الجدولين** لتتبع حالة الفحص.
- **تحديث أمني:** إضافة `file_rejection_reason` لجدول `cart_items` لضمان عمل الـ Job بدون أخطاء.
- **تحديث التوافق:** تعديل `product_id` ليصبح `nullable` بطريقة آمنة (إسقاط القيد ثم إعادة إنشائه).

---

## القسم الثاني: محركات المنطق (V14 Logic Engines)

### 1. خوارزمية التسعير (مع التفريع الصارم)
```
if pricing_method === 'fixed':
    لا ضرب في مساحة.
elseif pricing_method === 'attributes_only':
    لا base_price ولا مساحة.
elseif pricing_method === 'area':
    Area_m2 = bcdiv(mm², 1000000, 4)
    unit_options لا تُضرب في المساحة أبداً.
```
*ملاحظة التوافق:* بعد الانتهاء من كل الحسابات بالقرش، يتم القسمة على 100 وحفظ الناتج النهائي في `cart_items.price` و `order_items.price_at_purchase` كـ Decimal(10,2) ليتوافق مع النظام الحالي.

### 2. ترتيب المعادلة المالية
1. Subtotal (حسب الـ pricing_method) بالقرش.
2. `Subtotal = max(Subtotal, min_chargeable_price)` ← **قبل الضريبة!**
3. Discount (basis points + bcceil).
4. Tax (basis points + bcceil).
5. Final Total (بالقرش) ← ثم يُحوّل لجنيه (Decimal) قبل الحفظ في جداول النظام الأساسي.

### 3. حماية PDF Bomb
- `$timeout = 120`, `$tries = 1`, و Ghostscript بـ `Process::timeout(60)` + `-dSAFER`.

### 4. بنية الـ Real-time ومرونة الواجهة
- **إعداد البنية التحتية:** تفعيل وإعداد Laravel Reverb أو Pusher من الصفر لأن النظام الحالي لا يحتوي على Broadcasting.
- **المرونة المزدوجة:** WebSocket كأولوية + HTTP Polling كل 5 ثوانٍ كبديل لو النت فصل.

### 5. تعديل نواة الدفع (Checkout)
- تجاوز نظام فحص المخزون والـ `product_id` في `CheckoutController` للمنتجات من نوع الطباعة لضمان إتمام الدفع بنجاح.

### 6. المتطلبات التقنية الحتمية (Dependencies)
- إضافة `ext-bcmath` إلى `composer.json` لتجنب انهيار خوارزمية BCMath.
