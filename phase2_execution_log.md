# Pull Request: Phase 2 (Frontend Cart Migration) (FINAL)

هذا الملف يحتوي على الأكواد التي تم تحديثها في الفرونت إند لربط السلة بالخادم مع تطبيق تقنيات الـ Optimistic UI والـ Debouncing وإصلاح كافة الثغرات المنطقية (Race Conditions, Optimistic Rollback, Sync Lock State Leak).


## File: `storefront\lib\cartApi.ts`

``tsx
import axios from 'axios';
import { API_URL } from './api';

const createCartApi = (sessionId: string) => {
  return axios.create({
    baseURL: API_URL + '/storefront/cart',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Session-ID': sessionId,
    },
  });
};

export const fetchActiveCart = async (sessionId: string) => {
  const api = createCartApi(sessionId);
  // Using POST /cart as defined in backend routes for getOrCreate
  const response = await api.post('/');
  return response.data;
};

export const migrateLegacyCart = async (sessionId: string, legacyItems: any[]) => {
  const api = createCartApi(sessionId);
  const response = await api.post('/migrate', { items: legacyItems });
  return response.data;
};

export interface AddCartItemPayload {
  product_id: number | string;
  variant_id?: number | string | null;
  quantity: number;
  addons?: { product_addon_id: number | string; temp_file_id?: string | null }[];
}

export const addCartItem = async (sessionId: string, payload: AddCartItemPayload) => {
  const api = createCartApi(sessionId);
  const response = await api.post('/items', payload);
  return response.data;
};

export const updateCartItemQuantity = async (sessionId: string, cartItemId: number | string, quantity: number) => {
  const api = createCartApi(sessionId);
  const response = await api.put(`/items/${cartItemId}`, { quantity });
  return response.data;
};

export const removeCartItem = async (sessionId: string, cartItemId: number | string) => {
  const api = createCartApi(sessionId);
  const response = await api.delete(`/items/${cartItemId}`);
  return response.data;
};

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

