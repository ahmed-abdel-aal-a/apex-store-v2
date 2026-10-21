# Pull Request: Phase 3 (Storefront Checkout Logic) 

هذا الملف يحتوي على الأكواد التي تم تحديثها في مرحلة الدفع لتجريد الـ Payload من بيانات السلة والاعتماد على السيرفر تماماً، بالإضافة إلى تفعيل أقفال الـ Sync Lock وحماية منتجات الطباعة.


## File: `storefront\lib\api.ts`

``tsx
export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api/v1';

export async function fetchCategories() {
    try {
        const res = await fetch(`${API_URL}/storefront/categories`, {
            next: { tags: ['categories'] }
        });
        if (!res.ok) throw new Error('Failed to fetch categories');
        const json = await res.json();
        return json.data;
    } catch (error) {
        console.error('Error fetching categories:', error);
        return [];
    }
}

import { DEFAULT_MIN_PRICE, DEFAULT_MAX_PRICE } from "./constants";

export async function fetchProducts(page: number = 1, category: string = 'الكل', minPrice?: number, maxPrice?: number, searchQuery?: string) {
    try {
        const params = new URLSearchParams({
            page: page.toString(),
            ...(category !== 'الكل' && { category_id: category }),
            ...(minPrice !== undefined && { min_price: minPrice.toString() }),
            ...(maxPrice !== undefined && { max_price: maxPrice.toString() }),
            ...(searchQuery && { search: searchQuery })
        });
        
        const isDefaultMin = minPrice === undefined || minPrice === DEFAULT_MIN_PRICE;
        const isDefaultMax = maxPrice === undefined || maxPrice === DEFAULT_MAX_PRICE;
        const hasFilters = (category !== 'الكل') || !isDefaultMin || !isDefaultMax || !!searchQuery;
        
        const fetchOptions: RequestInit = hasFilters 
            ? { cache: 'no-store' } 
            : { next: { tags: ['products'] } };

        const res = await fetch(`${API_URL}/storefront/products?${params.toString()}`, fetchOptions);
        if (!res.ok) throw new Error('Failed to fetch products');
        const data = await res.json();
        return data.data;
    } catch (error) {
        console.error('Error fetching products:', error);
        return null;
    }
}

export async function fetchShippingZones() {
    try {
        const res = await fetch(`${API_URL}/shipping-zones`);
        if (!res.ok) throw new Error('Failed to fetch shipping zones');
        return await res.json();
    } catch (error) {
        console.error('Error fetching shipping zones:', error);
        return [];
    }
}

export async function processCheckout(payload: any, sessionId: string) {
    try {
        const res = await fetch(`${API_URL}/checkout`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Session-ID': sessionId
            },
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (!res.ok) {
            // Throw the validation errors or general error
            throw new Error(data.message || data.error || 'Failed to process checkout');
        }
        return data;
    } catch (error: any) {
        throw error;
    }
}

export async function fetchProductById(id: string) {
    try {
        const res = await fetch(`${API_URL}/storefront/products/${id}`);
        if (!res.ok) throw new Error('Failed to fetch product');
        const json = await res.json();
        return json.data;
    } catch (error) {
        console.error('Error fetching product:', error);
        return null;
    }
}

export async function login(payload: any) {
    const res = await fetch(`${API_URL}/storefront/auth/login`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || 'Login failed');
    return data;
}

export async function register(payload: any) {
    const res = await fetch(`${API_URL}/storefront/auth/register`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || 'Registration failed');
    return data;
}

export async function logout(token: string) {
    try {
        await fetch(`${API_URL}/storefront/auth/logout`, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Authorization': `Bearer ${token}`
            }
        });
    } catch (e) {
        // ignore errors on logout
    }
}

export async function getUser(token: string) {
    try {
        const res = await fetch(`${API_URL}/storefront/auth/me`, {
            headers: {
                'Accept': 'application/json',
                'Authorization': `Bearer ${token}`
            }
        });
        if (!res.ok) return null;
        const data = await res.json();
        return data.user || data.customer || data.data;
    } catch {
        return null;
    }
}

``

## File: `storefront\app\checkout\page.tsx`

``tsx
"use client";

import React, { useState, useEffect } from "react";
import { PageTransition } from "@/components/UI/Animations";
import { useAppContext } from "@/context/AppContext";
import { useRouter } from "next/navigation";
import { CheckCircle2, ArrowRight, Loader2, AlertCircle } from "lucide-react";
import { fetchShippingZones, processCheckout } from "@/lib/api";

