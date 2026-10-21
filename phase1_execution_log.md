# Pull Request: Phase 1 (Backend Core) Security & Architecture Update (FINAL)

هذا الملف يحتوي على الكود الكامل لجميع الملفات التي تم إنشاؤها وتعديلها خلال المرحلة الأولى، شاملاً معالجة الثغرات المنطقية الأخيرة.


## File: `database\migrations\2026_08_10_015958_add_shipping_fields_to_orders_table.php`

``php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->boolean('is_fallback_shipping')->default(false)->after('shipping_cost');
            $table->timestamp('latest_shipping_update_at')->nullable()->after('status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['is_fallback_shipping', 'latest_shipping_update_at']);
        });
    }
};

``

## File: `database\migrations\2026_08_10_020006_add_file_fields_to_addon_tables.php`

``php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('cart_item_addons', function (Blueprint $table) {
            $table->string('file_path')->nullable()->after('total');
            $table->string('temp_file_id')->nullable()->after('file_path');
        });

        Schema::table('order_item_addons', function (Blueprint $table) {
            $table->string('file_path')->nullable()->after('total');
            $table->string('temp_file_id')->nullable()->after('file_path');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('cart_item_addons', function (Blueprint $table) {
            $table->dropColumn(['file_path', 'temp_file_id']);
        });

        Schema::table('order_item_addons', function (Blueprint $table) {
            $table->dropColumn(['file_path', 'temp_file_id']);
        });
    }
};

``

## File: `database\migrations\2026_08_10_023440_drop_temp_file_id_from_order_item_addons.php`

``php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('order_item_addons', function (Blueprint $table) {
            $table->dropColumn('temp_file_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('order_item_addons', function (Blueprint $table) {
            $table->string('temp_file_id')->nullable()->after('file_path');
        });
    }
};

``

## File: `database\migrations\2026_08_10_130618_add_cart_id_to_orders_table.php`

``php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->unsignedBigInteger('cart_id')->nullable()->after('id');
            // Assuming carts table exists, otherwise just the column is fine. 
            // It's safer to just add the column if we aren't 100% sure about the foreign key constraints or engine.
            // But let's add the foreign key for strictness.
            $table->foreign('cart_id')->references('id')->on('carts')->onDelete('set null');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropForeign(['cart_id']);
            $table->dropColumn('cart_id');
        });
    }
};

``

## File: `app\Console\Commands\CleanOrphanedUploads.php`

``php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\TemporaryUpload;
use Illuminate\Support\Facades\Storage;
use Carbon\Carbon;

class CleanOrphanedUploads extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'uploads:clean-orphaned';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Clean orphaned temporary uploads older than 48 hours';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $cutoff = Carbon::now()->subHours(48);

        // 1. Clean Temporary Uploads
        $orphans = TemporaryUpload::where('created_at', '<', $cutoff)->get();
        foreach ($orphans as $upload) {
            if (Storage::disk('local')->exists($upload->file_path)) {
                Storage::disk('local')->delete($upload->file_path);
            }
            $upload->delete();
        }

        // 2. Clean CartItems Uploads (Orphaned in Cart over 48h)
        $expiredCartItems = \App\Models\CartItem::where('created_at', '<', $cutoff)
            ->where('file_status', '!=', 'expired')
            ->whereNotNull('uploaded_files')
            ->get();

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
                $item->update([
                    'file_status' => 'expired',
                    'uploaded_files' => [] // empty the references
                ]);
            }
        }

        $this->info("Cleaned {$orphans->count()} temp uploads and {$cartFilesCount} abandoned cart item files.");
    }
}

``

## File: `routes\api.php`

``php
<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// ==========================================
// Admin Auth Routes
// ==========================================
use App\Http\Controllers\Admin\AuthController as AdminAuthController;

Route::prefix('v1/admin/auth')->group(function () {
    // Rate Limiting: 5 requests per minute for login
    Route::post('/login', [AdminAuthController::class, 'login'])->middleware('throttle:5,1');
});

Route::middleware('auth:sanctum')->prefix('v1/admin/auth')->group(function () {
    Route::post('/logout', [AdminAuthController::class, 'logout']);
    Route::get('/me', [AdminAuthController::class, 'me']);
});


