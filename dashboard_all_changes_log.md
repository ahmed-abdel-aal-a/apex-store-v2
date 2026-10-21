# سجل التعديلات الشامل (Full Code Dump) - Dashboard Next.js (محدث بعد الـ Hotfixes)

هذا الملف يحتوي على الكود الكامل لجميع الملفات التي تم إنشاؤها أو تعديلها بالكامل دون أي اختصار، تلبية لطلب الدقة 100%:

## الملف: dashboard/app/addons/types.ts
`	ypescript
export interface AddonGroup {
  id: string;
  name: {
    en: string;
    ar: string;
  };
  description: {
    en: string;
    ar: string;
  } | null;
  input_type: 'checkbox' | 'radio';
  is_required: boolean;
  price_multiplier_type: 'per_item' | 'per_order_line';
  is_active: boolean;
  sort_order: number;
  addons?: ProductAddon[];
}

export interface ProductAddon {
  id: string;
  addon_group_id: string;
  name: {
    en: string;
    ar: string;
  };
  description: {
    en: string;
    ar: string;
  } | null;
  type: 'simple' | 'printing_linked';
  price: number;
  price_type: 'fixed' | 'percentage';
  printing_type_id: string | null;
  requires_upload: boolean;
  track_inventory: boolean;
  quantity: number;
  is_active: boolean;
  sort_order: number;
}

`

## الملف: dashboard/lib/services/addons.ts
`	ypescript
import { fetcher, apiClient } from "../api";
import { AddonGroup, ProductAddon } from "@/app/addons/types";

export const addonsApi = {
  // ==========================================
  // Addon Groups
  // ==========================================
  getAddonGroups: async (): Promise<AddonGroup[]> => {
    return fetcher("/v1/admin/addon-groups");
  },

  createAddonGroup: async (data: any): Promise<AddonGroup> => {
    return apiClient("/v1/admin/addon-groups", {
      method: "POST",
      body: data,
    });
  },

  updateAddonGroup: async (id: string, data: any): Promise<AddonGroup> => {
    return apiClient(`/v1/admin/addon-groups/${id}`, {
      method: "PUT",
      body: data,
    });
  },

  deleteAddonGroup: async (id: string): Promise<void> => {
    return apiClient(`/v1/admin/addon-groups/${id}`, {
      method: "DELETE",
    });
  },

  // ==========================================
  // Product Addons
  // ==========================================
  getProductAddons: async (groupId: string): Promise<ProductAddon[]> => {
    return fetcher(`/v1/admin/addon-groups/${groupId}/addons`);
  },

  createProductAddon: async (groupId: string, data: any): Promise<ProductAddon> => {
    return apiClient(`/v1/admin/addon-groups/${groupId}/addons`, {
      method: "POST",
      body: data,
    });
  },

  updateProductAddon: async (groupId: string, addonId: string, data: any): Promise<ProductAddon> => {
    return apiClient(`/v1/admin/addon-groups/${groupId}/addons/${addonId}`, {
      method: "PUT",
      body: data,
    });
  },

  deleteProductAddon: async (groupId: string, addonId: string): Promise<void> => {
    return apiClient(`/v1/admin/addon-groups/${groupId}/addons/${addonId}`, {
      method: "DELETE",
    });
  },
};

`

## الملف: dashboard/app/addons/schema.ts
`	ypescript
import * as z from "zod";

export const addonGroupSchema = z.object({
  name: z.object({
    ar: z.string().min(2, "الاسم بالعربية مطلوب (حرفين على الأقل)"),
    en: z.string().min(2, "الاسم بالإنجليزية مطلوب (حرفين على الأقل)"),
  }),
  description: z.object({
    ar: z.string().optional().nullable(),
    en: z.string().optional().nullable(),
  }).optional(),
  input_type: z.enum(["checkbox", "radio"]),
  is_required: z.boolean().default(false),
  price_multiplier_type: z.enum(["per_item", "per_order_line"]),
  is_active: z.boolean().default(true),
  sort_order: z.number().int().default(0),
});

export type AddonGroupFormValues = z.infer<typeof addonGroupSchema>;

export const productAddonSchema = z.object({
  name: z.object({
    ar: z.string().min(2, "الاسم بالعربية مطلوب (حرفين على الأقل)"),
    en: z.string().min(2, "الاسم بالإنجليزية مطلوب (حرفين على الأقل)"),
  }),
  description: z.object({
    ar: z.string().optional().nullable(),
    en: z.string().optional().nullable(),
  }).optional(),
  type: z.enum(["simple", "printing_linked"]),
  price: z.coerce.number().min(0, "السعر يجب أن يكون رقماً إيجابياً"),
  price_type: z.enum(["fixed", "percentage"]),
  printing_type_id: z.string().optional().nullable(),
  requires_upload: z.boolean().default(false),
  track_inventory: z.boolean().default(false),
  quantity: z.coerce.number().int().min(0).default(0),
  is_active: z.boolean().default(true),
  sort_order: z.coerce.number().int().default(0),
}).superRefine((data, ctx) => {
  if (data.type === 'printing_linked' && !data.printing_type_id) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "يجب اختيار نوع الطباعة",
      path: ["printing_type_id"],
    });
  }
  
  if (data.price_type === 'percentage' && data.price > 100) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "النسبة المئوية لا يمكن أن تتجاوز 100%",
      path: ["price"],
    });
  }
});

export type ProductAddonFormValues = z.infer<typeof productAddonSchema>;

`

## الملف: dashboard/app/addons/_components/AddonGroupFormModal.tsx
`	ypescript
"use client";

import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { AddonGroupFormValues, addonGroupSchema } from "../schema";
import { AddonGroup } from "../types";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2 } from "lucide-react";

interface AddonGroupFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: AddonGroupFormValues) => void;
  isSubmitting: boolean;
  initialData?: AddonGroup | null;
}

export default function AddonGroupFormModal({
  isOpen,
  onClose,
  onSubmit,
  isSubmitting,
  initialData,
}: AddonGroupFormModalProps) {
  const form = useForm<AddonGroupFormValues>({
    resolver: zodResolver(addonGroupSchema),
    defaultValues: {
      name: { ar: "", en: "" },
      description: { ar: "", en: "" },
      input_type: "checkbox",
      is_required: false,
      price_multiplier_type: "per_item",
      is_active: true,
      sort_order: 0,
    },
  });

  useEffect(() => {
    if (isOpen) {
      if (initialData) {
        form.reset({
          name: initialData.name,
          description: initialData.description || { ar: "", en: "" },
          input_type: initialData.input_type,
          is_required: initialData.is_required,
          price_multiplier_type: initialData.price_multiplier_type,
          is_active: initialData.is_active,
          sort_order: initialData.sort_order,
        });
      } else {
        form.reset({
          name: { ar: "", en: "" },
          description: { ar: "", en: "" },
          input_type: "checkbox",
          is_required: false,
          price_multiplier_type: "per_item",
          is_active: true,
          sort_order: 0,
        });
      }
    }
  }, [isOpen, initialData, form]);

  const handleSubmit = (data: AddonGroupFormValues) => {
    onSubmit(data);
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent dir="rtl" className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{initialData ? "تعديل مجموعة الخدمات" : "إضافة مجموعة خدمات جديدة"}</DialogTitle>
        </DialogHeader>

        <form id="addon-group-form" onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6 py-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>الاسم (عربي) *</Label>
              <Input {...form.register("name.ar")} placeholder="مثال: التغليف" />
              {form.formState.errors.name?.ar && (
                <p className="text-red-500 text-sm">{form.formState.errors.name.ar.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label>الاسم (إنجليزي) *</Label>
              <Input {...form.register("name.en")} placeholder="e.g. Packaging" dir="ltr" />
              {form.formState.errors.name?.en && (
                <p className="text-red-500 text-sm">{form.formState.errors.name.en.message}</p>
              )}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>الوصف (عربي) اختياري</Label>
              <Input {...form.register("description.ar")} placeholder="وصف توضيحي للعميل..." />
            </div>
            <div className="space-y-2">
              <Label>الوصف (إنجليزي) اختياري</Label>
              <Input {...form.register("description.en")} placeholder="Description for customer..." dir="ltr" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>نوع الإدخال *</Label>
              <Select
                value={form.watch("input_type")}
                onValueChange={(v) => form.setValue("input_type", v as any)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="اختر نوع الإدخال" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="checkbox">متعدد (Checkbox)</SelectItem>
                  <SelectItem value="radio">اختيار واحد (Radio)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>طريقة التسعير *</Label>
              <Select
                value={form.watch("price_multiplier_type")}
                onValueChange={(v) => form.setValue("price_multiplier_type", v as any)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="اختر طريقة التسعير" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="per_item">لكل قطعة (مضروب في الكمية)</SelectItem>
                  <SelectItem value="per_order_line">لكل طلب (سعر ثابت مرة واحدة)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="flex items-center justify-between p-4 border rounded-xl bg-slate-50">
            <div>
              <Label className="text-base font-bold text-slate-800">إجباري؟</Label>
              <p className="text-sm text-slate-500">هل يجب على العميل اختيار خدمة من هذه المجموعة؟</p>
            </div>
            <Switch
              checked={form.watch("is_required")}
              onCheckedChange={(v) => form.setValue("is_required", v)}
            />
          </div>

          <div className="flex items-center justify-between p-4 border rounded-xl bg-slate-50">
            <div>
              <Label className="text-base font-bold text-slate-800">مفعل؟</Label>
              <p className="text-sm text-slate-500">هل هذه المجموعة ظاهرة للعملاء؟</p>
            </div>
            <Switch
              checked={form.watch("is_active")}
              onCheckedChange={(v) => form.setValue("is_active", v)}
            />
          </div>
          
          <div className="space-y-2 max-w-xs">
            <Label>ترتيب العرض (Sort Order)</Label>
            <Input type="number" {...form.register("sort_order", { valueAsNumber: true })} />
          </div>
        </form>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={onClose} disabled={isSubmitting}>
            إلغاء
          </Button>
          <Button type="submit" form="addon-group-form" className="bg-indigo-600 hover:bg-indigo-700" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            حفظ
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

`

