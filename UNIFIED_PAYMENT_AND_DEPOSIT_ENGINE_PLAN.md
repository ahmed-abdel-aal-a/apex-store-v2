# 🛡️ وثيقة الخطة الهندسية الشاملة (الإصدار المعتمد النهائي V15.2): محرك المدفوعات الموحد ونظام العربون الذكي لخدمات الطباعة (Apex Store V2)
**مشروع:** Apex Store V2 (Print Express)  
**الإصدار المعماري:** Enterprise Financial Edition V15.2 (Locked & Approved for Execution)  
**تاريخ الاعتماد:** 2026-10-20  
**الحالة:** معتمد للتنفيذ الفوري (Execution in Progress)

---

## 📌 1. الملخص التنفيذي وأهداف التحديث (Executive Summary)

تم إحكام هذه الوثيقة بدمج التعديلات المنطقية والحسابية الثلاثة الأخيرة، لتصبح المرجع المعماري الشامل لتنفيذ:
1. **المركز العام لتحديد وإعدادات الدفع (Unified Payment Center):** نقل الـ COD من الشحن إلى الدفع وتجميع كافة بوابات وسياسات الدفع في واجهة مركزية واحدة.
2. **محرك العربون وسياسات المطبوعات مع الحد الأدنى (`min_deposit_amount`):** حماية المتجر من خسائر الشحن للطلبات المنخفضة أو الكوبونات الكبيرة عبر تحديد حد أدنى للعربون (مثلاً 50 أو 100 ج.م).
3. **التأخير الآمن لتصفير السلة (`clearCart`):** تصفير السلة فقط داخل Polling صفحة `/checkout/success` بعد التأكد التام من استلام إشعار السداد البنكي بنجاح (`partially_paid` أو `paid`)، لحماية تصاميم وملفات العميل من الضياع في حال حدوث أي خطأ بالدفع.
4. **تأمين عمود `payment_status` صراحة في الـ Migration:** تعديل صريح للعمود لاستيعاب `partially_paid` دون أي استثناءات SQL.
5. **فصل بوليصة الشحن:** إصدار البوليصة فقط عند جاهزية الطلب للشحن (`ready_for_shipping`) وليس عند دفع العربون.
6. **إغلاق الدورة المالية تلقائياً:** عند وصول الشحنة (`delivered`) تتحول حالة الدفع من `partially_paid` إلى `paid`.
7. **تنظيف المخزون المهجور (Ghost Stock):** أمر مجدول كل 15 دقيقة يلغي الطلبات غير المسددة بعد 45 دقيقة ويحرر المخزون والكوبونات.

---

## 📐 2. معادلة حساب العربون والحد الأدنى (The Fortified Deposit Formula)

```php
// 1. حساب وعاء المطبوعات الصافي بعد حصتها من الخصم
$printingSubtotal = $calcResult['printing_subtotal'];
$depositPercentage = (float)($settings['deposit_percentage'] ?? 30.0);
$minDepositAmount = (float)($settings['min_deposit_amount'] ?? 50.0);
$grandTotal = (float)$calcResult['grand_total'];

// 2. حساب النسبة المئوية
$calculatedDeposit = (float)bcmul((string)$printingSubtotal, bcdiv((string)$depositPercentage, '100', 4), 2);

// 3. تطبيق قاعدة الحد الأدنى لضمان تغطية تكلفة الخامات والشحن المرتجع
$depositAmount = max($calculatedDeposit, $minDepositAmount);

// 4. شرط الأمان: إذا كان إجمالي الطلب أقل من الحد الأدنى، يسدد العميل الإجمالي بالكامل
if ($grandTotal <= $minDepositAmount || $depositAmount >= $grandTotal) {
    $depositAmount = $grandTotal;
    $remainingAmount = 0.00;
    $paymentType = 'full';
} else {
    // 5. رسوم الدفع عند الاستلام تضاف بالكامل 100% على المبلغ المتبقي
    $remainingAmount = (float)bcsub((string)$grandTotal, (string)number_format($depositAmount, 2, '.', ''), 2);
    $paymentType = 'deposit';
}
```

---

## 🛠️ 3. خارطة التنفيذ المرحلية (Execution Roadmap)

- [ ] **المرحلة 1: قاعدة البيانات والنماذج (Database & Models):**
  - إنشاء مايجريشن `2026_10_20_220000_add_deposit_fields_to_orders_table.php` مع تعديل صريح لـ `payment_status` وإضافة `payment_type`, `deposit_percentage`, `deposit_amount`, `remaining_amount`, `deposit_paid_at`, `remaining_paid_at`.
  - تحديث النموذج `Order.php`.
- [ ] **المرحلة 2: واجهات برمجة التطبيقات والإعدادات (API & Settings):**
  - تحديث `SettingsController.php` لدعم `min_deposit_amount`, `deposit_enabled`, `deposit_percentage`, `printing_payment_mode`, `allow_full_cod_for_printing`.
  - تحديث `StorefrontDataController.php` لتصدير هذه الإعدادات عبر `/storefront/checkout-settings`.
  - تحديث `CheckoutProcessRequest.php` ليكون مرناً وديناميكياً بدون hardcoding لطرق الدفع.
- [ ] **المرحلة 3: دورة الشيك أوت وكاشير وبوالص الشحن (Checkout & Fulfillment):**
  - تحديث `CheckoutController.php` بتطبيق معادلة العربون والحد الأدنى.
  - تحديث `KashierService.php` لتوليد الرابط بقيمة `$depositAmount`.
  - تحديث `KashierWebhookController.php` للتحقق من العربون وتحويل الحالة إلى `partially_paid` دون إصدار بوليصة.
  - تحديث `CreateShippingWaybillJob.php` ليصدر فقط لـ `ready_for_shipping` مع تسجيل تحصيل الـ COD بقيمة `remaining_amount`.
  - تحديث `ShippingWebhookController.php` و `OrderController.php` لتسوية `partially_paid` إلى `paid` عند `delivered`.
  - تحديث `ExpireUnpaidOrders.php` وجدولته كل 15 دقيقة لتحرير المخزون الوهمي.
  - إضافة مسار خفيف `GET /storefront/orders/{id}/payment-status` للـ Polling.
- [ ] **المرحلة 4: لوحة التحكم (Dashboard UI/UX):**
  - إعادة بناء صفحة `dashboard/app/settings/page.tsx`: نقل COD وتأسيس المركز العام لإعدادات الدفع وعربون المطبوعات مع شريط النسبة وصندوق المحاكاة.
  - تحديث `PaymentBadge.tsx` و `OrderDetailsModal.tsx` و `order.types.ts`.
- [ ] **المرحلة 5: واجهة المتجر (Storefront UI/UX):**
  - تحديث `storefront/app/checkout/page.tsx` لعرض خيارات العربون والحد الأدنى وتفقيط المبالغ.
  - إنشاء `storefront/app/checkout/success/page.tsx` مع Smart Polling وتأخير `clearCart()` لما بعد التأكيد.
  - إنشاء `storefront/app/checkout/error/page.tsx` لحماية السلة والتصميمات عند الإلغاء أو الفشل.
- [ ] **المرحلة 6: الاختبار والتحقق المتكامل (Testing & Verification):**
  - تشغيل الاختبارات والتأكد من استقرار كافة الحسابات والتدفق المالي.