// ==========================================
// Admin Protected Routes
// ==========================================
use App\Http\Controllers\Admin\StaffController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\AbandonedCartController;
use App\Http\Controllers\Admin\ChatCenter\FaqController;
use App\Http\Controllers\Admin\ChatCenter\SettingsController as ChatSettingsController;
use App\Http\Controllers\Admin\ChatCenter\ConversationController;
use App\Http\Controllers\Api\Admin\SettingsController as AdminSettingsController;
use App\Http\Controllers\Api\Admin\ShippingController as AdminShippingController;
use App\Http\Controllers\Api\Admin\PaymentController as AdminPaymentController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\CustomerController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\AttributeController;
use App\Http\Controllers\UploadController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\PrintingProductTypeController;
use App\Http\Controllers\PrintingTypeController;
use App\Http\Controllers\PrintingAttributeController;
use App\Http\Controllers\PrintingAttributeValueController;
use App\Http\Controllers\PrintingVolumeDiscountController;
use App\Http\Controllers\Admin\AddonGroupController;
use App\Http\Controllers\Admin\ProductAddonController;
Route::middleware('auth:sanctum')->prefix('v1/admin')->group(function () {

    // Dashboard Home
    Route::get('/dashboard/summary', [DashboardController::class, 'summary']);

    // Staff Management
    Route::apiResource('staff', StaffController::class);

    // Customers
    Route::get('/customers', [CustomerController::class, 'index']);
    Route::get('/customers/{id}', [CustomerController::class, 'show']);
    Route::get('/customers/{id}/history', [CustomerController::class, 'history']);

    // Categories & Attributes
    Route::apiResource('categories', CategoryController::class)->only(['index', 'store', 'destroy']);
    Route::apiResource('attributes', AttributeController::class)->only(['index', 'store', 'update']);
    
    // Products & Printing
    Route::apiResource('products', ProductController::class);
    Route::apiResource('printing-product-types', PrintingProductTypeController::class);
    Route::apiResource('printing-types', PrintingTypeController::class);
    Route::apiResource('printing-attributes', PrintingAttributeController::class);
    Route::apiResource('printing-attribute-values', PrintingAttributeValueController::class);
    Route::apiResource('printing-volume-discounts', PrintingVolumeDiscountController::class);
    Route::post('/upload', [UploadController::class, 'upload']);
    Route::post('/upload-general', [UploadController::class, 'uploadGeneral']);
    
    // Addons
    Route::apiResource('addon-groups', AddonGroupController::class);
    Route::apiResource('addon-groups.addons', ProductAddonController::class)->scoped();
    
    // Blog
    Route::apiResource('blog-posts', App\Http\Controllers\Admin\BlogPostController::class);
    
    // Offers
    Route::apiResource('offers', App\Http\Controllers\Api\Admin\OfferController::class);

    // Orders
    Route::get('/orders/export', [OrderController::class, 'export']);
    Route::get('/orders/summary', [OrderController::class, 'summary']);
    Route::get('/orders', [OrderController::class, 'index']);
    Route::patch('/orders/{id}/status', [OrderController::class, 'updateStatus']);
    Route::patch('/orders/items/{item_id}/file-status', [OrderController::class, 'updateItemFileStatus']);

    // Abandoned Carts
    Route::get('/abandoned-carts', [AbandonedCartController::class, 'index']);
    Route::get('/abandoned-carts/{id}', [AbandonedCartController::class, 'show']);
    Route::post('/abandoned-carts/{id}/generate-discount', [AbandonedCartController::class, 'generateDiscount']);
    Route::post('/abandoned-carts/{id}/contact-history', [AbandonedCartController::class, 'logContactEvent']);

    // Chat Center
    Route::prefix('chat-center')->group(function () {
        Route::get('/faqs', [FaqController::class, 'index']);
        Route::post('/faqs/sections', [FaqController::class, 'storeSection']);
        Route::put('/faqs/sections/{id}', [FaqController::class, 'updateSection']);
        Route::delete('/faqs/sections/{id}', [FaqController::class, 'destroySection']);
        Route::post('/faqs/questions', [FaqController::class, 'storeQuestion']);
        Route::put('/faqs/questions/{id}', [FaqController::class, 'updateQuestion']);
        Route::delete('/faqs/questions/{id}', [FaqController::class, 'destroyQuestion']);
        Route::put('/faqs/reorder', [FaqController::class, 'reorder']);

        Route::get('/settings', [ChatSettingsController::class, 'index']);
        Route::put('/settings', [ChatSettingsController::class, 'update']);

        Route::get('/conversations', [ConversationController::class, 'index']);
        Route::get('/conversations/{id}/messages', [ConversationController::class, 'messages']);
        Route::post('/conversations/{id}/messages', [ConversationController::class, 'storeMessage'])->middleware('throttle:chat-messages');
        Route::put('/conversations/{id}/read', [ConversationController::class, 'markAsRead']);
        Route::put('/conversations/{id}/end', [ConversationController::class, 'endConversation']);
        Route::delete('/conversations/{id}', [ConversationController::class, 'destroy']);
    });

    // Settings
    Route::prefix('settings')->group(function () {
        Route::get('/general', [AdminSettingsController::class, 'index']);
        Route::put('/general', [AdminSettingsController::class, 'update']);

        Route::get('/shipping/companies', [AdminShippingController::class, 'getCompanies']);
        Route::put('/shipping/companies/{code}', [AdminShippingController::class, 'updateCompany']);
        Route::get('/shipping/zones', [AdminShippingController::class, 'getZones']);
        Route::put('/shipping/zones', [AdminShippingController::class, 'updateZones']);

        Route::get('/payment/gateways', [AdminPaymentController::class, 'getGateways']);
        Route::put('/payment/gateways/{code}', [AdminPaymentController::class, 'updateGateway']);
    });

});

// ==========================================
// Storefront Auth Routes
// ==========================================
use App\Http\Controllers\Storefront\AuthController as StorefrontAuthController;

Route::prefix('v1/storefront/auth')->group(function () {
    Route::post('/login', [StorefrontAuthController::class, 'login'])->middleware('throttle:5,1');
    Route::post('/register', [StorefrontAuthController::class, 'register'])->middleware('throttle:5,1');
});

Route::middleware('auth:sanctum')->prefix('v1/storefront/auth')->group(function () {
    Route::post('/logout', [StorefrontAuthController::class, 'logout']);
    Route::get('/me', [StorefrontAuthController::class, 'me']);
});


// ==========================================
// Storefront Public Routes
// ==========================================
use App\Http\Controllers\Api\Storefront\StorefrontDataController;
use App\Http\Controllers\Api\Storefront\CheckoutController;
use App\Http\Controllers\Storefront\CartRecoveryController;
use App\Http\Controllers\Storefront\CartController;
use App\Http\Controllers\Api\Payment\PaymobWebhookController;
use App\Http\Controllers\Api\Storefront\PrintStationController;