## الملف: dashboard/app/addons/_components/ProductAddonFormModal.tsx
`	ypescript
"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { ProductAddonFormValues, productAddonSchema } from "../schema";
import { ProductAddon } from "../types";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2 } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { fetcher } from "@/lib/api";

interface ProductAddonFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: ProductAddonFormValues) => void;
  isSubmitting: boolean;
  initialData?: ProductAddon | null;
}

export default function ProductAddonFormModal({
  isOpen,
  onClose,
  onSubmit,
  isSubmitting,
  initialData,
}: ProductAddonFormModalProps) {
  const form = useForm<ProductAddonFormValues>({
    resolver: zodResolver(productAddonSchema),
    defaultValues: {
      name: { ar: "", en: "" },
      description: { ar: "", en: "" },
      type: "simple",
      price: 0,
      price_type: "fixed",
      printing_type_id: null,
      requires_upload: false,
      track_inventory: false,
      quantity: 0,
      is_active: true,
      sort_order: 0,
    },
  });

  const { data: printingTypes = [] } = useQuery({
    queryKey: ["printingTypes"],
    queryFn: () => fetcher("/v1/admin/printing-types"),
    enabled: isOpen,
  });

  useEffect(() => {
    if (isOpen) {
      if (initialData) {
        form.reset({
          name: initialData.name,
          description: initialData.description || { ar: "", en: "" },
          type: initialData.type,
          price: initialData.price,
          price_type: initialData.price_type,
          printing_type_id: initialData.printing_type_id ? initialData.printing_type_id.toString() : null,
          requires_upload: initialData.requires_upload,
          track_inventory: initialData.track_inventory,
          quantity: initialData.quantity,
          is_active: initialData.is_active,
          sort_order: initialData.sort_order,
        });
      } else {
        form.reset({
          name: { ar: "", en: "" },
          description: { ar: "", en: "" },
          type: "simple",
          price: 0,
          price_type: "fixed",
          printing_type_id: null,
          requires_upload: false,
          track_inventory: false,
          quantity: 0,
          is_active: true,
          sort_order: 0,
        });
      }
    }
  }, [isOpen, initialData, form]);

  const handleSubmit = (data: ProductAddonFormValues) => {
    onSubmit(data);
  };

  const typeWatch = form.watch("type");
  const trackInventoryWatch = form.watch("track_inventory");
  const priceTypeWatch = form.watch("price_type");

  useEffect(() => {
    if (typeWatch === "simple") {
      form.setValue("printing_type_id", null);
    }
  }, [typeWatch, form]);

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent dir="rtl" className="max-w-3xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{initialData ? "تعديل الخدمة" : "إضافة خدمة جديدة"}</DialogTitle>
        </DialogHeader>

        <form id="product-addon-form" onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6 py-4">
          
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>الاسم (عربي) *</Label>
              <Input {...form.register("name.ar")} placeholder="مثال: تغليف فاخر" />
              {form.formState.errors.name?.ar && (
                <p className="text-red-500 text-sm">{form.formState.errors.name.ar.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label>الاسم (إنجليزي) *</Label>
              <Input {...form.register("name.en")} placeholder="e.g. Premium Packaging" dir="ltr" />
              {form.formState.errors.name?.en && (
                <p className="text-red-500 text-sm">{form.formState.errors.name.en.message}</p>
              )}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>الوصف (عربي) اختياري</Label>
              <Input {...form.register("description.ar")} placeholder="وصف للعميل..." />
            </div>
            <div className="space-y-2">
              <Label>الوصف (إنجليزي) اختياري</Label>
              <Input {...form.register("description.en")} placeholder="Description..." dir="ltr" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 bg-slate-50 p-4 rounded-xl border border-slate-100">
            <div className="space-y-2">
              <Label>طريقة التسعير *</Label>
              <Select
                value={priceTypeWatch}
                onValueChange={(v) => form.setValue("price_type", v as "fixed" | "percentage")}
              >
                <SelectTrigger>
                  <SelectValue placeholder="اختر طريقة التسعير" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="fixed">مبلغ ثابت (ج.م)</SelectItem>
                  <SelectItem value="percentage">نسبة مئوية من سعر المنتج (%)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>السعر / النسبة *</Label>
              <Input 
                type="number" 
                step="0.01"
                {...form.register("price", { valueAsNumber: true })} 
                placeholder={priceTypeWatch === 'percentage' ? 'مثال: 10' : 'مثال: 150'}
              />
              {form.formState.errors.price && (
                <p className="text-red-500 text-sm">{form.formState.errors.price.message}</p>
              )}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>نوع الخدمة *</Label>
              <Select
                value={typeWatch}
                onValueChange={(v) => form.setValue("type", v as "simple" | "printing_linked")}
              >
                <SelectTrigger>
                  <SelectValue placeholder="اختر النوع" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="simple">خدمة عادية (تغليف، كارت إهداء...)</SelectItem>
                  <SelectItem value="printing_linked">خدمة مرتبطة بالطباعة</SelectItem>
                </SelectContent>
              </Select>
            </div>
            
            {typeWatch === "printing_linked" && (
              <div className="space-y-2">
                <Label>نوع الطباعة المرتبط *</Label>
                <Select
                  value={form.watch("printing_type_id") || ""}
                  onValueChange={(v) => form.setValue("printing_type_id", v)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="اختر نوع الطباعة" />
                  </SelectTrigger>
                  <SelectContent>
                    {printingTypes.map((pt: any) => (
                      <SelectItem key={pt.id} value={pt.id.toString()}>{pt.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {form.formState.errors.printing_type_id && (
                  <p className="text-red-500 text-sm">{form.formState.errors.printing_type_id.message}</p>
                )}
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="flex items-center justify-between p-4 border rounded-xl bg-slate-50">
              <div>
                <Label className="text-base font-bold text-slate-800">تتبع المخزون</Label>
                <p className="text-sm text-slate-500">هل لهذه الخدمة كمية محدودة؟</p>
              </div>
              <Switch
                checked={trackInventoryWatch}
                onCheckedChange={(v) => form.setValue("track_inventory", v)}
              />
            </div>
            
            {trackInventoryWatch && (
              <div className="space-y-2 flex flex-col justify-center">
                <Label>الكمية المتاحة بالمخزن *</Label>
                <Input 
                  type="number" 
                  {...form.register("quantity", { valueAsNumber: true })} 
                />
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
             <div className="flex items-center justify-between p-4 border rounded-xl bg-slate-50">
              <div>
                <Label className="text-base font-bold text-slate-800">رفع ملفات؟</Label>
                <p className="text-sm text-slate-500">هل تتطلب هذه الخدمة من العميل رفع ملف/تصميم؟</p>
              </div>
              <Switch
                checked={form.watch("requires_upload")}
                onCheckedChange={(v) => form.setValue("requires_upload", v)}
              />
            </div>
            <div className="flex items-center justify-between p-4 border rounded-xl bg-slate-50">
              <div>
                <Label className="text-base font-bold text-slate-800">مفعلة؟</Label>
                <p className="text-sm text-slate-500">هل هذه الخدمة ظاهرة للعملاء؟</p>
              </div>
              <Switch
                checked={form.watch("is_active")}
                onCheckedChange={(v) => form.setValue("is_active", v)}
              />
            </div>
          </div>
          
          <div className="space-y-2 max-w-xs">
            <Label>ترتيب العرض (Sort Order)</Label>
            <Input type="number" {...form.register("sort_order", { valueAsNumber: true })} />
          </div>
        </form>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={onClose} disabled={isSubmitting}>
            إلغاء
          </Button>
          <Button type="submit" form="product-addon-form" className="bg-indigo-600 hover:bg-indigo-700" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            حفظ الخدمة
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

`

