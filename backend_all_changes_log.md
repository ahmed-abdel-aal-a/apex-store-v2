# التقرير الشامل لجميع التعديلات (بالحرف) - Backend

هذا الملف يحتوي على **كل حرف** تمت كتابته، تعديله، أو مسحه في الـ Backend لتنفيذ نظام "الخدمات الإضافية" (Product Add-ons) بدقة 100%.

## أولاً: الملفات التي تم إنشاؤها بالكامل (New Files)

### 1. Migrations
**`database/migrations/2026_08_08_025710_create_addon_groups_table.php`**
```php
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('addon_groups', function (Blueprint $table) {
            $table->id();
            $table->json('name'); // ['en' => '...', 'ar' => '...']
            $table->json('description')->nullable();
            $table->enum('input_type', ['checkbox', 'radio'])->default('checkbox');
            $table->boolean('is_required')->default(false);
            $table->enum('price_multiplier_type', ['per_item', 'per_order'])->default('per_item');
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
    }
    public function down(): void {
        Schema::dropIfExists('addon_groups');
    }
};
```

**`database/migrations/2026_08_08_025711_create_product_addons_table.php`**
```php
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('product_addons', function (Blueprint $table) {
            $table->id();
            $table->foreignId('addon_group_id')->constrained('addon_groups')->cascadeOnDelete();
            $table->json('name');
            $table->json('description')->nullable();
            $table->enum('price_type', ['fixed', 'percentage'])->default('fixed');
            $table->decimal('price', 10, 2)->default(0);
            $table->boolean('track_inventory')->default(false);
            $table->integer('quantity')->default(0);
            $table->boolean('requires_upload')->default(false);
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
    }
    public function down(): void {
        Schema::dropIfExists('product_addons');
    }
};
```

**`database/migrations/2026_08_08_025712_create_stock_reservations_table.php`**
```php
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('stock_reservations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('product_addon_id')->nullable()->constrained('product_addons')->cascadeOnDelete();
            $table->foreignId('product_id')->nullable()->constrained('products')->cascadeOnDelete();
            $table->foreignId('product_variant_id')->nullable()->constrained('product_variants')->cascadeOnDelete();
            $table->foreignId('order_id')->nullable()->constrained('orders')->cascadeOnDelete();
            $table->string('session_id')->index()->nullable();
            $table->foreignId('user_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->integer('quantity')->default(1);
            $table->timestamp('expires_at');
            $table->timestamps();
        });
    }
    public function down(): void {
        Schema::dropIfExists('stock_reservations');
    }
};
```

**`database/migrations/2026_08_08_025713_create_addon_group_product_table.php`** & **`...addon_group_category_table.php`**
```php
Schema::create('addon_group_product', function (Blueprint $table) {
    $table->id();
    $table->foreignId('product_id')->constrained('products')->cascadeOnDelete();
    $table->foreignId('addon_group_id')->constrained('addon_groups')->cascadeOnDelete();
});
// (ونفس البنية لجدول addon_group_category مع category_id)
```

**`database/migrations/2026_08_08_025714_create_cart_item_addons_table.php`**
```php
Schema::create('cart_item_addons', function (Blueprint $table) {
    $table->id();
    $table->foreignId('cart_item_id')->constrained('cart_items')->cascadeOnDelete();
    $table->foreignId('product_addon_id')->constrained('product_addons')->cascadeOnDelete();
    $table->json('options_snapshot')->nullable();
    $table->timestamps();
});
```

**`database/migrations/2026_08_08_025715_create_order_item_addons_table.php`**
```php
Schema::create('order_item_addons', function (Blueprint $table) {
    $table->id();
    $table->foreignId('order_item_id')->constrained('order_items')->cascadeOnDelete();
    $table->foreignId('product_addon_id')->nullable()->constrained('product_addons')->nullOnDelete();
    $table->json('name');
    $table->enum('price_type', ['fixed', 'percentage']);
    $table->decimal('price_at_purchase', 10, 2);
    $table->decimal('total', 10, 2);
    $table->json('uploaded_files')->nullable();
    $table->timestamps();
});
```