Route::prefix('v1/storefront')->group(function () {
    Route::get('/categories', [StorefrontDataController::class, 'getCategories']);
    Route::get('/products', [StorefrontDataController::class, 'getProducts']);
    Route::get('/products/{id}', [StorefrontDataController::class, 'getProduct']);
    Route::get('/shipping-zones', [StorefrontDataController::class, 'getShippingZones']);
    Route::post('/checkout', [CheckoutController::class, 'process']);
    
    // Public Cart
    Route::get('/cart/recover/{uuid}', [CartRecoveryController::class, 'recover']);
    Route::post('/cart', [CartController::class, 'getOrCreate']);
    Route::post('/cart/contact', [CartController::class, 'captureContact']);
    Route::post('/cart/migrate', [CartController::class, 'migrate']);
    Route::post('/cart/items', [CartController::class, 'addItem']);
    Route::put('/cart/items/{itemId}', [CartController::class, 'updateItem']);
    Route::delete('/cart/items/{itemId}', [CartController::class, 'removeItem']);

    // Public Print Station
    Route::get('/printing-product-types', [PrintStationController::class, 'getPrintingProductTypes']);
    Route::get('/printing-types/{id}', [PrintStationController::class, 'getPrintingTypeDetails']);
    Route::post('/print/calculate-price', [PrintStationController::class, 'calculateLivePrice']);
    Route::post('/print/temp-upload', [PrintStationController::class, 'tempUpload']);
    Route::post('/print/add-to-cart', [PrintStationController::class, 'addToCart']);
    Route::get('/print/file-status/{cartItemId}', [PrintStationController::class, 'checkFileStatus']);
    Route::delete('/print/files/{cartItemId}/{category}', [PrintStationController::class, 'deleteUnlinkedFile']);
    
    // Blog
    Route::get('/blog-posts', [App\Http\Controllers\Api\Storefront\BlogController::class, 'index']);
    Route::get('/blog-posts/{idOrSlug}', [App\Http\Controllers\Api\Storefront\BlogController::class, 'show']);
    
    // Offers
    Route::get('/offers', [App\Http\Controllers\Api\Storefront\OfferController::class, 'index']);
});

Route::prefix('v1/payment')->group(function () {
    Route::post('/kashier/webhook', [\App\Http\Controllers\Api\Payment\KashierWebhookController::class, 'handle'])
        ->middleware(\App\Http\Middleware\KashierWebhookIPWhitelist::class);
});

Route::prefix('v1/shipping')->group(function () {
    Route::post('/webhook/{provider}', [\App\Http\Controllers\Api\Shipping\ShippingWebhookController::class, 'handle'])
        ->middleware(\App\Http\Middleware\ShippingWebhookSecurity::class);
});

Route::fallback(function (\Illuminate\Http\Request $request) {
    file_put_contents(storage_path('logs/fallback.log'), '[' . date('Y-m-d H:i:s') . '] 404 Fallback Hit! Method: ' . $request->method() . ', URL: ' . $request->fullUrl() . ', Headers: ' . json_encode($request->headers->all()) . PHP_EOL, FILE_APPEND);
    return response()->json(['error' => 'Fallback 404'], 404);
});

``

## File: `app\Models\Order.php`

``php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Casts\Attribute;

class Order extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'cart_id', 'customer_name', 'customer_phone', 'total', 'items_count',
        'status', 'payment_status', 'shipping_company',
        'tracking_number', 'shipping_address',
        'zone_id', 'subtotal', 'shipping_cost', 'payment_method'
    ];

    protected $appends = ['order_number'];

    protected function orderNumber(): Attribute
    {
        return Attribute::make(
            get: fn () => '#ORD-' . str_pad($this->id, 4, '0', STR_PAD_LEFT),
        );
    }

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }
}

``

## File: `app\Http\Controllers\Storefront\CartController.php`

``php
<?php

namespace App\Http\Controllers\Storefront;

use App\Http\Controllers\Controller;
use App\Services\Storefront\CartService;
use App\Models\Cart;
use Illuminate\Http\Request;

class CartController extends Controller
{
    protected $cartService;

    public function __construct(CartService $cartService)
    {
        $this->cartService = $cartService;
    }

    /**
     * Get the current cart for the session or create a new anonymous one.
     */
    public function getOrCreate(Request $request)
    {
        $sessionId = $request->header('X-Session-ID');
        $storeId = config('tenant.current_store_id') ?? $request->header('X-Store-ID');
        
        $cart = $this->cartService->getOrCreateCart(
            $sessionId,
            $storeId,
            $request->ip(),
            $request->userAgent()
        );

        $cart->load('items.printingType');
        
        $missingFiles = false;
        foreach ($cart->items as $item) {
            if ($item->file_status === 'expired') {
                $missingFiles = true;
                break;
            }
        }

        return response()->json([
            'cart' => $cart,
            'session_id' => $cart->session_id,
            'missing_required_files' => $missingFiles,
        ]);
    }