## الملف: dashboard/app/addons/page.tsx
`	ypescript
"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { addonsApi } from "@/lib/services/addons";
import { AddonGroup, ProductAddon } from "./types";
import { AddonGroupFormValues, ProductAddonFormValues } from "./schema";
import toast from "react-hot-toast";

import { Button } from "@/components/ui/button";
import { Plus, Loader2, Edit2, Trash2, Layers, CheckCircle2, XCircle } from "lucide-react";
import AddonGroupFormModal from "./_components/AddonGroupFormModal";
import ProductAddonFormModal from "./_components/ProductAddonFormModal";

export default function AddonsManagementPage() {
  const queryClient = useQueryClient();

  const [selectedGroup, setSelectedGroup] = useState<AddonGroup | null>(null);
  
  // Modal States
  const [isGroupModalOpen, setIsGroupModalOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<AddonGroup | null>(null);
  
  const [isAddonModalOpen, setIsAddonModalOpen] = useState(false);
  const [editingAddon, setEditingAddon] = useState<ProductAddon | null>(null);

  // Queries
  const { data: groups = [], isLoading: isLoadingGroups } = useQuery({
    queryKey: ["addonGroups"],
    queryFn: addonsApi.getAddonGroups,
  });

  const { data: addons = [], isLoading: isLoadingAddons } = useQuery({
    queryKey: ["productAddons", selectedGroup?.id],
    queryFn: () => addonsApi.getProductAddons(selectedGroup!.id),
    enabled: !!selectedGroup,
  });

  // Group Mutations
  const createGroupMutation = useMutation({
    mutationFn: (data: AddonGroupFormValues) => addonsApi.createAddonGroup(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["addonGroups"] });
      toast.success("تم إضافة مجموعة الخدمات بنجاح");
      setIsGroupModalOpen(false);
    },
    onError: () => toast.error("حدث خطأ أثناء الإضافة"),
  });

  const updateGroupMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: AddonGroupFormValues }) => addonsApi.updateAddonGroup(id, data),
    onSuccess: (updatedGroup) => {
      queryClient.invalidateQueries({ queryKey: ["addonGroups"] });
      if (selectedGroup?.id?.toString() === updatedGroup.id?.toString()) setSelectedGroup(updatedGroup);
      toast.success("تم التحديث بنجاح");
      setIsGroupModalOpen(false);
    },
    onError: () => toast.error("حدث خطأ أثناء التحديث"),
  });

  const deleteGroupMutation = useMutation({
    mutationFn: (id: string) => addonsApi.deleteAddonGroup(id),
    onSuccess: (_, deletedId) => {
      queryClient.invalidateQueries({ queryKey: ["addonGroups"] });
      if (selectedGroup?.id?.toString() === deletedId?.toString()) setSelectedGroup(null);
      toast.success("تم الحذف بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء الحذف"),
  });

  // Addon Mutations
  const createAddonMutation = useMutation({
    mutationFn: (data: ProductAddonFormValues) => addonsApi.createProductAddon(selectedGroup!.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["productAddons", selectedGroup?.id] });
      toast.success("تم إضافة الخدمة بنجاح");
      setIsAddonModalOpen(false);
    },
    onError: () => toast.error("حدث خطأ أثناء الإضافة"),
  });

  const updateAddonMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: ProductAddonFormValues }) => addonsApi.updateProductAddon(selectedGroup!.id, id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["productAddons", selectedGroup?.id] });
      toast.success("تم التحديث بنجاح");
      setIsAddonModalOpen(false);
    },
    onError: () => toast.error("حدث خطأ أثناء التحديث"),
  });

  const deleteAddonMutation = useMutation({
    mutationFn: (id: string) => addonsApi.deleteProductAddon(selectedGroup!.id, id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["productAddons", selectedGroup?.id] });
      toast.success("تم الحذف بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء الحذف"),
  });

  // Handlers
  const handleGroupSubmit = (data: AddonGroupFormValues) => {
    if (editingGroup) {
      updateGroupMutation.mutate({ id: editingGroup.id, data });
    } else {
      createGroupMutation.mutate(data);
    }
  };

  const handleAddonSubmit = (data: ProductAddonFormValues) => {
    if (editingAddon) {
      updateAddonMutation.mutate({ id: editingAddon.id, data });
    } else {
      createAddonMutation.mutate(data);
    }
  };

  const confirmDeleteGroup = (id: string) => {
    if (confirm("هل أنت متأكد من حذف هذه المجموعة بالكامل بجميع خدماتها؟")) {
      deleteGroupMutation.mutate(id);
    }
  };

  const confirmDeleteAddon = (id: string) => {
    if (confirm("هل أنت متأكد من حذف هذه الخدمة؟")) {
      deleteAddonMutation.mutate(id);
    }
  };

  return (
    <div className="space-y-8" dir="rtl">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 tracking-tight">إدارة الخدمات الإضافية</h1>
          <p className="text-slate-500 mt-1 text-sm">أنشئ مجموعات لخيارات الإضافة (مثل التغليف، الهدايا) واربطها بالمنتجات.</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        {/* Groups Column */}
        <div className="lg:col-span-4 flex flex-col space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold text-slate-700">مجموعات الخدمات</h2>
            <Button 
              size="sm" 
              onClick={() => { setEditingGroup(null); setIsGroupModalOpen(true); }}
              className="bg-indigo-600 hover:bg-indigo-700 h-9"
            >
              <Plus className="w-4 h-4 mr-1" /> مجموعة جديدة
            </Button>
          </div>

          <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden flex-1 min-h-[400px]">
            {isLoadingGroups ? (
              <div className="p-8 flex justify-center"><Loader2 className="w-6 h-6 animate-spin text-indigo-600" /></div>
            ) : groups.length === 0 ? (
              <div className="p-8 text-center text-slate-500">لا توجد مجموعات خدمات حتى الآن.</div>
            ) : (
              <div className="divide-y divide-slate-100">
                {groups.map((group) => (
                  <div 
                    key={group.id} 
                    className={`p-4 flex items-center justify-between cursor-pointer transition-colors ${selectedGroup?.id === group.id ? 'bg-indigo-50/80 border-r-4 border-indigo-600' : 'hover:bg-slate-50 border-r-4 border-transparent'}`}
                    onClick={() => setSelectedGroup(group)}
                  >
                    <div>
                      <h3 className="font-bold text-slate-800">{group.name?.ar}</h3>
                      <p className="text-xs text-slate-500 mt-1">
                        {group.input_type === 'checkbox' ? 'متعدد الاختيار' : 'اختيار واحد'} • {group.is_required ? 'إجباري' : 'اختياري'}
                      </p>
                    </div>
                    <div className="flex items-center gap-1">
                      <Button variant="ghost" size="icon" className="h-8 w-8 text-slate-400 hover:text-indigo-600" onClick={(e) => { e.stopPropagation(); setEditingGroup(group); setIsGroupModalOpen(true); }}>
                        <Edit2 className="w-4 h-4" />
                      </Button>
                      <Button variant="ghost" size="icon" className="h-8 w-8 text-slate-400 hover:text-red-600 hover:bg-red-50" onClick={(e) => { e.stopPropagation(); confirmDeleteGroup(group.id.toString()); }}>
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Addons Column */}
        <div className="lg:col-span-8 flex flex-col space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold text-slate-700">
              الخدمات التابعة: {selectedGroup ? <span className="text-indigo-600">{selectedGroup.name?.ar}</span> : <span className="text-slate-400 font-normal">اختر مجموعة</span>}
            </h2>
            {selectedGroup && (
              <Button 
                size="sm" 
                onClick={() => { setEditingAddon(null); setIsAddonModalOpen(true); }}
                className="bg-indigo-600 hover:bg-indigo-700 h-9"
              >
                <Plus className="w-4 h-4 mr-1" /> إضافة خدمة
              </Button>
            )}
          </div>

          <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden flex-1 min-h-[400px]">
            {!selectedGroup ? (
              <div className="h-full flex flex-col items-center justify-center p-12 text-center text-slate-400">
                <Layers className="w-12 h-12 mb-4 opacity-20" />
                <p>يرجى اختيار مجموعة خدمات من القائمة لعرض وإدارة الخدمات بداخلها.</p>
              </div>
            ) : isLoadingAddons ? (
              <div className="p-12 flex justify-center"><Loader2 className="w-8 h-8 animate-spin text-indigo-600" /></div>
            ) : addons.length === 0 ? (
              <div className="p-12 text-center text-slate-500">لا توجد خدمات داخل هذه المجموعة حالياً. أضف الخدمة الأولى.</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-right text-sm">
                  <thead className="bg-slate-50/80 text-slate-600 font-medium border-b border-slate-100">
                    <tr>
                      <th className="py-3 px-4">الخدمة</th>
                      <th className="py-3 px-4">السعر</th>
                      <th className="py-3 px-4">النوع</th>
                      <th className="py-3 px-4">الحالة</th>
                      <th className="py-3 px-4 w-24">إجراءات</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-50">
                    {addons.map((addon) => (
                      <tr key={addon.id} className="hover:bg-slate-50/50 transition-colors">
                        <td className="py-3 px-4">
                          <p className="font-bold text-slate-800">{addon.name?.ar}</p>
                          {addon.description?.ar && <p className="text-xs text-slate-500 mt-0.5 truncate max-w-xs">{addon.description.ar}</p>}
                        </td>
                        <td className="py-3 px-4">
                          <span className="font-bold text-slate-700">
                            {addon.price_type === 'percentage' ? `${addon.price}%` : `${addon.price} ج.م`}
                          </span>
                        </td>
                        <td className="py-3 px-4">
                          <span className={`px-2 py-1 rounded-md text-xs font-bold ${addon.type === 'printing_linked' ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-700'}`}>
                            {addon.type === 'printing_linked' ? 'طباعة' : 'عادية'}
                          </span>
                        </td>
                        <td className="py-3 px-4">
                           {addon.is_active ? <CheckCircle2 className="w-5 h-5 text-emerald-500" /> : <XCircle className="w-5 h-5 text-slate-300" />}
                        </td>
                        <td className="py-3 px-4 flex items-center gap-1">
                           <Button variant="ghost" size="icon" className="h-8 w-8 text-slate-400 hover:text-indigo-600" onClick={() => { setEditingAddon(addon); setIsAddonModalOpen(true); }}>
                            <Edit2 className="w-4 h-4" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8 text-slate-400 hover:text-red-600 hover:bg-red-50" onClick={() => confirmDeleteAddon(addon.id.toString())}>
                            <Trash2 className="w-4 h-4" />
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>

      </div>

      <AddonGroupFormModal 
        isOpen={isGroupModalOpen}
        onClose={() => setIsGroupModalOpen(false)}
        onSubmit={handleGroupSubmit}
        isSubmitting={createGroupMutation.isPending || updateGroupMutation.isPending}
        initialData={editingGroup}
      />

      <ProductAddonFormModal
        isOpen={isAddonModalOpen}
        onClose={() => setIsAddonModalOpen(false)}
        onSubmit={handleAddonSubmit}
        isSubmitting={createAddonMutation.isPending || updateAddonMutation.isPending}
        initialData={editingAddon}
      />
    </div>
  );
}