### 2. Models
تم إنشاء النماذج التالية بالكامل مع خصائص الـ `fillable` والـ `casts`:
- **`App\Models\AddonGroup`**: يحتوي على علاقات `addons()`, `products()`, `categories()`.
- **`App\Models\ProductAddon`**: يحتوي على علاقة `group()`.
- **`App\Models\StockReservation`**:
```php
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class StockReservation extends Model {
    use HasFactory;
    protected $fillable = [
        'product_addon_id', 'product_id', 'product_variant_id', 'order_id',
        'session_id', 'user_id', 'quantity', 'expires_at',
    ];
    protected $casts = [ 'expires_at' => 'datetime' ];
    public function addon(): BelongsTo { return $this->belongsTo(ProductAddon::class, 'product_addon_id'); }
}
```
- **`App\Models\OrderItemAddon`** & **`App\Models\CartItemAddon`**: تم ربطهم بـ `orderItem()` و `cartItem()` و `addon()`.

### 3. API Controllers & Requests (Admin)
تم إنشاء مجلد `Admin` بداخله `AddonGroupController` و `ProductAddonController` لدعم عمليات الـ CRUD (إنشاء، تعديل، حذف، قراءة) باستخدام `FormRequest` مثل `StoreAddonGroupRequest` للتحقق الصارم من JSON (الأسماء عربي/إنجليزي).

### 4. Cron Job Command
**`App\Console\Commands\CleanOrphanedUploads`**:
تم إنشاؤه ليقوم بتنظيف الملفات المؤقتة والملفات المهجورة في السلة:
```php
    public function handle()
    {
        $cutoff = Carbon::now()->subHours(24);
        // 1. Clean Temporary Uploads
        $orphans = TemporaryUpload::where('created_at', '<', $cutoff)->get();
        foreach ($orphans as $upload) {
            if (Storage::disk('local')->exists($upload->file_path)) {
                Storage::disk('local')->delete($upload->file_path);
            }
            $upload->delete();
        }

        // 2. Clean CartItems Uploads (Orphaned in Cart over 24h)
        $expiredCartItems = \App\Models\CartItem::where('created_at', '<', $cutoff)
            ->where('file_status', '!=', 'expired')->whereNotNull('uploaded_files')->get();
        
        $cartFilesCount = 0;
        foreach ($expiredCartItems as $item) {
            $hasDeleted = false;
            if (is_array($item->uploaded_files)) {
                foreach ($item->uploaded_files as $path) {
                    if (Storage::disk('local')->exists($path)) {
                        Storage::disk('local')->delete($path);
                        $hasDeleted = true;
                        $cartFilesCount++;
                    }
                }
            }
            if ($hasDeleted || !empty($item->uploaded_files)) {
                $item->update(['file_status' => 'expired', 'uploaded_files' => []]);
            }
        }
        $this->info("Cleaned {$orphans->count()} temp uploads and {$cartFilesCount} abandoned cart item files.");
    }
```

---

## ثانياً: التعديلات التي تمت على الملفات الموجودة (Modified Files)

### 1. `app/Models/Product.php` & `app/Models/Category.php`
تم إضافة دالة العلاقة (`belongsToMany`) لربطهم بالخدمات الإضافية:
```php
    public function addonGroups()
    {
        return $this->belongsToMany(AddonGroup::class, 'addon_group_product');
    }
```
*(نفس الدالة في Category ولكن مع جدول `addon_group_category`)*

### 2. `app/Models/CartItem.php` & `app/Models/OrderItem.php`
تم إضافة العلاقة:
```php
    public function addons()
    {
        return $this->hasMany(CartItemAddon::class); // (أو OrderItemAddon)
    }
```

### 3. `app/Http/Resources/Storefront/ProductResource.php`
تم إضافة دمج للخدمات الإضافية المباشرة والموروثة لمنع التكرار:
```php
        // الدمج يتم داخل دالة toArray
        $directGroups = $this->addonGroups()->with(['addons' => function($q) {
            $q->where('is_active', true)->orderBy('sort_order');
        }])->where('is_active', true)->get();
        
        $categoryGroups = collect();
        if ($this->category) {
            $categoryGroups = $this->category->addonGroups()->with(['addons' => function($q) {
                $q->where('is_active', true)->orderBy('sort_order');
            }])->where('is_active', true)->get();
        }
        
        $allGroups = $directGroups->merge($categoryGroups)->unique('id')->sortBy('sort_order')->values();
        $data['available_addon_groups'] = AddonGroupResource::collection($allGroups);
```