    /**
     * Capture contact details to promote the cart to guest.
     */
    public function captureContact(Request $request)
    {
        $request->validate([
            'session_id' => 'required|string',
            'email' => 'nullable|email',
            'phone' => 'nullable|string',
            'name' => 'nullable|string',
        ]);

        if (!$request->email && !$request->phone) {
            return response()->json(['message' => 'Email or phone is required'], 422);
        }

        // The TenantScope will automatically scope this to the current store
        $cart = Cart::where('session_id', $request->session_id)
            ->whereIn('status', ['active', 'pending'])
            ->firstOrFail();

        $data = $request->only(['name', 'email', 'phone']);
        $data['ip_address'] = $request->ip();
        $data['user_agent'] = $request->userAgent();

        $cart = $this->cartService->captureContact($cart, $data);

        return response()->json([
            'message' => 'Contact details captured successfully',
            'cart' => $cart
        ]);
    }

    public function addItem(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
            'variant_id' => 'nullable|exists:product_variants,id',
            'quantity' => 'required|integer|min:1',
            'addons' => 'nullable|array',
            'addons.*.product_addon_id' => 'required|exists:product_addons,id',
            'addons.*.temp_file_id' => 'nullable|string'
        ]);

        $sessionId = $request->header('X-Session-ID');
        if (!$sessionId) return response()->json(['message' => 'Session ID required'], 400);

        $cart = Cart::where('session_id', $sessionId)->firstOrFail();

        $cartItem = $this->cartService->addStandardItem($cart, $request->all());

        return response()->json([
            'message' => 'Item added',
            'cart_item' => $cartItem->load('addons')
        ]);
    }

    public function updateItem(Request $request, $itemId)
    {
        $request->validate([
            'quantity' => 'required|integer|min:1',
        ]);

        $sessionId = $request->header('X-Session-ID');
        if (!$sessionId) return response()->json(['message' => 'Session ID required'], 400);

        $cart = Cart::where('session_id', $sessionId)->firstOrFail();
        $cartItem = \App\Models\CartItem::where('cart_id', $cart->id)->where('id', $itemId)->firstOrFail();

        $cartItem = $this->cartService->updateItemQuantity($cartItem, $request->quantity);

        return response()->json([
            'message' => 'Item updated',
            'cart_item' => $cartItem
        ]);
    }

    public function removeItem(Request $request, $itemId)
    {
        $sessionId = $request->header('X-Session-ID');
        if (!$sessionId) return response()->json(['message' => 'Session ID required'], 400);

        $cart = Cart::where('session_id', $sessionId)->firstOrFail();
        $cartItem = \App\Models\CartItem::where('cart_id', $cart->id)->where('id', $itemId)->firstOrFail();

        $cartItem->delete();

        return response()->json(['message' => 'Item removed']);
    }

    public function migrate(Request $request)
    {
        $request->validate([
            'items' => 'required|array',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.variant_id' => 'nullable|exists:product_variants,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.addons' => 'nullable|array',
        ]);

        $sessionId = $request->header('X-Session-ID');
        $storeId = config('tenant.current_store_id') ?? $request->header('X-Store-ID');
        
        $cart = $this->cartService->getOrCreateCart(
            $sessionId,
            $storeId,
            $request->ip(),
            $request->userAgent()
        );

        $this->cartService->migrateLegacyCart($cart, $request->items);

        return response()->json([
            'message' => 'Cart migrated',
            'cart' => $cart->load(['items.addons', 'items.printingType'])
        ]);
    }
}

``

## File: `app\Services\Storefront\CartService.php`

``php
<?php

namespace App\Services\Storefront;

use App\Models\Cart;
use App\Models\Customer;
use Illuminate\Support\Str;

class CartService
{
    /**
     * Get or create an anonymous cart for the session.
     */
    public function getOrCreateCart(?string $sessionId, ?int $storeId, ?string $ip, ?string $userAgent): Cart
    {
        if (!$sessionId) {
            $sessionId = Str::uuid()->toString();
        }

        $cart = Cart::where('session_id', $sessionId)
            ->whereIn('status', ['active', 'pending'])
            ->first();

        if (!$cart) {
            $cart = Cart::create([
                'uuid' => Str::uuid()->toString(),
                'session_id' => $sessionId,
                'store_id' => $storeId,
                'customer_type' => 'anonymous',
                'status' => 'active',
                'ip_address' => $ip,
                'user_agent' => $userAgent,
            ]);
        } else {
            // Update IP and User Agent on subsequent accesses to track the latest snapshot
            $cart->update([
                'ip_address' => $ip,
                'user_agent' => $userAgent,
            ]);
        }

        return $cart;
    }

    /**
     * Capture contact details, snapshot them, and promote to Guest.
     */
    public function captureContact(Cart $cart, array $data): Cart
    {
        // 1. Snapshot Data in Cart
        $cart->customer_name = $data['name'] ?? $cart->customer_name;
        $cart->customer_email = $data['email'] ?? $cart->customer_email;
        $cart->customer_phone = $data['phone'] ?? $cart->customer_phone;
        
        if (isset($data['ip_address'])) $cart->ip_address = $data['ip_address'];
        if (isset($data['user_agent'])) $cart->user_agent = $data['user_agent'];

        // 2. Promote to Guest in Customers table
        if ($cart->customer_email || $cart->customer_phone) {
            $customer = $this->findOrCreateGuestCustomer(
                $cart->store_id,
                $cart->session_id,
                $cart->customer_name,
                $cart->customer_email,
                $cart->customer_phone,
                $cart->ip_address,
                $cart->user_agent
            );

            $cart->customer_id = $customer->id;
            
            // Only promote anonymous to guest, don't downgrade registered
            if ($cart->customer_type === 'anonymous') {
                $cart->customer_type = 'guest';
            }
        }

        $cart->save();

        return $cart;
    }