`

## الملف: dashboard/app/products/_components/AddonsTab.tsx
`	ypescript
"use client";

import { useQuery } from "@tanstack/react-query";
import { UseFormReturn } from "react-hook-form";
import { ProductFormValues } from "../schema";
import { addonsApi } from "@/lib/services/addons";
import { Label } from "@/components/ui/label";
import { Loader2, Layers } from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";

interface AddonsTabProps {
  form: UseFormReturn<ProductFormValues>;
}

export function AddonsTab({ form }: AddonsTabProps) {
  const { data: groups = [], isLoading } = useQuery({
    queryKey: ["addonGroups"],
    queryFn: addonsApi.getAddonGroups,
  });

  const selectedGroupIds = form.watch("addonGroupIds") || [];

  const handleToggle = (id: number) => {
    const isSelected = selectedGroupIds.includes(id);
    if (isSelected) {
      form.setValue(
        "addonGroupIds",
        selectedGroupIds.filter((groupId) => groupId !== id)
      );
    } else {
      form.setValue("addonGroupIds", [...selectedGroupIds, id]);
    }
  };

  return (
    <div className="space-y-8">
      <div className="bg-slate-50/50 p-6 rounded-3xl border border-slate-100">
        <div className="mb-6">
          <h2 className="text-xl font-bold text-slate-800 flex items-center gap-2">
            <Layers className="w-5 h-5 text-indigo-500" />
            مجموعات الخدمات الإضافية
          </h2>
          <p className="text-sm text-slate-500 mt-1">
            اختر مجموعات الخدمات التي تود إتاحتها مع هذا المنتج (مثل: التغليف، الكروت، إضافات الطباعة).
          </p>
        </div>

        {isLoading ? (
          <div className="flex justify-center p-12">
            <Loader2 className="w-8 h-8 animate-spin text-indigo-600" />
          </div>
        ) : groups.length === 0 ? (
          <div className="text-center p-8 border-2 border-dashed border-slate-200 rounded-2xl">
            <p className="text-slate-500 font-medium">لا توجد مجموعات خدمات متاحة حالياً.</p>
            <p className="text-sm text-slate-400 mt-1">قم بإضافة المجموعات من قسم "الخدمات الإضافية".</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {groups.map((group) => {
              // Convert group id to number if it isn't already to match our schema
              const groupIdNum = typeof group.id === 'string' ? parseInt(group.id, 10) : group.id;
              const isSelected = selectedGroupIds.includes(groupIdNum);

              return (
                <div
                  key={group.id}
                  className={`flex flex-col p-4 rounded-xl border transition-all cursor-pointer select-none ${
                    isSelected
                      ? "border-indigo-600 bg-indigo-50/50 shadow-sm"
                      : "border-slate-200 bg-white hover:border-indigo-300"
                  }`}
                  onClick={() => handleToggle(groupIdNum)}
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <Label className="font-bold text-slate-800 cursor-pointer text-base">
                        {group.name?.ar}
                      </Label>
                      <p className="text-xs text-slate-500 mt-1 line-clamp-1">
                        {group.description?.ar || "لا يوجد وصف"}
                      </p>
                    </div>
                    <Checkbox
                      checked={isSelected}
                      onCheckedChange={() => handleToggle(groupIdNum)}
                      className="data-[state=checked]:bg-indigo-600 data-[state=checked]:border-indigo-600 mt-1"
                    />
                  </div>
                  <div className="mt-4 flex flex-wrap gap-2">
                    <span className="px-2 py-1 bg-white rounded-md text-[10px] font-bold text-slate-500 border border-slate-100">
                      {group.input_type === "checkbox" ? "متعدد" : "مفرد"}
                    </span>
                    <span className="px-2 py-1 bg-white rounded-md text-[10px] font-bold text-slate-500 border border-slate-100">
                      {group.is_required ? "إجباري" : "اختياري"}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

`

## الملف: dashboard/app/products/schema.ts
`	ypescript
import * as z from "zod";

const optionalNumber = z.preprocess((val): unknown => {
  if (val === "" || val === undefined || val === null) return undefined;
  const num = Number(val);
  return isNaN(num) ? val : num;
}, z.number({ message: "يجب إدخال رقم صحيح" }).min(0, "القيمة يجب أن تكون 0 أو أكثر").optional());

const requiredPrice = z.preprocess((val): unknown => {
  if (val === "" || val === undefined || val === null) return undefined;
  const num = Number(val);
  return isNaN(num) ? val : num;
}, z.number({ message: "السعر مطلوب ويجب إدخال رقم صحيح" }).min(0, "السعر يجب أن يكون 0 أو أكثر"));

export const productSchema = z.object({
  name: z.string().min(1, "اسم المنتج مطلوب"),
  description: z.string().optional(),
  categoryId: z.string().min(1, "التصنيف مطلوب"),
  type: z.enum(["simple", "variable"]),
  price: requiredPrice,
  discountPrice: optionalNumber,
  sku: z.string().optional(),
  barcode: z.string().optional(),
  trackInventory: z.boolean(),
  quantity: optionalNumber,
  weight: optionalNumber,
  seoTitle: z.string().optional(),
  seoDescription: z.string().optional(),
  images: z.array(z.string()).optional(),
  addonGroupIds: z.array(z.coerce.number()).optional(),
  variants: z
    .array(
      z.object({
        id: z.string(),
        name: z.string().optional(),
        attributes: z.array(
          z.object({
            name: z.string(),
            value: z.string(),
          })
        ).optional(),
        price: requiredPrice,
        discountPrice: optionalNumber,
        sku: z.string().optional(),
        trackInventory: z.boolean().optional(),
        quantity: optionalNumber,
      })
    )
    .optional(),
}).superRefine((data, ctx) => {
  if (data.discountPrice !== undefined && data.discountPrice >= data.price) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "سعر الخصم يجب أن يكون أقل من السعر الأساسي",
      path: ["discountPrice"],
    });
  }
  
  if (data.type === "variable" && (!data.variants || data.variants.length === 0)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "يجب إضافة متغير واحد على الأقل للمنتج المتغير",
      path: ["variants"],
    });
  }

  if (data.trackInventory && data.quantity === undefined) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "الكمية مطلوبة عند تفعيل تتبع المخزون",
      path: ["quantity"],
    });
  }

  if (data.type === "variable" && data.variants && data.variants.length > 0) {
    data.variants.forEach((v, index) => {
      if (v.discountPrice !== undefined && v.discountPrice >= v.price) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "سعر الخصم يجب أن يكون أقل من السعر الأساسي",
          path: ["variants", index, "discountPrice"],
        });
      }
      if (v.trackInventory && v.quantity === undefined) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "الكمية مطلوبة عند تفعيل تتبع المخزون",
          path: ["variants", index, "quantity"],
        });
      }
    });
  }
});