export default function CheckoutPage() {
  const { cart, user, isCartSyncing, sessionId, clearCart } = useAppContext();
  const router = useRouter();
  
  const hasPrinting = cart.some(item => item.category === 'printing' || item.isPrinting);
  
  const [isSuccess, setIsSuccess] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState(hasPrinting ? "online" : "cod"); 
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  
  const [shippingZones, setShippingZones] = useState<any[]>([]);
  const [formData, setFormData] = useState({
    customer_name: user?.name || "",
    customer_phone: "",
    shipping_address: "",
    zone_id: ""
  });

  useEffect(() => {
    async function loadZones() {
      const zones = await fetchShippingZones();
      setShippingZones(zones);
    }
    loadZones();
  }, []);

  // Force online payment if there's a printing item
  useEffect(() => {
    if (hasPrinting && paymentMethod === "cod") {
      setPaymentMethod("online");
    }
  }, [hasPrinting, paymentMethod]);

  const subtotal = cart.reduce((sum, item) => {
    let itemTotal = item.price * item.quantity;
    let addonsTotal = 0;
    if (item.addons) {
      item.addons.forEach(a => {
        if (a.price_multiplier_type === 'per_item') {
          addonsTotal += a.price * item.quantity;
        } else {
          addonsTotal += a.price;
        }
      });
    }
    return sum + itemTotal + addonsTotal;
  }, 0);
  
  const selectedZone = shippingZones.find(z => z.id.toString() === formData.zone_id);
  const shippingCost = selectedZone ? Number(selectedZone.cost) : 0;
  const total = subtotal + shippingCost;

  if (cart.length === 0 && !isSuccess) {
    router.push("/shop");
    return null;
  }

  const handleCheckout = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage("");
    
    if (!formData.zone_id) {
        setErrorMessage("الرجاء اختيار المحافظة");
        return;
    }
    
    if (!sessionId) {
        setErrorMessage("خطأ في الجلسة، يرجى تحديث الصفحة");
        return;
    }

    setIsLoading(true);
    try {
      const payload = {
          customer_name: formData.customer_name,
          customer_phone: formData.customer_phone,
          shipping_address: formData.shipping_address,
          zone_id: formData.zone_id,
          payment_method: paymentMethod === 'online' ? 'visa' : 'cod',
          success_url: window.location.origin + '/checkout/success',
          failure_url: window.location.origin + '/checkout/error',
      };

      const result = await processCheckout(payload, sessionId);
      
      if (paymentMethod === 'online' && result.payment_url) {
          window.location.href = result.payment_url;
      } else {
          clearCart(); // ONLY on COD success, online retains cart until webhook/success page resolves
          setIsSuccess(true);
      }
    } catch (error: any) {
      setErrorMessage(error.message || "حدث خطأ أثناء الدفع");
    } finally {
      setIsLoading(false);
    }
  };

  if (isSuccess) {
    return (
      <PageTransition>
        <div className="max-w-md mx-auto px-4 pt-32 pb-24 text-center">
          <div className="w-24 h-24 bg-green-500/15 text-green-500 rounded-full flex items-center justify-center mx-auto mb-8">
            <CheckCircle2 size={48} />
          </div>
          <h1 className="text-4xl font-black mb-4">تم تأكيد طلبك!</h1>
          <p className="text-gray-500 mb-8 text-lg">
            شكراً لتسوقك معنا. رقم طلبك هو{" "}
            <span className="font-mono font-bold text-white">#ORD-7392</span>
            . سيتم التواصل معك قريباً.
          </p>
          <button
            onClick={() => router.push("/")}
            className="bg-yellow-400 text-black font-bold px-8 py-4 rounded-full hover:bg-yellow-300 transition-colors"
          >
            العودة للرئيسية
          </button>
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition>
      <div className="max-w-5xl mx-auto px-4 pt-28 md:pt-32 pb-8 md:pb-12">
        <button
          onClick={() => router.back()}
          className="flex items-center gap-2 text-gray-500 hover:text-white mb-8 font-bold transition-colors w-fit"
        >
          <ArrowRight size={20} /> العودة للسلة
        </button>

        <h1 className="text-3xl font-black mb-8">إتمام الطلب</h1>

        <div className="flex flex-col lg:flex-row gap-8">
          <div className="flex-1">
            <form
              id="checkout-form"
              onSubmit={handleCheckout}
              className="space-y-8"
            >
              <div className="bg-[#111111] p-6 md:p-8 rounded-3xl shadow-sm shadow-black/30 border border-yellow-500/20">
                <h2 className="text-xl font-bold mb-6">بيانات الشحن</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      الاسم
                    </label>
                    <input
                      required
                      value={formData.customer_name}
                      onChange={e => setFormData({...formData, customer_name: e.target.value})}
                      type="text"
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      رقم الهاتف
                    </label>
                    <input
                      required
                      type="tel"
                      value={formData.customer_phone}
                      onChange={e => setFormData({...formData, customer_phone: e.target.value})}
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400"
                      dir="ltr"
                    />
                  </div>
                  <div className="md:col-span-2">
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      العنوان بالتفصيل
                    </label>
                    <textarea
                      required
                      value={formData.shipping_address}
                      onChange={e => setFormData({...formData, shipping_address: e.target.value})}
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400 min-h-[100px]"
                    ></textarea>
                  </div>
                  <div className="md:col-span-2">
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      المحافظة
                    </label>
                    <select
                      required
                      value={formData.zone_id}
                      onChange={e => setFormData({...formData, zone_id: e.target.value})}
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400"
                    >
                        <option value="">اختر المحافظة...</option>
                        {shippingZones.map(zone => (
                            <option key={zone.id} value={zone.id}>{zone.name}</option>
                        ))}
                    </select>
                  </div>
                </div>
              </div>

              <div className="bg-[#111111] p-6 md:p-8 rounded-3xl shadow-sm shadow-black/30 border border-yellow-500/20">
                <h2 className="text-xl font-bold mb-6">طريقة الدفع</h2>
                <div className="space-y-4">
                  <label
                    className={`flex items-start gap-4 p-4 rounded-xl border-2 transition-colors ${
                      hasPrinting 
                        ? "opacity-50 cursor-not-allowed border-white/[0.04]" 
                        : paymentMethod === "cod" 
                          ? "border-yellow-400 bg-yellow-400/10 cursor-pointer" 
                          : "border-white/[0.06] hover:border-white/[0.08] cursor-pointer"
                    }`}
                  >
                    <input
                      type="radio"
                      name="payment"
                      value="cod"
                      checked={paymentMethod === "cod"}
                      onChange={() => { if (!hasPrinting) setPaymentMethod("cod"); }}
                      disabled={hasPrinting}
                      className="w-5 h-5 accent-yellow-500 mt-1 cursor-pointer disabled:cursor-not-allowed"
                    />
                    <div>
                      <div className="font-bold text-white">
                        الدفع عند الاستلام
                      </div>
                      <div className="text-sm text-gray-500">
                        ادفع نقداً عند استلام طلبك
                      </div>
                      {hasPrinting && (
                        <div className="flex items-center gap-1.5 text-xs text-yellow-500 font-bold mt-2 bg-yellow-500/10 w-fit px-2 py-1 rounded-md">
                          <AlertCircle size={14} />
                          غير متاح لوجود منتجات طباعة مخصصة تتطلب الدفع المسبق
                        </div>
                      )}
                    </div>
                  </label>

                  <label
                    className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-colors ${paymentMethod === "online" ? "border-yellow-400 bg-yellow-400/10" : "border-white/[0.06] hover:border-white/[0.08]"}`}
                  >
                    <input
                      type="radio"
                      name="payment"
                      value="online"
                      checked={paymentMethod === "online"}
                      onChange={() => setPaymentMethod("online")}
                      className="w-5 h-5 accent-yellow-500"
                    />
                    <div>
                      <div className="font-bold text-white">
                        دفع إلكتروني
                      </div>
                      <div className="text-sm text-gray-500">
                        بطاقة ائتمان / ميزة / محافظ إلكترونية
                      </div>
                    </div>
                  </label>
                </div>
              </div>
            </form>
          </div>

          <div className="lg:w-96 shrink-0">
            <div className="bg-[#111111] p-6 rounded-3xl shadow-sm shadow-black/30 border border-yellow-500/20 sticky top-24">
              <h2 className="text-xl font-bold mb-6">ملخص الطلب</h2>

              <div className="space-y-4 mb-6 max-h-[300px] overflow-y-auto pr-2">
                {cart.map((item) => (
                  <div key={item.cartItemId} className="flex gap-4">
                    <div className="w-16 h-16 bg-[#222222] rounded-xl overflow-hidden shrink-0">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={item.image}
                        alt={item.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                    <div className="flex-1">
                      <h4 className="font-bold text-sm text-white line-clamp-1">
                        {item.name}
                      </h4>
                      <div className="text-xs text-gray-500">
                        الكمية: {item.quantity}
                      </div>
                      <div className="font-bold text-yellow-400 mt-1">
                        {item.price.toFixed(2)} ج.م
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="border-t border-white/[0.06] pt-4 space-y-3 mb-6 text-sm font-bold">
                <div className="flex justify-between text-gray-500">
                  <span>المجموع الفرعي</span>
                  <span>{subtotal.toFixed(2)} ج.م</span>
                </div>
                <div className="flex justify-between text-gray-500">
                  <span>الشحن</span>
                  <span>{selectedZone ? `${shippingCost.toFixed(2)} ج.م` : 'سيتم تحديده'}</span>
                </div>
                <div className="flex justify-between text-lg text-white pt-3 border-t border-white/[0.06] font-black">
                  <span>الإجمالي</span>
                  <span className="text-yellow-400">
                    {total.toFixed(2)} ج.م
                  </span>
                </div>
              </div>

              {errorMessage && (
                  <div className="mb-4 text-red-500 text-sm font-bold text-center">
                      {errorMessage}
                  </div>
              )}
              <button
                form="checkout-form"
                type="submit"
                disabled={isLoading || isCartSyncing}
                className="w-full bg-yellow-400 text-black font-bold py-4 rounded-full hover:bg-yellow-300 transition-colors shadow-lg shadow-black/40 disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-2"
              >
                {isLoading || isCartSyncing ? <Loader2 className="animate-spin" size={20} /> : null}
                {isCartSyncing ? 'جاري مزامنة السلة...' : isLoading ? 'جاري التأكيد...' : 'تأكيد الطلب'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </PageTransition>
  );
}

``



# Pull Request: Phase 3 (Logical Bugs Fix) 

هذا التحديث يعالج 3 أخطاء برمجية هامة، ويشمل الـ Health Check، وتعديل Order Number، والبوابات المتعددة للدفع.


## File: `backend\routes\api.php`

``php
<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// ==========================================
// Health Check Endpoint
// ==========================================
Route::get('/', function () {
    return response()->json([
        'status' => 'success',
        'message' => 'Apex Store API is running smoothly.',
        'timestamp' => now()
    ], 200);
});

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

## File: `backend\app\Http\Controllers\Api\Storefront\CheckoutController.php`

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
                    'order_number' => $order->order_number,
                    'payment_url' => $paymentUrl
                ]);
            }

            if ($request->payment_method === 'visa') {
                $paymentUrl = 'https://paymob.com/mock-url'; 
                return response()->json([
                    'message' => 'Order created successfully',
                    'order_id' => $order->id,
                    'order_number' => $order->order_number,
                    'payment_url' => $paymentUrl
                ]);
            }

            // For Cash On Delivery
            \App\Jobs\CreateShippingWaybillJob::dispatch($order->id)->afterCommit();
            return response()->json([
                'message' => 'Order created successfully',
                'order_id' => $order->id,
                'order_number' => $order->order_number
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

## File: `storefront\app\checkout\page.tsx`

``php
"use client";

import React, { useState, useEffect } from "react";
import { PageTransition } from "@/components/UI/Animations";
import { useAppContext } from "@/context/AppContext";
import { useRouter } from "next/navigation";
import { CheckCircle2, ArrowRight, Loader2, AlertCircle } from "lucide-react";
import { fetchShippingZones, processCheckout } from "@/lib/api";

export default function CheckoutPage() {
  const { cart, user, isCartSyncing, sessionId, clearCart } = useAppContext();
  const router = useRouter();
  
  const hasPrinting = cart.some(item => item.category === 'printing' || item.isPrinting);
  
  const [successOrderNumber, setSuccessOrderNumber] = useState<string | null>(null);
  const [paymentMethod, setPaymentMethod] = useState(hasPrinting ? "visa" : "cod"); 
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  
  const [shippingZones, setShippingZones] = useState<any[]>([]);
  const [formData, setFormData] = useState({
    customer_name: user?.name || "",
    customer_phone: "",
    shipping_address: "",
    zone_id: ""
  });

  useEffect(() => {
    async function loadZones() {
      const zones = await fetchShippingZones();
      setShippingZones(zones);
    }
    loadZones();
  }, []);

  // Force online payment if there's a printing item
  useEffect(() => {
    if (hasPrinting && paymentMethod === "cod") {
      setPaymentMethod("visa");
    }
  }, [hasPrinting, paymentMethod]);

  const subtotal = cart.reduce((sum, item) => {
    let itemTotal = item.price * item.quantity;
    let addonsTotal = 0;
    if (item.addons) {
      item.addons.forEach(a => {
        if (a.price_multiplier_type === 'per_item') {
          addonsTotal += a.price * item.quantity;
        } else {
          addonsTotal += a.price;
        }
      });
    }
    return sum + itemTotal + addonsTotal;
  }, 0);
  
  const selectedZone = shippingZones.find(z => z.id.toString() === formData.zone_id);
  const shippingCost = selectedZone ? Number(selectedZone.cost) : 0;
  const total = subtotal + shippingCost;

  if (cart.length === 0 && !successOrderNumber) {
    router.push("/shop");
    return null;
  }

  const handleCheckout = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage("");
    
    if (!formData.zone_id) {
        setErrorMessage("الرجاء اختيار المحافظة");
        return;
    }
    
    if (!sessionId) {
        setErrorMessage("خطأ في الجلسة، يرجى تحديث الصفحة");
        return;
    }

    setIsLoading(true);
    try {
      const payload = {
          customer_name: formData.customer_name,
          customer_phone: formData.customer_phone,
          shipping_address: formData.shipping_address,
          zone_id: formData.zone_id,
          payment_method: paymentMethod, // cod, visa, kashier
          success_url: window.location.origin + '/checkout/success',
          failure_url: window.location.origin + '/checkout/error',
      };

      const result = await processCheckout(payload, sessionId);
      
      if ((paymentMethod === 'visa' || paymentMethod === 'kashier') && result.payment_url) {
          window.location.href = result.payment_url;
      } else {
          clearCart(); // ONLY on COD success, online retains cart until webhook/success page resolves
          setSuccessOrderNumber(result.order_number);
      }
    } catch (error: any) {
      setErrorMessage(error.message || "حدث خطأ أثناء الدفع");
    } finally {
      setIsLoading(false);
    }
  };

  if (successOrderNumber) {
    return (
      <PageTransition>
        <div className="max-w-md mx-auto px-4 pt-32 pb-24 text-center">
          <div className="w-24 h-24 bg-green-500/15 text-green-500 rounded-full flex items-center justify-center mx-auto mb-8">
            <CheckCircle2 size={48} />
          </div>
          <h1 className="text-4xl font-black mb-4">تم تأكيد طلبك!</h1>
          <p className="text-gray-500 mb-8 text-lg">
            شكراً لتسوقك معنا. رقم طلبك هو{" "}
            <span className="font-mono font-bold text-white">{successOrderNumber}</span>
            . سيتم التواصل معك قريباً.
          </p>
          <button
            onClick={() => router.push("/")}
            className="bg-yellow-400 text-black font-bold px-8 py-4 rounded-full hover:bg-yellow-300 transition-colors"
          >
            العودة للرئيسية
          </button>
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition>
      <div className="max-w-5xl mx-auto px-4 pt-28 md:pt-32 pb-8 md:pb-12">
        <button
          onClick={() => router.back()}
          className="flex items-center gap-2 text-gray-500 hover:text-white mb-8 font-bold transition-colors w-fit"
        >
          <ArrowRight size={20} /> العودة للسلة
        </button>

        <h1 className="text-3xl font-black mb-8">إتمام الطلب</h1>

        <div className="flex flex-col lg:flex-row gap-8">
          <div className="flex-1">
            <form
              id="checkout-form"
              onSubmit={handleCheckout}
              className="space-y-8"
            >
              <div className="bg-[#111111] p-6 md:p-8 rounded-3xl shadow-sm shadow-black/30 border border-yellow-500/20">
                <h2 className="text-xl font-bold mb-6">بيانات الشحن</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      الاسم
                    </label>
                    <input
                      required
                      value={formData.customer_name}
                      onChange={e => setFormData({...formData, customer_name: e.target.value})}
                      type="text"
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      رقم الهاتف
                    </label>
                    <input
                      required
                      type="tel"
                      value={formData.customer_phone}
                      onChange={e => setFormData({...formData, customer_phone: e.target.value})}
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400"
                      dir="ltr"
                    />
                  </div>
                  <div className="md:col-span-2">
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      العنوان بالتفصيل
                    </label>
                    <textarea
                      required
                      value={formData.shipping_address}
                      onChange={e => setFormData({...formData, shipping_address: e.target.value})}
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400 min-h-[100px]"
                    ></textarea>
                  </div>
                  <div className="md:col-span-2">
                    <label className="block text-sm font-bold text-gray-300 mb-1">
                      المحافظة
                    </label>
                    <select
                      required
                      value={formData.zone_id}
                      onChange={e => setFormData({...formData, zone_id: e.target.value})}
                      className="w-full bg-[#1a1a1a] border border-white/[0.08] rounded-xl px-4 py-3 focus:outline-none focus:border-yellow-400"
                    >
                        <option value="">اختر المحافظة...</option>
                        {shippingZones.map(zone => (
                            <option key={zone.id} value={zone.id}>{zone.name}</option>
                        ))}
                    </select>
                  </div>
                </div>
              </div>

              <div className="bg-[#111111] p-6 md:p-8 rounded-3xl shadow-sm shadow-black/30 border border-yellow-500/20">
                <h2 className="text-xl font-bold mb-6">طريقة الدفع</h2>
                <div className="space-y-4">
                  <label
                    className={`flex items-start gap-4 p-4 rounded-xl border-2 transition-colors ${
                      hasPrinting 
                        ? "opacity-50 cursor-not-allowed border-white/[0.04]" 
                        : paymentMethod === "cod" 
                          ? "border-yellow-400 bg-yellow-400/10 cursor-pointer" 
                          : "border-white/[0.06] hover:border-white/[0.08] cursor-pointer"
                    }`}
                  >
                    <input
                      type="radio"
                      name="payment"
                      value="cod"
                      checked={paymentMethod === "cod"}
                      onChange={() => { if (!hasPrinting) setPaymentMethod("cod"); }}
                      disabled={hasPrinting}
                      className="w-5 h-5 accent-yellow-500 mt-1 cursor-pointer disabled:cursor-not-allowed"
                    />
                    <div>
                      <div className="font-bold text-white">
                        الدفع عند الاستلام
                      </div>
                      <div className="text-sm text-gray-500">
                        ادفع نقداً عند استلام طلبك
                      </div>
                      {hasPrinting && (
                        <div className="flex items-center gap-1.5 text-xs text-yellow-500 font-bold mt-2 bg-yellow-500/10 w-fit px-2 py-1 rounded-md">
                          <AlertCircle size={14} />
                          غير متاح لوجود منتجات طباعة مخصصة تتطلب الدفع المسبق
                        </div>
                      )}
                    </div>
                  </label>

                  <label
                    className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-colors ${paymentMethod === "visa" ? "border-yellow-400 bg-yellow-400/10" : "border-white/[0.06] hover:border-white/[0.08]"}`}
                  >
                    <input
                      type="radio"
                      name="payment"
                      value="visa"
                      checked={paymentMethod === "visa"}
                      onChange={() => setPaymentMethod("visa")}
                      className="w-5 h-5 accent-yellow-500"
                    />
                    <div>
                      <div className="font-bold text-white">
                        بطاقة ائتمان / ميزة
                      </div>
                      <div className="text-sm text-gray-500">
                        دفع إلكتروني آمن عبر Paymob
                      </div>
                    </div>
                  </label>
                  
                  <label
                    className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-colors ${paymentMethod === "kashier" ? "border-yellow-400 bg-yellow-400/10" : "border-white/[0.06] hover:border-white/[0.08]"}`}
                  >
                    <input
                      type="radio"
                      name="payment"
                      value="kashier"
                      checked={paymentMethod === "kashier"}
                      onChange={() => setPaymentMethod("kashier")}
                      className="w-5 h-5 accent-yellow-500"
                    />
                    <div>
                      <div className="font-bold text-white">
                        كاشير (Kashier)
                      </div>
                      <div className="text-sm text-gray-500">
                        دفع إلكتروني عبر بطاقات الائتمان ومحافظ الهاتف
                      </div>
                    </div>
                  </label>
                </div>
              </div>
            </form>
          </div>

          <div className="lg:w-96 shrink-0">
            <div className="bg-[#111111] p-6 rounded-3xl shadow-sm shadow-black/30 border border-yellow-500/20 sticky top-24">
              <h2 className="text-xl font-bold mb-6">ملخص الطلب</h2>

              <div className="space-y-4 mb-6 max-h-[300px] overflow-y-auto pr-2">
                {cart.map((item) => (
                  <div key={item.cartItemId} className="flex gap-4">
                    <div className="w-16 h-16 bg-[#222222] rounded-xl overflow-hidden shrink-0">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={item.image}
                        alt={item.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                    <div className="flex-1">
                      <h4 className="font-bold text-sm text-white line-clamp-1">
                        {item.name}
                      </h4>
                      <div className="text-xs text-gray-500">
                        الكمية: {item.quantity}
                      </div>
                      <div className="font-bold text-yellow-400 mt-1">
                        {item.price.toFixed(2)} ج.م
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="border-t border-white/[0.06] pt-4 space-y-3 mb-6 text-sm font-bold">
                <div className="flex justify-between text-gray-500">
                  <span>المجموع الفرعي</span>
                  <span>{subtotal.toFixed(2)} ج.م</span>
                </div>
                <div className="flex justify-between text-gray-500">
                  <span>الشحن</span>
                  <span>{selectedZone ? `${shippingCost.toFixed(2)} ج.م` : 'سيتم تحديده'}</span>
                </div>
                <div className="flex justify-between text-lg text-white pt-3 border-t border-white/[0.06] font-black">
                  <span>الإجمالي</span>
                  <span className="text-yellow-400">
                    {total.toFixed(2)} ج.م
                  </span>
                </div>
              </div>

              {errorMessage && (
                  <div className="mb-4 text-red-500 text-sm font-bold text-center">
                      {errorMessage}
                  </div>
              )}
              <button
                form="checkout-form"
                type="submit"
                disabled={isLoading || isCartSyncing}
                className="w-full bg-yellow-400 text-black font-bold py-4 rounded-full hover:bg-yellow-300 transition-colors shadow-lg shadow-black/40 disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-2"
              >
                {isLoading || isCartSyncing ? <Loader2 className="animate-spin" size={20} /> : null}
                {isCartSyncing ? 'جاري مزامنة السلة...' : isLoading ? 'جاري التأكيد...' : 'تأكيد الطلب'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </PageTransition>
  );
}

``



## File: `storefront\context\AppContext.tsx`

``tsx
"use client";

import React, { createContext, useContext, useState, useEffect, useRef } from "react";
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SelectedAddon } from "@/types/addons";
import { 
  fetchActiveCart, 
  migrateLegacyCart, 
  addCartItem, 
  updateCartItemQuantity, 
  removeCartItem 
} from "@/lib/cartApi";

type Product = {
  id: string;
  name: string;
  price: number;
  image: string;
  category: string;
  youtubeLink?: string;
  variant_id?: string;
};

export type CartItem = Product & { 
  cartItemId: string; 
  quantity: number;
  addons?: SelectedAddon[];
  isPrinting?: boolean;
};

type AppContextType = {
  cart: CartItem[];
  addToCart: (product: Product, quantity?: number, addons?: SelectedAddon[]) => void;
  removeFromCart: (cartItemId: string) => void;
  updateQuantity: (cartItemId: string, quantity: number) => void;
  isCartOpen: boolean;
  setIsCartOpen: (isOpen: boolean) => void;
  isCartSyncing: boolean;
  sessionId: string;
  clearCart: () => void;

  wishlist: Product[];
  addToWishlist: (product: Product) => void;
  removeFromWishlist: (productId: string) => void;
  isInWishlist: (productId: string) => boolean;

  user: any;
  setUser: (user: any) => void;
  isChatOpen: boolean;
  setIsChatOpen: (isOpen: boolean) => void;
};

const AppContext = createContext<AppContextType | undefined>(undefined);

const queryClient = new QueryClient();

// Fallback UUID generator if crypto.randomUUID is not available
const generateUUID = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
};

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [cart, setCart] = useState<CartItem[]>([]);
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [syncCount, setSyncCount] = useState(0); // [Fix 1] Counter instead of boolean
  const [wishlist, setWishlist] = useState<Product[]>([]);
  const [user, setUser] = useState<any>(null);
  const [isChatOpen, setIsChatOpen] = useState(false);
  
  const [sessionId, setSessionId] = useState<string>('');
  const debounceTimers = useRef<{ [key: string]: NodeJS.Timeout }>({});

  const isCartSyncing = syncCount > 0; // [Fix 1]

  const mapBackendCartItemToFrontend = (item: any): CartItem => {
    if (item.item_type === 'printing') {
      return {
        cartItemId: String(item.id),
        id: String(item.printing_type_id),
        name: item.custom_product_name || item.printingType?.name || 'منتج طباعة',
        price: Number(item.price_at_purchase || 0),
        image: item.printingType?.image_path || '/images/placeholder.png',
        category: 'printing',
        quantity: item.quantity,
        addons: [], 
        isPrinting: true,
      };
    } else {
      const product = item.product || {};
      const variant = item.productVariant || null;
      const price = variant ? (variant.discount_price || variant.price) : (product.discount_price || product.price);
      
      return {
        cartItemId: String(item.id),
        id: String(item.product_id),
        variant_id: variant ? String(variant.id) : undefined,
        name: product.name || 'منتج غير معروف',
        price: Number(price || 0),
        image: product.main_image_path || product.main_image || '',
        category: product.category?.name || 'غير مصنف',
        quantity: item.quantity,
        addons: item.addons?.map((a: any) => ({
          addonId: String(a.product_addon_id),
          groupId: a.productAddon?.group_id || 0,
          name: a.productAddon?.name || a.name,
          groupName: a.productAddon?.group?.name || '',
          price: Number(a.price_at_purchase || a.price || 0),
          price_multiplier_type: a.productAddon?.price_multiplier_type || 'per_item',
          requires_upload: a.productAddon?.requires_upload || false,
          temp_file_id: a.temp_file_id,
          max_quantity: a.productAddon?.max_quantity || Infinity
        })) || []
      };
    }
  };

  // 1. Session & Cart Initialization
  useEffect(() => {
    let currentSessionId = localStorage.getItem("X-Session-ID");
    if (!currentSessionId) {
      currentSessionId = generateUUID();
      localStorage.setItem("X-Session-ID", currentSessionId);
    }
    setSessionId(currentSessionId);

    const savedWishlist = localStorage.getItem("wishlist");
    const savedUser = localStorage.getItem("user");
    if (savedWishlist) setWishlist(JSON.parse(savedWishlist));
    if (savedUser) setUser(JSON.parse(savedUser));

    // Handle Legacy Cart Migration or Fetch Backend Cart
    const initCart = async () => {
      try {
        setSyncCount(prev => prev + 1);
        const legacyCartStr = localStorage.getItem("cart");
        if (legacyCartStr) {
          const legacyItems = JSON.parse(legacyCartStr);
          
          // [Fix 2] Filter out printing items to prevent backend validation crash
          const validLegacyItems = legacyItems.filter((item: any) => 
            item.category !== 'printing' && !item.isPrinting
          );

          if (validLegacyItems && validLegacyItems.length > 0) {
            // Migrate
            const payload = validLegacyItems.map((item: any) => {
              return {
                product_id: item.id,
                variant_id: item.variant_id,
                quantity: item.quantity,
                addons: item.addons?.map((a: any) => ({
                  product_addon_id: a.addonId,
                  temp_file_id: a.temp_file_id
                }))
              };
            });
            const res = await migrateLegacyCart(currentSessionId as string, payload);
            setCart(res.cart?.items?.map(mapBackendCartItemToFrontend) || []);
          } else {
            // Fetch existing server cart if nothing valid to migrate
            const res = await fetchActiveCart(currentSessionId as string);
            setCart(res.cart?.items?.map(mapBackendCartItemToFrontend) || []);
          }
          localStorage.removeItem("cart"); // Clear legacy
        } else {
          // Fetch existing server cart
          const res = await fetchActiveCart(currentSessionId as string);
          setCart(res.cart?.items?.map(mapBackendCartItemToFrontend) || []);
        }
      } catch (error) {
        console.error("Failed to sync cart on load:", error);
      } finally {
        setSyncCount(prev => prev - 1);
      }
    };

    initCart();
  }, []);

  // Sync wishlist & user to localStorage
  useEffect(() => {
    localStorage.setItem("wishlist", JSON.stringify(wishlist));
  }, [wishlist]);

  useEffect(() => {
    if (user) {
      localStorage.setItem("user", JSON.stringify(user));
    } else {
      localStorage.removeItem("user");
    }
  }, [user]);

  // Actions
  const addToCart = async (product: Product, quantity = 1, addons: SelectedAddon[] = []) => {
    if (!sessionId) return;
    
    const addonsHashString = addons.map(a => `${a.addonId}:${a.temp_file_id || 'none'}`).sort().join('|');
    const tempCartItemId = `temp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    const maxCap = addons.reduce((cap, a) => {
      if (a.price_multiplier_type === 'per_item' && typeof a.max_quantity === 'number') {
        return Math.min(cap, a.max_quantity);
      }
      return cap;
    }, Infinity);

    // [Fix 3] Capture previous state for strict optimistic rollback
    const previousCart = [...cart];

    // Optimistic Update
    setCart((prev) => {
      const existingIdx = prev.findIndex(item => 
        item.id === product.id && 
        item.variant_id === product.variant_id &&
        (item.addons || []).map(a => `${a.addonId}:${a.temp_file_id || 'none'}`).sort().join('|') === addonsHashString
      );

      if (existingIdx >= 0) {
        const newCart = [...prev];
        const newQuantity = Math.min(newCart[existingIdx].quantity + quantity, maxCap);
        newCart[existingIdx] = { ...newCart[existingIdx], quantity: newQuantity };
        return newCart;
      }
      return [...prev, { ...product, quantity, cartItemId: tempCartItemId, addons }];
    });
    
    setIsCartOpen(true);
    setSyncCount(prev => prev + 1);

    try {
      // Background Server Call
      await addCartItem(sessionId, {
        product_id: product.id,
        variant_id: product.variant_id,
        quantity,
        addons: addons.map(a => ({ product_addon_id: a.addonId, temp_file_id: a.temp_file_id }))
      });
      
      // Refresh to get real IDs and exact DB state
      const res = await fetchActiveCart(sessionId);
      setCart(res.cart?.items?.map(mapBackendCartItemToFrontend) || []);
    } catch (error) {
      console.error("Failed to add to cart on server:", error);
      // [Fix 3] Strict Optimistic Rollback
      setCart(previousCart);
    } finally {
      setSyncCount(prev => Math.max(0, prev - 1));
    }
  };

  const removeFromCart = async (cartItemId: string) => {
    if (!sessionId) return;

    // [Fix 3] Capture previous state for strict optimistic rollback
    const previousCart = [...cart];

    // Optimistic Update
    setCart((prev) => prev.filter((item) => item.cartItemId !== cartItemId));
    
    // Ignore temporary items that haven't synced
    if (!cartItemId.startsWith('temp-')) {
      setSyncCount(prev => prev + 1);
      try {
        await removeCartItem(sessionId, cartItemId);
        // Refresh silently
        const res = await fetchActiveCart(sessionId);
        setCart(res.cart?.items?.map(mapBackendCartItemToFrontend) || []);
      } catch (error) {
        console.error("Failed to remove item on server:", error);
        // [Fix 3] Strict Optimistic Rollback
        setCart(previousCart);
      } finally {
        setSyncCount(prev => Math.max(0, prev - 1));
      }
    }
  };

  const updateQuantity = (cartItemId: string, quantity: number) => {
    if (quantity <= 0) {
      removeFromCart(cartItemId);
      return;
    }

    // [Fix 3] Capture previous state for strict optimistic rollback
    const previousCart = [...cart];

    // Optimistic Update
    setCart((prev) =>
      prev.map((item) => {
        if (item.cartItemId === cartItemId) {
          let maxCap = Infinity;
          item.addons?.forEach(a => {
            if (a.price_multiplier_type === 'per_item' && typeof a.max_quantity === 'number') {
              maxCap = Math.min(maxCap, a.max_quantity);
            }
          });
          return { ...item, quantity: Math.min(quantity, maxCap) };
        }
        return item;
      })
    );

    if (cartItemId.startsWith('temp-')) return; 

    // Debounce Server Call
    if (debounceTimers.current[cartItemId]) {
      clearTimeout(debounceTimers.current[cartItemId]);
    } else {
      // نرفع العداد مرة واحدة فقط في بداية الـ Debounce
      setSyncCount(prev => prev + 1); 
    }

    debounceTimers.current[cartItemId] = setTimeout(async () => {
      try {
        await updateCartItemQuantity(sessionId, cartItemId, quantity);
        // Silently refresh to ensure data consistency
        const res = await fetchActiveCart(sessionId);
        setCart(res.cart?.items?.map(mapBackendCartItemToFrontend) || []);
      } catch (error) {
        console.error("Failed to update quantity on server:", error);
        // [Fix 3] Strict Optimistic Rollback
        setCart(previousCart);
      } finally {
        setSyncCount(prev => Math.max(0, prev - 1));
        delete debounceTimers.current[cartItemId];
      }
    }, 500);
  };

  const addToWishlist = (product: Product) => {
    setWishlist((prev) => {
      if (prev.find((item) => item.id === product.id)) return prev;
      return [...prev, product];
    });
  };

  const removeFromWishlist = (productId: string) => {
    setWishlist((prev) => prev.filter((item) => item.id !== productId));
  };

  const isInWishlist = (productId: string) => {
    return wishlist.some((item) => item.id === productId);
  };

  const clearCart = () => {
    setCart([]);
    // Since backend clearing would be handled by CheckoutController or Webhook, 
    // we only need to clear the local frontend state here.
  };

  return (
    <QueryClientProvider client={queryClient}>
      <AppContext.Provider
        value={{
          cart,
          addToCart,
          removeFromCart,
          updateQuantity,
          isCartOpen,
          setIsCartOpen,
          isCartSyncing,
          sessionId,
          clearCart,
          wishlist,
          addToWishlist,
          removeFromWishlist,
          isInWishlist,
          user,
          setUser,
          isChatOpen,
          setIsChatOpen,
        }}
      >
        {children}
      </AppContext.Provider>
    </QueryClientProvider>
  );
}

export function useAppContext() {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error("useAppContext must be used within an AppProvider");
  }
  return context;
}

``