    protected function findOrCreateGuestCustomer($storeId, $sessionId, $name, $email, $phone, $ip, $userAgent)
    {
        $customer = null;

        // 1. Priority lookup by Email (Strongest Identifier)
        if ($email) {
            $customer = Customer::where('store_id', $storeId)->where('email', $email)->first();
        }

        // 2. Secondary lookup by Phone
        if (!$customer && $phone) {
            $customer = Customer::where('store_id', $storeId)->where('phone', $phone)->first();
        }

        if (!$customer) {
            // Create completely new guest customer
            $customer = Customer::create([
                'store_id' => $storeId,
                'session_id' => $sessionId,
                'name' => $name,
                'email' => $email,
                'phone' => $phone,
                'ip_address' => $ip,
                'user_agent' => $userAgent,
            ]);
        } else {
            // Update session and security snapshot if customer already exists
            $updateData = [
                'session_id' => $sessionId,
                'ip_address' => $ip,
                'user_agent' => $userAgent,
            ];

            // Only populate missing fields to prevent data corruption from mistyped inputs
            if (!$customer->email && $email) $updateData['email'] = $email;
            if (!$customer->phone && $phone) $updateData['phone'] = $phone;
            if (!$customer->name && $name) $updateData['name'] = $name;

            $customer->update($updateData);
        }

        return $customer;
    }

    /**
     * Calculate price for selected addons and lock inventory if needed.
     */
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
            if ($multiplier === 'per_item') {
                $totalAddonPrice = $addonPrice * $itemQuantity;
            } else {
                $totalAddonPrice = $addonPrice;
            }

            $subtotal += $totalAddonPrice;
            $snapshots[] = [
                'product_addon_id' => $addon->id,
                'name' => $addon->name,
                'price_type' => $addon->price_type,
                'price_at_purchase' => $addonPrice,
                'total' => $totalAddonPrice,
                'multiplier_type' => $multiplier,
                'quantity' => $itemQuantity, // tracking quantity for per_item
            ];