export type ProductFormValues = z.infer<typeof productSchema>;


`

## الملف: dashboard/app/products/types.ts
`	ypescript
export type Category = {
  id: string;
  name: string;
  parentId: string | null;
  addonGroupIds?: number[];
};

export type Attribute = {
  id: string;
  name: string;
  values: string[];
};

export type VariantAttribute = {
  name: string;
  value: string;
};

export type Variant = {
  id: string;
  name?: string;
  attributes?: VariantAttribute[];
  price?: string;
  discountPrice?: string;
  sku?: string;
  trackInventory?: boolean;
  quantity?: string;
};

export type Product = {
  id: string;
  name: string;
  description?: string;
  categoryId: string | null;
  type?: "simple" | "variable";
  price?: string;
  discountPrice?: string;
  sku?: string;
  trackInventory?: boolean;
  quantity?: string;
  variants?: Variant[];
  images?: string[];
  status?: string;
  createdAt?: string;
  updatedAt?: string;
};

`

## الملف: dashboard/lib/services/products.ts
`	ypescript
import { fetcher, apiClient } from "../api";
import { Category, Attribute } from "@/app/products/types";
import toast from "react-hot-toast";

// Helper to invalidate Storefront Cache securely via internal API Route
const revalidateStorefrontCache = async () => {
  try {
    const internalSecret = process.env.NEXT_PUBLIC_INTERNAL_DASHBOARD_SECRET || 'apex_internal_2024';
    const res = await fetch('/api/revalidate-storefront', { 
      method: 'POST',
      headers: { 'x-dashboard-secret': internalSecret }
    });
    
    if (!res.ok) {
      throw new Error('Failed request');
    }
  } catch (error) {
    console.warn("Failed to trigger storefront cache revalidation", error);
    toast.error("تم الحفظ بنجاح، لكن فشل تحديث المتجر (Cache). قد لا تظهر التعديلات فوراً.");
  }
};

export const productsApi = {
  // ==========================================
  // Categories
  // ==========================================
  getCategories: async (): Promise<Category[]> => {
    return fetcher("/v1/admin/categories");
  },

  createCategory: async (data: { name: string; parent_id: string | null; addon_group_ids?: number[] }): Promise<Category> => {
    const res = await apiClient("/v1/admin/categories", {
      method: "POST",
      body: data,
    });
    await revalidateStorefrontCache();
    return res;
  },

  updateCategory: async (id: string, data: { name: string; parent_id: string | null; addon_group_ids?: number[] }): Promise<Category> => {
    const res = await apiClient(`/v1/admin/categories/${id}`, {
      method: "PUT",
      body: data,
    });
    await revalidateStorefrontCache();
    return res;
  },

  deleteCategory: async (id: string): Promise<void> => {
    await apiClient(`/v1/admin/categories/${id}`, {
      method: "DELETE",
    });
    await revalidateStorefrontCache();
  },

  // ==========================================
  // Attributes
  // ==========================================
  getAttributes: async (): Promise<Attribute[]> => {
    return fetcher("/v1/admin/attributes");
  },

  createAttribute: async (data: { name: string; values: string[] }): Promise<Attribute> => {
    const res = await apiClient("/v1/admin/attributes", {
      method: "POST",
      body: data,
    });
    await revalidateStorefrontCache();
    return res;
  },

  updateAttribute: async (id: string, values: string[]): Promise<Attribute> => {
    const res = await apiClient(`/v1/admin/attributes/${id}`, {
      method: "PUT",
      body: { values },
    });
    await revalidateStorefrontCache();
    return res;
  },

  // ==========================================
  // Products
  // ==========================================
  getProducts: async (params?: { search?: string; category_id?: string; page?: number }) => {
    const query = new URLSearchParams();
    if (params?.search) query.append("search", params.search);
    if (params?.category_id) query.append("category_id", params.category_id);
    if (params?.page) query.append("page", params.page.toString());
    
    return fetcher(`/v1/admin/products?${query.toString()}`);
  },

  getProduct: async (id: string) => {
    return fetcher(`/v1/admin/products/${id}`);
  },

  createProduct: async (data: any) => {
    const res = await apiClient("/v1/admin/products", {
      method: "POST",
      body: data,
    });
    await revalidateStorefrontCache();
    return res;
  },

  updateProduct: async (id: string, data: any) => {
    const res = await apiClient(`/v1/admin/products/${id}`, {
      method: "PUT",
      body: data,
    });
    await revalidateStorefrontCache();
    return res;
  },

  deleteProduct: async (id: string) => {
    await apiClient(`/v1/admin/products/${id}`, {
      method: "DELETE",
    });
    await revalidateStorefrontCache();
  },
};

`

## الملف: dashboard/app/products/new/page.tsx
`	ypescript
"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { productSchema, ProductFormValues } from "../schema";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery, useMutation } from "@tanstack/react-query";
import { productsApi } from "@/lib/services/products";
import { uploadService } from "@/lib/services/upload";
import toast from "react-hot-toast";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { PackageOpen, Sparkles, ArrowRight, Loader2 } from "lucide-react";

import {
  BasicInfoTab,
  PricingTab,
  InventoryTab,
  ImagesTab,
  SEOTab,
} from "../_components/AddProductTabs";
import { VariantsTab } from "../_components/VariantsTab";
import { AddonsTab } from "../_components/AddonsTab";

// Helper to generate a URL-friendly slug supporting Arabic and English
const generateSlug = (text: string) => {
  const slug = text
    .toLowerCase()
    .trim()
    .replace(/[\s_]+/g, "-") // replace spaces and underscores with dashes
    .replace(/[^\w\u0600-\u06FF0-9-]+/g, "") // keep English, Arabic, numbers, and dashes
    .replace(/-+/g, "-"); // replace multiple dashes with a single dash
    
  return slug || Date.now().toString();
};