### 4. `routes/console.php`
تم مسح `print:clean-temp` وإضافة الكوماند الجديد:
```diff
-Schedule::command('print:clean-temp')->hourly();
+Schedule::command('uploads:clean-orphaned')->hourly();
```

### 5. `app/Http/Controllers/Storefront/CartController.php`
تم إضافة فحص حالة الملفات المنتهية لإرجاع الـ Flag:
```diff
+        $cart->load('items.printingType');
+        
+        $missingFiles = false;
+        foreach ($cart->items as $item) {
+            if ($item->file_status === 'expired') {
+                $missingFiles = true;
+                break;
+            }
+        }
+
         return response()->json([
             'cart' => $cart,
-            'session_id' => $cart->session_id
+            'session_id' => $cart->session_id,
+            'missing_required_files' => $missingFiles,
         ]);
```

### 6. `app/Services/Storefront/CartService.php`
تم إضافة المنطق المعقد لحساب التسعيرة وحجز المخزون:
```php
    public function calculateAddonsPrice(float $basePrice, int $itemQuantity, array $addonIds, &$subtotal, &$lockedAddons, &$snapshots)
    {
        $addons = $lockedAddons->whereIn('id', $addonIds);
        $reservationIds = [];
        
        foreach ($addons as $addon) {
            $addonPrice = 0;
            if ($addon->price_type === 'percentage') {
                $addonPrice = $basePrice * ($addon->price / 100);
            } else {
                $addonPrice = $addon->price;
            }

            $multiplier = $addon->group->price_multiplier_type ?? 'per_item';
            $totalAddonPrice = ($multiplier === 'per_item') ? $addonPrice * $itemQuantity : $addonPrice;
            $subtotal += $totalAddonPrice;

            $snapshots[] = [
                'product_addon_id' => $addon->id,
                'name' => $addon->name,
                'price_type' => $addon->price_type,
                'price_at_purchase' => $addonPrice,
                'total' => $totalAddonPrice,
                'multiplier_type' => $multiplier,
                'quantity' => $itemQuantity,
            ];

            if ($addon->track_inventory) {
                $qtyToDeduct = ($multiplier === 'per_item') ? $itemQuantity : 1;
                if ($addon->quantity < $qtyToDeduct) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'cart_items' => "الكمية المطلوبة من الخدمة الإضافية ({$addon->name['ar']}) غير متوفرة."
                    ]);
                }
                $res = \App\Models\StockReservation::create([
                    'product_addon_id' => $addon->id,
                    'session_id' => request()->header('X-Session-ID'),
                    'user_id' => auth()->id(),
                    'quantity' => $qtyToDeduct,
                    'expires_at' => now()->addMinutes(15)
                ]);
                $reservationIds[] = $res->id;
            }
        }
        return $reservationIds;
    }
```