            // Handle Addon Inventory
            if ($addon->track_inventory) {
                $qtyToDeduct = ($multiplier === 'per_item') ? $itemQuantity : 1;
                if ($addon->available_quantity < $qtyToDeduct) {
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

    /**
     * Add a standard item to the cart.
     */
    public function addStandardItem(Cart $cart, array $data)
    {
        // Add to cart_items table
        $cartItem = \App\Models\CartItem::create([
            'cart_id' => $cart->id,
            'product_id' => $data['product_id'],
            'product_variant_id' => $data['variant_id'] ?? null,
            'quantity' => $data['quantity'],
        ]);

        // Process Addons
        if (!empty($data['addons'])) {
            foreach ($data['addons'] as $addon) {
                // If there's a temp file, validate IDOR
                if (!empty($addon['temp_file_id'])) {
                    $tempUpload = \App\Models\TemporaryUpload::where('id', $addon['temp_file_id'])
                        ->where(function($query) use ($cart) {
                            $query->where('session_id', $cart->session_id)
                                  ->orWhere('user_id', auth('sanctum')->id());
                        })->first();

                    if (!$tempUpload) {
                        throw \Illuminate\Validation\ValidationException::withMessages([
                            'addons' => "الملف المرفوع غير صالح أو لا ينتمي لجلستك الحالية."
                        ]);
                    }
                }

                \App\Models\CartItemAddon::create([
                    'cart_item_id' => $cartItem->id,
                    'product_addon_id' => $addon['product_addon_id'],
                    'temp_file_id' => $addon['temp_file_id'] ?? null,
                ]);
            }
        }

        return $cartItem;
    }

    public function updateItemQuantity(\App\Models\CartItem $cartItem, int $quantity)
    {
        $cartItem->update(['quantity' => $quantity]);
        return $cartItem;
    }

    public function migrateLegacyCart(Cart $cart, array $items)
    {
        foreach ($items as $itemData) {
            // Find existing matching standard product
            $existingItem = \App\Models\CartItem::where('cart_id', $cart->id)
                ->where('product_id', $itemData['product_id'])
                ->where('product_variant_id', $itemData['variant_id'] ?? null)
                ->whereNull('printing_type_id') // Ensure it's a standard product
                ->first();

            // For simplicity in migration and to prevent losing addon selections,
            // we only merge quantities if BOTH items have zero addons.
            // If they have addons, we insert as a separate line item.
            
            if ($existingItem && empty($itemData['addons'])) {
                // Check if existing item also has no addons
                if ($existingItem->addons()->count() === 0) {
                    // Merge Conflict Resolution: Sum quantities
                    $existingItem->update([
                        'quantity' => $existingItem->quantity + $itemData['quantity']
                    ]);
                    continue;
                }
            }

            // Otherwise, create a new item
            $this->addStandardItem($cart, $itemData);
        }
    }
}

``

## File: `app\Services\Shipping\ShippingProviderInterface.php`

``php
<?php

namespace App\Services\Shipping;

use App\Models\Order;

interface ShippingProviderInterface
{
    /**
     * Calculate the shipping cost dynamically via API.
     * Should throw an exception on failure or return null to trigger static fallback.
     * 
     * @param Order $order
     * @return float|null
     */
    public function calculateCost(Order $order): ?float;

    /**
     * Create a shipping waybill for the order.
     * 
     * @param Order $order
     * @return array Contains tracking_number and waybill_url
     */
    public function createWaybill(Order $order): array;

    /**
     * Track a shipment by its tracking number.
     * 
     * @param string $trackingNumber
     * @return string Current status
     */
    public function trackShipment(string $trackingNumber): string;

    /**
     * Parse webhook payload and standardize status.
     * 
     * @param array $payload
     * @return array ['tracking_number' => string, 'status' => string, 'timestamp' => Carbon]
     */
    public function parseWebhook(array $payload): array;
}

``

## File: `app\Services\Shipping\ShippingFactory.php`

``php
<?php

namespace App\Services\Shipping;

use App\Models\Order;
use Exception;
use Illuminate\Support\Facades\Log;

class ShippingFactory
{
    /**
     * Get the active shipping provider based on order details or store settings.
     * 
     * @param Order $order
     * @return ShippingProviderInterface|null
     */
    public function getProvider(Order $order): ?ShippingProviderInterface
    {
        // For Phase 1, we will return null or resolve based on configuration.
        // E.g., if (setting('shipping_provider') === 'bosta') return new BostaProvider();
        return null; // By returning null, we force the fallback calculation.
    }

    /**
     * Calculate cost with static fallback.
     */
    public function calculateCostWithFallback(Order $order): array
    {
        $provider = $this->getProvider($order);
        
        if ($provider) {
            try {
                $cost = $provider->calculateCost($order);
                if ($cost !== null) {
                    return [
                        'cost' => $cost,
                        'is_fallback' => false
                    ];
                }
            } catch (Exception $e) {
                Log::error("Shipping API Calculation Failed: " . $e->getMessage());
                // Fallback to static
            }
        }

        // Static Fallback logic based on Shipping Zone
        $shippingZone = \App\Models\ShippingZone::find($order->shipping_zone_id);
        $cost = $shippingZone ? $shippingZone->cost : 0.0;

        return [
            'cost' => (float) $cost,
            'is_fallback' => true
        ];
    }
}

``

## File: `app\Http\Controllers\Api\Shipping\ShippingWebhookController.php`

``php
<?php

namespace App\Http\Controllers\Api\Shipping;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Order;
use App\Services\Shipping\ShippingFactory;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

class ShippingWebhookController extends Controller
{
    protected $shippingFactory;

    public function __construct(ShippingFactory $shippingFactory)
    {
        $this->shippingFactory = $shippingFactory;
    }

    public function handle(Request $request, string $providerName)
    {
        try {
            // Find provider (this would normally map to the specific provider class)
            // For now, we simulate resolving it.
            // $provider = $this->shippingFactory->resolveProviderByName($providerName);
            // $parsedData = $provider->parseWebhook($request->all());
            
            // Dummy implementation for Phase 1
            $parsedData = [
                'tracking_number' => $request->input('tracking_number'),
                'status' => $request->input('status'),
                'timestamp' => Carbon::parse($request->input('timestamp') ?? now()),
            ];

            if (!$parsedData['tracking_number'] || !$parsedData['status']) {
                return response()->json(['message' => 'Invalid payload'], 400);
            }

            $order = Order::where('tracking_number', $parsedData['tracking_number'])->first();
            
            if (!$order) {
                return response()->json(['message' => 'Order not found'], 404);
            }

            // Timestamp-Based Idempotency Check (Strict: Less Than or Equal)
            if ($order->latest_shipping_update_at && $parsedData['timestamp']->lte($order->latest_shipping_update_at)) {
                Log::info("Ignored out-of-order or duplicate webhook for order {$order->id}");
                return response()->json(['message' => 'Ignored out-of-order or duplicate webhook'], 200);
            }

            // Update order status
            $order->update([
                'status' => $parsedData['status'], // Ensure this maps to valid system statuses
                'latest_shipping_update_at' => $parsedData['timestamp']
            ]);

            return response()->json(['message' => 'Status updated successfully']);

        } catch (\Exception $e) {
            Log::error("Shipping Webhook Error ($providerName): " . $e->getMessage());
            return response()->json(['message' => 'Internal server error'], 500);
        }
    }
}

``

## File: `app\Http\Middleware\ShippingWebhookSecurity.php`

``php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ShippingWebhookSecurity
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $provider = $request->route('provider');
        
        // Skip verification if in local dev without a secret (Optional, but good for safety we enforce it if config exists)
        $secret = config("shipping.providers.{$provider}.webhook_secret");
        
        if ($secret) {
            $signature = $request->header('X-Webhook-Signature');
            
            if (!$signature || !$this->verifySignature($request->getContent(), $signature, $secret)) {
                return response()->json(['message' => 'Unauthorized webhook signature'], 401);
            }
        }

        return $next($request);
    }

    /**
     * Verify HMAC SHA-256 Signature
     */
    protected function verifySignature(string $payload, string $signature, string $secret): bool
    {
        $expectedSignature = hash_hmac('sha256', $payload, $secret);
        return hash_equals($expectedSignature, $signature);
    }
}

``

## File: `app\Http\Controllers\Api\Storefront\CheckoutController.php`

``php
<?php

namespace App\Http\Controllers\Api\Storefront;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Order;
use App\Models\Cart;
use App\Models\ShippingZone;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;