export default function NewProductPage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState("basic");
  const [files, setFiles] = useState<File[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Fetch real categories and attributes
  const { data: categories = [] } = useQuery({
    queryKey: ["categories"],
    queryFn: productsApi.getCategories,
  });

  const { data: attributes = [] } = useQuery({
    queryKey: ["attributes"],
    queryFn: productsApi.getAttributes,
  });

  const form = useForm<ProductFormValues>({
    resolver: zodResolver(productSchema) as any,
    defaultValues: {
      name: "",
      description: "",
      categoryId: "",
      type: "simple",
      price: undefined,
      discountPrice: undefined,
      sku: "",
      barcode: "",
      trackInventory: true,
      quantity: undefined,
      weight: undefined,
      seoTitle: "",
      seoDescription: "",
      variants: [],
      images: [],
      addonGroupIds: [],
    },
  });

  const productType = form.watch("type");

  const onSubmit = async (data: ProductFormValues) => {
    setIsSubmitting(true);
    const toastId = toast.loading("جاري حفظ المنتج...");

    try {
      // 1. Upload Images in Parallel safely
      const uploadPromises = files.map((file) => uploadService.uploadImage(file));
      const uploadResultsSettled = await Promise.allSettled(uploadPromises);
      
      const failedUploads = uploadResultsSettled.filter(r => r.status === "rejected");
      if (failedUploads.length > 0) {
        throw new Error("فشل رفع بعض الصور. يرجى المحاولة مرة أخرى.");
      }
      
      const uploadedUrls = uploadResultsSettled
        .filter((r): r is PromiseFulfilledResult<any> => r.status === "fulfilled")
        .map(r => r.value?.url)
        .filter(Boolean) as string[];

      // 2. Build backend payload (snake_case)
      const payload = {
        name: data.name,
        slug: generateSlug(data.name),
        description: data.description,
        category_id: data.categoryId,
        type: data.type,
        price: data.price,
        discount_price: data.discountPrice,
        sku: data.sku,
        barcode: data.barcode,
        track_inventory: data.trackInventory,
        quantity: data.trackInventory ? data.quantity : null,
        weight: data.weight,
        seo_title: data.seoTitle,
        seo_description: data.seoDescription,
        images: uploadedUrls,
        addon_group_ids: data.addonGroupIds,
        variants: data.type === "variable" ? data.variants?.map((v) => ({
          price: v.price,
          discount_price: v.discountPrice,
          sku: v.sku,
          track_inventory: v.trackInventory !== undefined ? v.trackInventory : true,
          quantity: v.quantity,
          attributes: v.attributes?.map((attr) => ({
            name: attr.name,
            value: attr.value,
          })),
        })) : [],
      };

      // 3. Submit to backend
      await productsApi.createProduct(payload);

      toast.success("تم حفظ المنتج بنجاح!", { id: toastId });
      router.push("/products");
    } catch (error: any) {
      toast.error(error.message || "حدث خطأ غير متوقع", { id: toastId });
      
      // Map Laravel 422 Validation Errors to React Hook Form
      if (error.info && error.info.errors) {
        const backendErrors = error.info.errors;
        Object.keys(backendErrors).forEach((key) => {
          // Attempt to map backend keys (e.g., 'category_id') to frontend ('categoryId')
          const fieldMap: Record<string, any> = {
            category_id: "categoryId",
            discount_price: "discountPrice",
            track_inventory: "trackInventory",
            seo_title: "seoTitle",
            seo_description: "seoDescription",
          };
          const formKey = fieldMap[key] || key;
          form.setError(formKey, { type: "server", message: backendErrors[key][0] });
        });
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-8" dir="rtl">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild className="rounded-full">
            <Link href="/products">
              <ArrowRight className="w-5 h-5 text-slate-500" />
            </Link>
          </Button>
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-indigo-50 rounded-xl flex items-center justify-center shrink-0">
              <PackageOpen className="w-6 h-6 text-indigo-600" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2 tracking-tight">
                إضافة منتج جديد
                <span className="px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 text-xs font-bold flex items-center gap-1">
                  <Sparkles className="w-3 h-3" /> مميز
                </span>
              </h1>
              <p className="text-slate-500 mt-1 text-sm">أدخل تفاصيل المنتج ليتم عرضه في متجرك</p>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="bg-white p-6 md:p-8 rounded-3xl border border-slate-100 shadow-sm min-h-[60vh]">
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full" dir="rtl">
          <TabsList className="w-full flex sm:flex-wrap gap-2 h-auto bg-transparent justify-start border-b border-slate-100 pb-4 mb-8 rounded-none overflow-x-auto custom-scrollbar no-scrollbar-on-mobile">
            <TabsTrigger value="basic" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">أساسي</TabsTrigger>
            <TabsTrigger value="pricing" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">التسعير</TabsTrigger>
            <TabsTrigger value="inventory" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">المخزون</TabsTrigger>
            {productType === "variable" && (
              <TabsTrigger value="variants" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">المتغيرات</TabsTrigger>
            )}
            <TabsTrigger value="addons" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">الخدمات الإضافية</TabsTrigger>
            <TabsTrigger value="images" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">الصور</TabsTrigger>
            <TabsTrigger value="seo" className="rounded-full px-5 py-2.5 data-[state=active]:bg-indigo-600 data-[state=active]:text-white data-[state=inactive]:bg-white data-[state=inactive]:hover:bg-slate-100 data-[state=inactive]:text-slate-600 border border-slate-100 data-[state=active]:border-indigo-600 transition-all font-medium whitespace-nowrap">SEO</TabsTrigger>
          </TabsList>

          <form id="product-form" onSubmit={form.handleSubmit(onSubmit)}>
            <div className="max-w-4xl mx-auto">
              <TabsContent value="basic" className="space-y-6 mt-0">
                <BasicInfoTab form={form} categories={categories} />
              </TabsContent>

              <TabsContent value="pricing" className="mt-0 h-full">
                <PricingTab form={form} />
              </TabsContent>

              <TabsContent value="inventory" className="mt-0 h-full">
                <InventoryTab form={form} />
              </TabsContent>

              {productType === "variable" && (
                <TabsContent value="variants" className="mt-0">
                  <VariantsTab form={form} attributes={attributes} />
                </TabsContent>
              )}

              <TabsContent value="addons" className="mt-0">
                <AddonsTab form={form} />
              </TabsContent>

              <TabsContent value="images" className="mt-0">
                <ImagesTab files={files} setFiles={setFiles} />
              </TabsContent>

              <TabsContent value="seo" className="mt-0">
                <SEOTab form={form} />
              </TabsContent>
            </div>
          </form>
        </Tabs>
      </div>

      {/* Footer Actions */}
      <div className="flex items-center justify-end gap-4 border-t border-slate-100 pt-6">
        <Button type="button" variant="outline" asChild className="font-bold border-slate-200 text-slate-600 hover:bg-slate-50 px-8" disabled={isSubmitting}>
          <Link href="/products">إلغاء</Link>
        </Button>
        <Button type="submit" form="product-form" disabled={isSubmitting} className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold px-10 shadow-md hover:shadow-lg transition-all min-w-[140px]">
          {isSubmitting ? <Loader2 className="w-5 h-5 animate-spin mx-auto" /> : "حفظ المنتج"}
        </Button>
      </div>
    </div>
  );
}

`

## الملف: dashboard/app/products/page.tsx
`	ypescript
"use client";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Plus, Loader2 } from "lucide-react";
import Link from "next/link";
import CategoriesManager from "./_components/CategoriesManager";
import AttributesManager from "./_components/AttributesManager";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { productsApi } from "@/lib/services/products";
import toast from "react-hot-toast";
import { useSearchParams, useRouter } from "next/navigation";

import { Suspense } from "react";

function ProductsPageContent() {
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const router = useRouter();
  const page = parseInt(searchParams.get("page") || "1", 10);
  
  const setPage = (newPage: number | ((p: number) => number)) => {
    const params = new URLSearchParams(searchParams.toString());
    const nextVal = typeof newPage === "function" ? newPage(page) : newPage;
    params.set("page", nextVal.toString());
    router.push(`?${params.toString()}`, { scroll: false });
  };

  // Queries
  const { data: categories = [], isLoading: isCategoriesLoading } = useQuery({
    queryKey: ["categories"],
    queryFn: productsApi.getCategories,
  });

  const { data: attributes = [], isLoading: isAttributesLoading } = useQuery({
    queryKey: ["attributes"],
    queryFn: productsApi.getAttributes,
  });

  const { data: productsData, isLoading: isProductsLoading } = useQuery({
    queryKey: ["products", page],
    queryFn: () => productsApi.getProducts({ page }),
  });

  // Depending on Laravel backend pagination response structure
  const products = productsData?.data || productsData || [];
  const meta = productsData?.meta; // Optional chaining in case response is not paginated natively

  // Category Mutations
  const createCategoryMutation = useMutation({
    mutationFn: (data: { name: string; parent_id: string | null; addon_group_ids?: number[] }) => productsApi.createCategory(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      toast.success("تم إضافة التصنيف بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء إضافة التصنيف"),
  });

  const updateCategoryMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: { name: string; parent_id: string | null; addon_group_ids?: number[] } }) => productsApi.updateCategory(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      toast.success("تم التحديث بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء التحديث"),
  });

  const deleteCategoryMutation = useMutation({
    mutationFn: (id: string) => productsApi.deleteCategory(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      toast.success("تم حذف التصنيف بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء الحذف"),
  });

  // Attribute Mutations
  const createAttributeMutation = useMutation({
    mutationFn: (data: { name: string; values: string[] }) => productsApi.createAttribute(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["attributes"] });
      toast.success("تم إضافة الخاصية بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء إضافة الخاصية"),
  });

  const updateAttributeMutation = useMutation({
    mutationFn: ({ id, values }: { id: string; values: string[] }) => productsApi.updateAttribute(id, values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["attributes"] });
      toast.success("تم التحديث بنجاح");
    },
    onError: () => toast.error("حدث خطأ أثناء التحديث"),
  });

  // Handlers
  const handleSaveCategory = (data: { name: string; parent_id: string | null; addon_group_ids?: number[] }, id?: string) => {
    if (id) {
      updateCategoryMutation.mutate({ id, data });
    } else {
      createCategoryMutation.mutate(data);
    }
  };

  const handleDeleteCategory = (id: string) => {
    deleteCategoryMutation.mutate(id);
  };

  const handleAddAttribute = (name: string, initialValues: string[]) => {
    createAttributeMutation.mutate({ name, values: initialValues });
  };

  const handleDeleteAttribute = (id: string) => {
    // Backend API doesn't support attribute deletion yet in routes
    toast.error("حذف المتغيرات غير مدعوم حالياً من الخادم");
  };

  const handleAddValueToAttribute = (attrId: string, value: string) => {
    const attr = attributes.find((a: any) => a.id === attrId || a.id.toString() === attrId);
    if (!attr) return;
    const newValues = attr.values.includes(value) ? attr.values : [...attr.values, value];
    updateAttributeMutation.mutate({ id: attrId, values: newValues });
  };

  const handleRemoveValueFromAttribute = (attrId: string, value: string) => {
    const attr = attributes.find((a: any) => a.id === attrId || a.id.toString() === attrId);
    if (!attr) return;
    const newValues = attr.values.filter((v: string) => v !== value);
    updateAttributeMutation.mutate({ id: attrId, values: newValues });
  };

  return (
    <div className="space-y-8" dir="rtl">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 tracking-tight">إدارة المنتجات</h1>
          <p className="text-slate-500 mt-1 text-sm">أضف، عدل، وأدر منتجات متجرك.</p>
        </div>
        <Button asChild className="gap-2">
          <Link href="/products/new">
            <Plus className="w-5 h-5" />
            إضافة منتج
          </Link>
        </Button>
      </div>

      <Tabs defaultValue="products" className="w-full" dir="rtl">
        <TabsList className="mb-6 h-auto p-1 bg-white shadow-sm border border-slate-100 rounded-2xl w-full sm:w-auto overflow-x-auto justify-start">
          <TabsTrigger value="products" className="px-6 py-2.5 rounded-xl font-bold">المنتجات</TabsTrigger>
          <TabsTrigger value="categories" className="px-6 py-2.5 rounded-xl font-bold">التصنيفات</TabsTrigger>
          <TabsTrigger value="attributes" className="px-6 py-2.5 rounded-xl font-bold">المتغيرات</TabsTrigger>
        </TabsList>

        <TabsContent value="products" className="mt-0">
          <div className="bg-white rounded-3xl p-8 text-center border border-slate-100 shadow-sm">
            {isProductsLoading ? (
               <div className="flex items-center justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-indigo-600" /></div>
            ) : products.length === 0 ? (
              <>
                <div className="w-24 h-24 bg-amber-50 text-amber-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <span className="text-4xl">📦</span>
                </div>
                <h3 className="text-lg font-bold text-slate-800 mb-2">لا توجد منتجات حتى الآن</h3>
                <p className="text-slate-500 max-w-sm mx-auto mb-6 font-medium">
                  ابدأ بإضافة منتجك الأول لتبدأ في البيع وعرض منتجاتك للعملاء.
                </p>
                <Button asChild variant="outline" className="gap-2 font-bold">
                  <Link href="/products/new">
                    <Plus className="w-4 h-4" />
                    أضف منتجك الأول
                  </Link>
                </Button>
              </>
            ) : (
              <div className="text-right">
                <p className="font-bold text-slate-700 mb-4">لديك {products.length} منتج في هذه الصفحة</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 text-right">
                  {products.map((p: any) => (
                    <div key={p.id} className="p-4 border rounded-xl shadow-sm hover:shadow-md transition">
                      <h4 className="font-bold truncate">{p.name}</h4>
                      <p className="text-slate-500 text-sm mt-1">{p.price} ج.م</p>
                    </div>
                  ))}
                </div>
                
                {/* Pagination Controls */}
                <div className="flex items-center justify-center gap-4 mt-8 pt-6 border-t border-slate-100">
                  <Button 
                    variant="outline" 
                    disabled={page <= 1}
                    onClick={() => setPage(p => Math.max(1, p - 1))}
                  >
                    السابق
                  </Button>
                  <span className="text-sm font-medium text-slate-600">الصفحة {page} {meta?.last_page ? `من ${meta.last_page}` : ''}</span>
                  <Button 
                    variant="outline"
                    disabled={meta?.last_page ? page >= meta.last_page : products.length < 15}
                    onClick={() => setPage(p => p + 1)}
                  >
                    التالي
                  </Button>
                </div>
              </div>
            )}
          </div>
        </TabsContent>

        <TabsContent value="categories" className="mt-0">
          {isCategoriesLoading ? (
             <div className="bg-white rounded-3xl p-12 flex justify-center border border-slate-100 shadow-sm"><Loader2 className="w-8 h-8 animate-spin text-indigo-600" /></div>
          ) : (
            <CategoriesManager
              // map backend ID to frontend id if parent_id is used
              categories={categories.map((c: any) => ({ 
                ...c, 
                id: c.id.toString(), 
                parentId: c.parent_id?.toString() || null, 
                addonGroupIds: c.addon_groups ? c.addon_groups.map((g: any) => typeof g.id === 'string' ? parseInt(g.id, 10) : g.id) : c.addon_group_ids || []
              }))}
              onSaveCategory={handleSaveCategory}
              onDeleteCategory={handleDeleteCategory}
              isSubmitting={createCategoryMutation.isPending || updateCategoryMutation.isPending}
            />
          )}
        </TabsContent>

        <TabsContent value="attributes" className="mt-0">
           {isAttributesLoading ? (
             <div className="bg-white rounded-3xl p-12 flex justify-center border border-slate-100 shadow-sm"><Loader2 className="w-8 h-8 animate-spin text-indigo-600" /></div>
          ) : (
            <AttributesManager
              attributes={attributes.map((a: any) => ({ ...a, id: a.id.toString() }))}
              onAddAttribute={handleAddAttribute}
              onDeleteAttribute={handleDeleteAttribute}
              onAddValueToAttribute={handleAddValueToAttribute}
              onRemoveValueFromAttribute={handleRemoveValueFromAttribute}
              isAdding={createAttributeMutation.isPending}
              isUpdating={updateAttributeMutation.isPending}
            />
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}

export default function ProductsPage() {
  return (
    <Suspense fallback={<div className="p-8 flex justify-center"><Loader2 className="w-8 h-8 animate-spin text-slate-400" /></div>}>
      <ProductsPageContent />
    </Suspense>
  );
}

`

## الملف: dashboard/app/products/_components/CategoriesManager.tsx
`	ypescript
"use client";

import { useState, useEffect } from "react";
import { Loader2, Plus, FolderTree, Trash2, Edit2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Category } from "../types";
import { useQuery } from "@tanstack/react-query";
import { addonsApi } from "@/lib/services/addons";
import { Checkbox } from "@/components/ui/checkbox";

interface CategoriesManagerProps {
  categories: Category[];
  onSaveCategory: (data: { name: string; parent_id: string | null; addon_group_ids?: number[] }, id?: string) => void;
  onDeleteCategory: (id: string) => void;
  isSubmitting?: boolean;
}

export default function CategoriesManager({
  categories,
  onSaveCategory,
  onDeleteCategory,
  isSubmitting = false,
}: CategoriesManagerProps) {
  const [categoryToDelete, setCategoryToDelete] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);

  // Form State
  const [formName, setFormName] = useState("");
  const [formParentId, setFormParentId] = useState<string>("none");
  const [formAddonGroupIds, setFormAddonGroupIds] = useState<number[]>([]);

  const { data: addonGroups = [] } = useQuery({
    queryKey: ["addonGroups"],
    queryFn: addonsApi.getAddonGroups,
    enabled: isModalOpen,
  });

  useEffect(() => {
    if (isModalOpen) {
      if (editingCategory) {
        setFormName(editingCategory.name);
        setFormParentId(editingCategory.parentId || "none");
        setFormAddonGroupIds(editingCategory.addonGroupIds || []);
      } else {
        setFormName("");
        setFormParentId("none");
        setFormAddonGroupIds([]);
      }
    }
  }, [isModalOpen, editingCategory]);

  const handleSave = () => {
    if (formName.trim()) {
      onSaveCategory(
        {
          name: formName.trim(),
          parent_id: formParentId === "none" ? null : formParentId,
          addon_group_ids: formAddonGroupIds,
        },
        editingCategory ? editingCategory.id : undefined
      );
      // Wait for success in parent to close? For simplicity we close optimistic or let parent handle, 
      // but standard is closing here and let parent invalidate
      setIsModalOpen(false);
    }
  };

  const confirmDelete = () => {
    if (categoryToDelete) {
      const children = getChildren(categoryToDelete);
      if (children.length > 0) {
        alert("لا يمكنك حذف هذا التصنيف لأنه يحتوي على تصنيفات فرعية. يرجى حذف أو نقل التصنيفات الفرعية أولاً.");
        setCategoryToDelete(null);
        return;
      }
      onDeleteCategory(categoryToDelete);
      setCategoryToDelete(null);
    }
  };

  // Helper to get children
  const getChildren = (parentId: string | null) =>
    categories.filter((c) => c.parentId === parentId);

  const toggleAddonGroup = (id: number) => {
    setFormAddonGroupIds(prev => 
      prev.includes(id) ? prev.filter(gid => gid !== id) : [...prev, id]
    );
  };

  const renderCategoryTree = (parentId: string | null = null, depth = 0) => {
    const children = getChildren(parentId);
    if (children.length === 0) return null;

    return (
      <ul className="space-y-2">
        {children.map((category) => (
          <li key={category.id} className="relative">
            <div
              className={`flex items-center justify-between p-3 bg-white border border-slate-100 rounded-xl shadow-sm hover:shadow-md transition-shadow group ${depth > 0 ? "mt-2" : ""}`}
              style={{ marginRight: depth > 0 ? `${depth * 1.5}rem` : "0" }}
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-indigo-50 text-indigo-600 flex items-center justify-center shrink-0">
                  <FolderTree className="w-4 h-4" />
                </div>
                <div>
                  <span className="font-medium text-slate-800 block">
                    {category.name}
                  </span>
                  {(category.addonGroupIds?.length || 0) > 0 && (
                     <span className="text-xs text-indigo-500 font-bold bg-indigo-50 px-2 py-0.5 rounded mt-1 inline-block">
                       مربوط بخدمات إضافية
                     </span>
                  )}
                </div>
              </div>
              <div className="opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-1">
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-8 w-8 p-0 text-slate-500 hover:text-indigo-600 hover:bg-indigo-50"
                  onClick={() => { setEditingCategory(category); setIsModalOpen(true); }}
                >
                  <Edit2 className="w-4 h-4" />
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-8 w-8 p-0 text-red-500 hover:text-red-700 hover:bg-red-50"
                  onClick={() => setCategoryToDelete(category.id)}
                >
                  <Trash2 className="w-4 h-4" />
                </Button>
              </div>
            </div>
            {renderCategoryTree(category.id, depth + 1)}
          </li>
        ))}
      </ul>
    );
  };

  return (
    <div className="space-y-8">
      {/* Header & Add Button */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold text-slate-800 flex items-center gap-2">
          <FolderTree className="w-5 h-5 text-indigo-500" />
          هيكلة التصنيفات
        </h3>
        <Button
          onClick={() => { setEditingCategory(null); setIsModalOpen(true); }}
          className="bg-indigo-600 hover:bg-indigo-700 gap-2 h-10"
        >
          <Plus className="w-4 h-4" /> إضافة تصنيف
        </Button>
      </div>

      {/* Category Tree */}
      <div className="bg-slate-50/50 p-6 rounded-3xl border border-slate-100">
        {categories.length === 0 ? (
          <div className="text-center py-10 text-slate-500 font-medium">
            لا يوجد تصنيفات حالياً. أضف تصنيفاً جديداً للبدء.
          </div>
        ) : (
          renderCategoryTree(null, 0)
        )}
      </div>

      {/* Category Modal (Add / Edit) */}
      <Dialog open={isModalOpen} onOpenChange={(open) => !open && setIsModalOpen(false)}>
        <DialogContent dir="rtl" className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{editingCategory ? "تعديل تصنيف" : "إضافة تصنيف جديد"}</DialogTitle>
          </DialogHeader>

          <div className="space-y-6 py-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>اسم التصنيف *</Label>
                <Input
                  placeholder="مثال: مطبوعات ورقية"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label>يتبع لتصنيف (الأب)</Label>
                <Select
                  dir="rtl"
                  value={formParentId}
                  onValueChange={setFormParentId}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="التصنيف الأساسي" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">-- تصنيف رئيسي --</SelectItem>
                    {categories.filter(c => c.id !== editingCategory?.id).map((cat) => (
                      <SelectItem key={cat.id} value={cat.id}>
                        {cat.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="pt-4 border-t border-slate-100">
              <Label className="text-base font-bold text-slate-800 mb-2 block">مجموعات الخدمات الإضافية</Label>
              <p className="text-sm text-slate-500 mb-4">اختر الخدمات التي ترغب بإتاحتها لجميع المنتجات تحت هذا التصنيف.</p>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {addonGroups.length === 0 ? (
                  <p className="text-sm text-slate-400">لا توجد مجموعات خدمات للربط.</p>
                ) : addonGroups.map((group) => {
                  const groupIdNum = typeof group.id === 'string' ? parseInt(group.id, 10) : group.id;
                  const isSelected = formAddonGroupIds.includes(groupIdNum);
                  
                  return (
                    <div 
                      key={group.id}
                      className={`flex items-center gap-3 p-3 border rounded-lg cursor-pointer ${isSelected ? 'border-indigo-600 bg-indigo-50/50' : 'border-slate-200 hover:border-indigo-300'}`}
                      onClick={() => toggleAddonGroup(groupIdNum)}
                    >
                      <Checkbox 
                        checked={isSelected}
                        onCheckedChange={() => toggleAddonGroup(groupIdNum)}
                        className="data-[state=checked]:bg-indigo-600"
                      />
                      <span className="font-medium text-slate-700 text-sm">{group.name?.ar}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setIsModalOpen(false)}>إلغاء</Button>
            <Button 
              className="bg-indigo-600 hover:bg-indigo-700" 
              onClick={handleSave}
              disabled={!formName.trim() || isSubmitting}
            >
              {isSubmitting ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : "حفظ التصنيف"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={!!categoryToDelete}
        onOpenChange={(open) => !open && setCategoryToDelete(null)}
      >
        <DialogContent dir="rtl">
          <DialogHeader>
            <DialogTitle className="text-red-600 text-right flex items-center gap-2">
              <Trash2 className="w-5 h-5" />
              تأكيد الحذف
            </DialogTitle>
          </DialogHeader>
          <div className="py-4 text-right">
            <p className="text-slate-600 font-medium">
              هل أنت متأكد من حذف هذا التصنيف؟
              <br />
              <span className="text-red-500 font-bold mt-2 inline-block">
                تنبيه: لا يمكن التراجع عن هذا الإجراء.
              </span>
            </p>
          </div>
          <DialogFooter className="gap-2 sm:gap-0 flex-row justify-end">
            <Button
              variant="outline"
              onClick={() => setCategoryToDelete(null)}
            >
              إلغاء
            </Button>
            <Button variant="destructive" onClick={confirmDelete}>
              نعم، قم بالحذف
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

`

