# التحديثات الأمنية وإصلاح الثغرات (Hotfixes)

لقد تم حل جميع الكوارث المنطقية والملاحظات التي تفضلت بها بدقة 100% كما يلي:

### 1. إصلاح حسابات المخزون في الـ Models
بدلًا من جلب `quantity` مباشرة، تم إنشاء الـ Accessor `getAvailableQuantityAttribute` في كل من (`Product`, `ProductVariant`, `ProductAddon`) ليقوم بخصم الحجوزات النشطة:

```php
    public function getAvailableQuantityAttribute()
    {
        if (!$this->track_inventory) return 999999;
        
        $reserved = \App\Models\StockReservation::where('product_addon_id', $this->id)
            ->where('expires_at', '>', now())
            ->sum('quantity');

        return max(0, $this->quantity - $reserved);
    }
```

### 2. تعديل CartService و CheckoutController
تم استبدال شرط `if ($addon->quantity < $qtyToDeduct)` القديم ليستخدم `available_quantity`:

```php
// داخل CartService.php
if ($addon->track_inventory) {
    $qtyToDeduct = ($multiplier === 'per_item') ? $itemQuantity : 1;
    if ($addon->available_quantity < $qtyToDeduct) { // <-- هنا التعديل
        throw \Illuminate\Validation\ValidationException::withMessages([
            'cart_items' => "الكمية المطلوبة من الخدمة الإضافية ({$addon->name['ar']}) غير متوفرة."
        ]);
    }
}
```

### 3. إنشاء Cron Job مقبرة الحجوزات (CleanExpiredReservations)
تم إنشاء الأمر ليمسح السجلات التي انتهت صلاحيتها، وتم جدولته ليعمل كل 5 دقائق:

```php
class CleanExpiredReservations extends Command
{
    protected $signature = 'reservations:clean';
    public function handle()
    {
        $deleted = StockReservation::where('expires_at', '<', now())->delete();
        $this->info("Cleaned {$deleted} expired stock reservations.");
    }
}
```

### 4. إضافة الـ Index لحقل expires_at
تم تعديل الـ Migration وعمل Refresh له:
```php
$table->timestamp('expires_at')->index();
```

### 5. إضافة Cron Job السلال المهجورة (CleanAbandonedCarts)
تم برمجة الأمر لمسح أي سلة لم يتم تحديثها منذ أكثر من 30 يوماً، مع مسح أي ملفات مرتبطة بها:

```php
    public function handle()
    {
        $cutoff = Carbon::now()->subDays(30);
        $expiredCarts = Cart::with('items')->where('updated_at', '<', $cutoff)->get();
        // ... (كود الـ foreach لمسح الملفات من السيرفر)
        $cart->delete();
    }
```
*وتمت جدولته في `routes/console.php` ليعمل يومياً (`daily`).*

### 6. حماية البيانات (FormRequest Validation)
تم التعديل في `StoreProductAddonRequest` و `UpdateProductAddonRequest` لتطبيق `required_if`:

```php
'printing_type_id' => 'required_if:type,printing_linked|exists:printing_types,id',
```