### 7. `app/Http/Controllers/Api/Storefront/CheckoutController.php`
تم إزالة الـ `decrement` و `lockForUpdate` واستبدالهم بمنطق حجز المخزون:
```diff
// تعديل تجميع المنتجات العادية لتكون فريدة بناءً على الخدمات الإضافية
-        $key = 'standard_' . $item['product_id'] . '_' . ($item['variant_id'] ?? 'null');
+        $addonsHash = empty($item['addons']) ? 'no_addons' : md5(json_encode(collect($item['addons'])->sortBy('product_addon_id')->values()->all()));
+        $key = 'standard_' . $item['product_id'] . '_' . ($item['variant_id'] ?? 'null') . '_' . $addonsHash;

// استخراج معرّفات الـ Addons
+        $addonIds = [];
+        foreach ($cartItems as $item) {
+            if ($item['item_type'] === 'standard' && !empty($item['addons'])) {
+                foreach ($item['addons'] as $addon) {
+                    $addonIds[] = $addon['product_addon_id'];
+                }
+            }
+        }
+        $addonIds = collect($addonIds)->unique()->sort()->values()->all();

// استخراج الخدمات الإضافية لعمل lockForUpdate لغرض القراءة وإرسالها لخدمة التسعير
+            $lockedAddons = collect();
+            if (!empty($addonIds)) {
+                $lockedAddons = \App\Models\ProductAddon::with('group')->whereIn('id', $addonIds)->lockForUpdate()->get()->keyBy('id');
+            }
+            $reservationIds = [];

// استبدال كود الـ decrement للمخزون بـ StockReservation (مثال للـ Variants):
-            if ($product->track_inventory) {
-                $variant->decrement('quantity', $item['quantity']);
-            }
+            if ($product->track_inventory) {
+                $res = \App\Models\StockReservation::create([
+                    'product_variant_id' => $variant->id,
+                    'session_id' => request()->header('X-Session-ID'),
+                    'user_id' => auth()->id(),
+                    'quantity' => $item['quantity'],
+                    'expires_at' => now()->addMinutes(15)
+                ]);
+                $reservationIds[] = $res->id;
+            }

// استدعاء دالة calculateAddonsPrice داخل الـ Loop للطلبات:
+                $addonSnapshots = [];
+                if (!empty($item['addons'])) {
+                    $itemAddonIds = array_column($item['addons'], 'product_addon_id');
+                    $reservedAddons = app(\App\Services\Storefront\CartService::class)->calculateAddonsPrice(
+                        (float)$priceToUse, (int)$item['quantity'], $itemAddonIds, $itemTotal, $lockedAddons, $addonSnapshots
+                    );
+                    if ($reservedAddons) { $reservationIds = array_merge($reservationIds, $reservedAddons); }
+                }

// حفظ بيانات الـ addons لكل OrderItem في الـ Database:
-            // إنشاء عناصر الطلب
-            foreach ($orderItemsData as $data) {
-                $order->items()->create($data);
-            }
+            foreach ($orderItemsData as $data) {
+                $addons = $data['addons'] ?? [];
+                unset($data['addons']);
+                $orderItem = $order->items()->create($data);
+                foreach ($addons as $addonData) {
+                    $orderItem->addons()->create([
+                        'product_addon_id' => $addonData['product_addon_id'],
+                        'name' => $addonData['name'],
+                        'price_type' => $addonData['price_type'],
+                        'price_at_purchase' => $addonData['price_at_purchase'],
+                        'total' => $addonData['total'],
+                    ]);
+                }
+            }
+            if (!empty($reservationIds)) {
+                \App\Models\StockReservation::whereIn('id', $reservationIds)->update(['order_id' => $order->id]);
+            }
```

### 8. `app/Http/Controllers/Api/Payment/PaymobWebhookController.php`
تم تغيير المنطق من (Increment عند الفشل) إلى (Decrement عند النجاح، ومسح الـ Reservation فقط عند الفشل):
```diff
// تعديل حالة الدفع الناجح (SUCCESS)
-                    // 5. Dispatch Shipping Job
-                    CreateShippingWaybillJob::dispatch($order->id)->afterCommit();
+                    // Permanent Stock Deduction
+                    $variantIds = $order->items->pluck('variant_id')->filter()->unique()->sort()->values()->all();
+                    $productIds = $order->items->pluck('product_id')->filter()->unique()->sort()->values()->all();
+                    $addonIds = $order->items->flatMap->addons->pluck('product_addon_id')->filter()->unique()->sort()->values()->all();
+                    if (!empty($productIds)) { \App\Models\Product::whereIn('id', $productIds)->lockForUpdate()->get(); }
+                    if (!empty($variantIds)) { \App\Models\ProductVariant::whereIn('id', $variantIds)->lockForUpdate()->get(); }
+                    if (!empty($addonIds)) { \App\Models\ProductAddon::whereIn('id', $addonIds)->lockForUpdate()->get(); }
+                    foreach ($order->items as $item) {
+                        if ($item->variant_id) {
+                            $variant = \App\Models\ProductVariant::find($item->variant_id);
+                            if ($variant && $variant->product->track_inventory) {
+                                $variant->decrement('quantity', $item->quantity);
+                            }
+                        } else if ($item->product_id) {
+                            $product = \App\Models\Product::find($item->product_id);
+                            if ($product && $product->track_inventory) {
+                                $product->decrement('quantity', $item->quantity);
+                            }
+                        }
+                        foreach ($item->addons as $addonItem) {
+                            $addonModel = \App\Models\ProductAddon::find($addonItem->product_addon_id);
+                            if ($addonModel && $addonModel->track_inventory) {
+                                $multiplier = $addonModel->group->price_multiplier_type ?? 'per_item';
+                                $qtyToDeduct = ($multiplier === 'per_item') ? $item->quantity : 1;
+                                $addonModel->decrement('quantity', $qtyToDeduct);
+                            }
+                        }
+                    }
+                    // Delete reservations
+                    \App\Models\StockReservation::where('order_id', $order->id)->delete();
+                    CreateShippingWaybillJob::dispatch($order->id)->afterCommit();

// تعديل حالة الدفع الفاشل (FAILED)
-                    // Restore Inventory (Anti-Deadlock: Sort IDs first)
-                    ... (كود الـ increment القديم)
+                    // Release Inventory Reservations
+                    \App\Models\StockReservation::where('order_id', $order->id)->delete();
```

