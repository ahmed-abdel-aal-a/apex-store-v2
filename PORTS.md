# Apex Store - Ports Configuration

This document outlines the ports used by the different services in this project to avoid any conflicts and for quick reference.

## 🔗 Services & Ports

| Service | Technology | Port | Local URL |
| :--- | :--- | :--- | :--- |
| **Backend (API)** | Laravel | `8000` | [http://127.0.0.1:8000](http://127.0.0.1:8000) |
| **Storefront (Client UI)** | Next.js | `3111` | [http://127.0.0.1:3111](http://127.0.0.1:3111) |
| **Dashboard (Admin UI)** | Next.js | `3112` | [http://127.0.0.1:3112](http://127.0.0.1:3112) |

## 🛠️ How to Start (Commands)

If you need to start them manually from the terminal:

1. **Backend:** 
   ```bash
   cd backend
   php artisan serve --port=8000
   ```
2. **Storefront:**
   ```bash
   cd storefront
   npm run dev
   ```
3. **Dashboard:**
   ```bash
   cd dashboard
   npm run dev
   ```

*(Note: Ensure `npm run dev` in package.json uses `-p 3111` for storefront and `-p 3112` for dashboard.)*