class CheckoutController extends Controller
{
    public function process(Request $request)
    {
        // 1. Validation Logic (NO CART ITEMS HERE! Backend Source of Truth)
        $request->validate([
            'customer_name' => 'required|string|max:255',
            'customer_phone' => 'required|string|max:20',
            'shipping_address' => 'required|string',
            'zone_id' => 'required|exists:shipping_zones,id',
            'payment_method' => 'required|in:cod,visa,kashier',
            'success_url' => 'nullable|url',
            'failure_url' => 'nullable|url',
        ]);

        // 2. Fetch Active Cart from Database (Strict Backend Source of Truth)
        $sessionId = $request->header('X-Session-ID');
        $userId = auth()->id();

        $cartQuery = Cart::with(['items.product', 'items.productVariant', 'items.printingType', 'items.addons.productAddon']);
        
        if ($userId) {
            $cartQuery->where('user_id', $userId);
        } else {
            if (!$sessionId) {
                throw ValidationException::withMessages(['cart' => 'السلة فارغة أو الجلسة غير صالحة.']);
            }
            $cartQuery->where('session_id', $sessionId);
        }

        $cart = $cartQuery->where('status', 'active')->first();

        if (!$cart || $cart->items->isEmpty()) {
            throw ValidationException::withMessages(['cart' => 'السلة فارغة، يرجى إضافة منتجات أولاً.']);
        }

        $hasPrintingItem = $cart->items->contains('item_type', 'printing');
        if ($hasPrintingItem && $request->payment_method === 'cod') {
            throw ValidationException::withMessages([
                'payment_method' => 'السلة تحتوي على منتجات طباعة مخصصة، يجب الدفع إلكترونياً مسبقاً.'
            ]);
        }

        try {
            DB::beginTransaction();

            $subtotal = 0;
            $itemsCount = 0;
            $orderItemsData = [];
            $reservationIds = [];

            // 3. Process Cart Items directly from DB
            foreach ($cart->items as $cartItem) {
                if ($cartItem->item_type === 'printing') {
                    $typeModel = $cartItem->printingType;
                    
                    if (!$typeModel) {
                        throw ValidationException::withMessages(['cart' => "نوع الطباعة غير موجود."]);
                    }

                    // [V14 Security Fix] Backend Pre-Payment Validation
                    if ($typeModel->requires_upload && $cartItem->file_status !== 'approved') {
                        throw ValidationException::withMessages([
                            'cart' => "لا يمكن إتمام الطلب، الملف المرفوع للمنتج غير معتمد أو جاري فحصه."
                        ]);
                    }

                    // [V14 Tax Fix & Security Fix]
                    $pricingService = app(\App\Services\PrintPricingService::class);
                    $pricingResult = $pricingService->calculatePrice(
                        $cartItem->printing_type_id, 
                        $cartItem->quantity, 
                        $cartItem->printing_options['selected_options'] ?? [], 
                        $cartItem->width_mm, 
                        $cartItem->length_mm, 
                        $cartItem->tax_basis_points_snapshot,
                        $cartItem->printing_options['image_count'] ?? 1
                    );

                    $itemTotal = $pricingResult['final_price_egp'];
                    $subtotal += $itemTotal;
                    $itemsCount += $cartItem->quantity;

                    $name = $cartItem->custom_product_name ?? $typeModel->name;

                    $orderItemsData[] = [
                        'item_type' => 'printing',
                        'printing_type_id' => $cartItem->printing_type_id,
                        'custom_product_name' => $cartItem->custom_product_name,
                        'printing_options' => $cartItem->printing_options ?? [],
                        'name' => $name,
                        'quantity' => $cartItem->quantity,
                        'price_at_purchase' => $cartItem->quantity > 0 ? $itemTotal / $cartItem->quantity : 0,
                        'total' => $itemTotal,
                        'uploaded_files' => $cartItem->uploaded_files,
                        'file_status' => $cartItem->file_status,
                        'tax_basis_points_snapshot' => $cartItem->tax_basis_points_snapshot
                    ];
                    continue;
                }

                // Standard product logic
                $product = $cartItem->product;
                if (!$product) {
                    throw ValidationException::withMessages([
                        'cart' => "أحد المنتجات في السلة لم يعد متوفراً."
                    ]);
                }
                
                $variant = $cartItem->productVariant;
                
                if ($product->variants()->exists() && !$variant) {
                    throw ValidationException::withMessages([
                        'cart' => "يجب اختيار مقاس أو لون للمنتج: {$product->name}"
                    ]);
                }

                // Check Inventory & Lock Stock
                if ($variant) {
                    $variant->lockForUpdate();
                    if ($product->track_inventory && $variant->available_quantity < $cartItem->quantity) {
                        throw ValidationException::withMessages([
                            'cart' => "الكمية المطلوبة من {$product->name} غير متوفرة بالمخزن."
                        ]);
                    }
                    $priceToUse = $variant->discount_price ?? $variant->price;

                    if ($product->track_inventory) {
                        $res = \App\Models\StockReservation::create([
                            'product_variant_id' => $variant->id,
                            'session_id' => $sessionId,
                            'user_id' => $userId,
                            'quantity' => $cartItem->quantity,
                            'expires_at' => now()->addMinutes(15)
                        ]);
                        $reservationIds[] = $res->id;
                    }
                } else {
                    $product->lockForUpdate();
                    if ($product->track_inventory && $product->available_quantity < $cartItem->quantity) {
                        throw ValidationException::withMessages([
                            'cart' => "الكمية المطلوبة من {$product->name} غير متوفرة بالمخزن."
                        ]);
                    }
                    $priceToUse = $product->discount_price ?? $product->price;

                    if ($product->track_inventory) {
                        $res = \App\Models\StockReservation::create([
                            'product_id' => $product->id,
                            'session_id' => $sessionId,
                            'user_id' => $userId,
                            'quantity' => $cartItem->quantity,
                            'expires_at' => now()->addMinutes(15)
                        ]);
                        $reservationIds[] = $res->id;
                    }
                }

                $itemTotal = $priceToUse * $cartItem->quantity;
                
                // Addons calculation
                $addonSnapshots = [];
                if ($cartItem->addons->isNotEmpty()) {
                    $itemAddonIds = $cartItem->addons->pluck('product_addon_id')->toArray();
                    
                    $lockedAddons = \App\Models\ProductAddon::with('group')
                                        ->whereIn('id', $itemAddonIds)
                                        ->lockForUpdate()
                                        ->get()
                                        ->keyBy('id');

                    $reservedAddons = app(\App\Services\Storefront\CartService::class)->calculateAddonsPrice(
                        (float)$priceToUse,
                        (int)$cartItem->quantity,
                        $itemAddonIds,
                        $itemTotal,
                        $lockedAddons,
                        $addonSnapshots
                    );
                    
                    if ($reservedAddons) {
                        $reservationIds = array_merge($reservationIds, $reservedAddons);
                    }
                    
                    // Attach temp_file_id from DB Truth (cart_item_addons)
                    foreach ($addonSnapshots as &$snap) {
                        $serverAddon = $cartItem->addons->firstWhere('product_addon_id', $snap['product_addon_id']);
                        if ($serverAddon && !empty($serverAddon->temp_file_id)) {
                            $snap['temp_file_id'] = $serverAddon->temp_file_id;
                        }
                    }
                }

                $subtotal += $itemTotal;
                $itemsCount += $cartItem->quantity; 

                $orderItemsData[] = [
                    'item_type' => 'standard',
                    'product_id' => $product->id,
                    'variant_id' => $variant ? $variant->id : null,
                    'name' => $product->name,
                    'quantity' => $cartItem->quantity,
                    'price_at_purchase' => $priceToUse,
                    'total' => $itemTotal,
                    'addons' => $addonSnapshots,
                ];
            }

            // Calculate Shipping
            $shippingZone = ShippingZone::findOrFail($request->zone_id);
            $shippingCost = $shippingZone->cost;
            $grandTotal = $subtotal + $shippingCost;

            // إنشاء الطلب (Data Hijacking Prevention: Independent Data)
            $order = Order::create([
                'cart_id' => $cart->id,
                'customer_name' => $request->customer_name,
                'customer_phone' => $request->customer_phone,
                'shipping_address' => $request->shipping_address,
                'zone_id' => $request->zone_id,
                'subtotal' => $subtotal,
                'shipping_cost' => $shippingCost,
                'total' => $grandTotal,
                'items_count' => $itemsCount,
                'status' => 'pending',
                'payment_status' => 'unpaid',
                'payment_method' => $request->payment_method,
            ]);

            // إنشاء عناصر الطلب
            foreach ($orderItemsData as $data) {
                $addons = $data['addons'] ?? [];
                unset($data['addons']);
                $orderItem = $order->items()->create($data);
                
                foreach ($addons as $addonData) {
                    // [SQL Crash Fix] Remove temp_file_id from DB insert array
                    $orderItemAddon = $orderItem->addons()->create([
                        'product_addon_id' => $addonData['product_addon_id'],
                        'name' => $addonData['name'],
                        'price_type' => $addonData['price_type'],
                        'price_at_purchase' => $addonData['price_at_purchase'],
                        'total' => $addonData['total'],
                    ]);

                    if (!empty($addonData['temp_file_id'])) {
                        $tempUpload = \App\Models\TemporaryUpload::find($addonData['temp_file_id']);
                        if ($tempUpload && \Illuminate\Support\Facades\Storage::disk('public')->exists($tempUpload->file_path)) {
                            $newPath = str_replace('temp_uploads/', 'addon_uploads/', $tempUpload->file_path);
                            \Illuminate\Support\Facades\Storage::disk('public')->move($tempUpload->file_path, $newPath);
                            $orderItemAddon->update(['file_path' => $newPath]);
                            $tempUpload->delete();
                        }
                    }
                }
            }

            if (!empty($reservationIds)) {
                \App\Models\StockReservation::whereIn('id', $reservationIds)->update(['order_id' => $order->id]);
            }

            // [Cart Lock & Purge Logic]
            if ($request->payment_method === 'cod') {
                $cart->update(['status' => 'converted']);
            } else {
                $cart->update(['status' => 'locked']);
            }

            DB::commit();

            // Handle Payment Gateway Logic
            if ($request->payment_method === 'kashier') {
                $kashierService = app(\App\Services\Payment\KashierService::class);
                $paymentUrl = $kashierService->generateCheckoutUrl(
                    $order, 
                    $request->success_url, 
                    $request->failure_url
                );
                
                return response()->json([
                    'message' => 'Order created successfully',
                    'order_id' => $order->id,
                    'payment_url' => $paymentUrl
                ]);
            }

            if ($request->payment_method === 'visa') {
                $paymentUrl = 'https://paymob.com/mock-url'; 
                return response()->json([
                    'message' => 'Order created successfully',
                    'order_id' => $order->id,
                    'payment_url' => $paymentUrl
                ]);
            }

            // For Cash On Delivery
            \App\Jobs\CreateShippingWaybillJob::dispatch($order->id)->afterCommit();
            return response()->json([
                'message' => 'Order created successfully',
                'order_id' => $order->id
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Checkout Failed: ' . $e->getMessage());
            
            if ($e instanceof ValidationException) {
                throw $e;
            }
            
            return response()->json(['error' => 'حدث خطأ أثناء معالجة الطلب.'], 500);
        }
    }
}

``