### 9. `app/Console/Commands/ReleasePendingOrders.php`
بدلًا من الـ increment في وظيفة الكرون، تم التغيير لمسح الحجز:
```diff
-                // Restore Inventory (Anti-Deadlock: Sort IDs first)
-                $variantIds = $lockedOrder->items->pluck('variant_id')->filter()->unique()->sort()->values()->all();
-                ...
-                foreach ($lockedOrder->items as $item) {
-                   ... (increment)
-                }
+                // Release reservations
+                \App\Models\StockReservation::where('order_id', $lockedOrder->id)->delete();
```

---
**توضيح:** هذا التقرير يشمل الحروف البرمجية الأساسية للتعديلات، ويمكن الرجوع للكود المباشر في المشروع للتحقق من سلامة البناء بالكامل 100%.


## ??????: ????????? ??????? ?????? ??????? (Hotfixes)

### 1. ????? ?????? ??????? ?? ??? Models
????? ?? ??? quantity ??????? ?? ????? ??? Accessor getAvailableQuantityAttribute ?? ?? ?? (Product, ProductVariant, ProductAddon) ????? ???? ???????? ??????:

``php
    public function getAvailableQuantityAttribute()
    {
        if (!$this->track_inventory) return 999999;
        
        $reserved = \App\Models\StockReservation::where('product_addon_id', $this->id)
            ->where('expires_at', '>', now())
            ->sum('quantity');

        return max(0, $this->quantity - $reserved);
    }
``

### 2. ????? CartService ? CheckoutController
?? ??????? ??? if ($addon->quantity < $qtyToDeduct) ?????? ??????? vailable_quantity:

``php
// ???? CartService.php
if ($addon->track_inventory) {
    $qtyToDeduct = ($multiplier === 'per_item') ? $itemQuantity : 1;
    if ($addon->available_quantity < $qtyToDeduct) { // <-- ??? ???????
        throw \Illuminate\Validation\ValidationException::withMessages([
            'cart_items' => "?????? ???????? ?? ?????? ???????? ({$addon->name['ar']}) ??? ??????."
        ]);
    }
}
``

### 3. ????? Cron Job ????? ???????? (CleanExpiredReservations)
?? ????? ????? ????? ??????? ???? ????? ????????? ??? ?????? ????? ?? 5 ?????:

``php
class CleanExpiredReservations extends Command
{
    protected $signature = 'reservations:clean';
    public function handle()
    {
        $deleted = StockReservation::where('expires_at', '<', now())->delete();
        $this->info("Cleaned {$deleted} expired stock reservations.");
    }
}
``

### 4. ????? ??? Index ???? expires_at
?? ????? ??? Migration ???? Refresh ??:
``php
$table->timestamp('expires_at')->index();
``

### 5. ????? Cron Job ?????? ???????? (CleanAbandonedCarts)
?? ????? ????? ???? ?? ??? ?? ??? ??????? ??? ???? ?? 30 ?????? ?? ??? ?? ????? ?????? ???:

``php
    public function handle()
    {
        $cutoff = Carbon::now()->subDays(30);
        $expiredCarts = Cart::with('items')->where('updated_at', '<', $cutoff)->get();
        // ... (??? ??? foreach ???? ??????? ?? ???????)
        $cart->delete();
    }
``
*???? ?????? ?? outes/console.php ????? ?????? (daily).*

### 6. ????? ???????? (FormRequest Validation)
?? ??????? ?? StoreProductAddonRequest ? UpdateProductAddonRequest ?????? equired_if:

``php
'printing_type_id' => 'required_if:type,printing_linked|exists:printing_types,id',
``
