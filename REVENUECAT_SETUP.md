# RevenueCat Setup Checklist

Entitlement ID en código: `pro` (no cambiar)

---

## ANDROID

### Paso 1 — Google Play Console: crear suscripciones

> Requisito: la app debe estar subida al menos en Internal Testing.

- [x] Ir a Monetize → Subscriptions → `+`
- [ ] ~~Crear suscripción `expensemanager_pro_annual`~~ (descartada)
- [x] Crear suscripción `expensemanager_pro_monthly`
  - Base Plan: recurrencia mensual
  - Offer: Free Trial de 4 días
  - Activar (estado: Active)

### Paso 2 — Google Play Console: Service Account para RevenueCat

- [ ] Setup → API access → Link to Google Cloud Project
- [ ] Crear Service Account con roles:
  - `Financial data viewer`
  - `Publisher`
- [ ] Descargar el JSON de credenciales del Service Account

### Paso 3 — RevenueCat: añadir app Android

- [ ] Apps & providers → Configurations → New Play Store app
  - App name: `ExpenseManager (Play Store)`
  - Package name: `com.gpm.expensemanager_app`
  - Subir el JSON del Service Account
- [ ] Guardar → copiar la **Public API Key** Android

### Paso 4 — RevenueCat: Product Catalog (Android)

- [x] Product catalog → Entitlements → `+` — Identifier: `pro`
- [x] Product catalog → Products → añadir:
  - ~~`expensemanager_pro_annual` — Play Store~~ (descartada)
  - `expensemanager_pro_monthly` — Play Store
- [x] Adjuntar producto al entitlement `pro`
- [x] Product catalog → Offerings → crear offering `default`
  - Package `$rc_monthly` → producto monthly Android

### Paso 5 — dart_defines.json

```json
{
  "REVENUECAT_ANDROID_KEY": "goog_XXXXXXXXXXXX"
}
```

### Paso 6 — Verificar Android

- [ ] `flutter run --dart-define-from-file=dart_defines.json` en dispositivo Android
- [ ] Abrir pantalla PRO → precios visibles
- [ ] Compra de prueba con cuenta de test de Google Play
- [ ] Verificar que `isProProvider` devuelve `true`

---

## iOS (pendiente después de Android)

### Requisitos previos

- [ ] Firmar **Paid Apps Agreement**: App Store Connect → Agreements → Paid Apps
  - Requiere datos bancarios, fiscales y dirección legal

### Paso 1 — App Store Connect: clave P8

- [ ] Users and Access → Integrations → In-App Purchase → `+`
- [ ] Descargar el `.p8` (solo se puede descargar una vez)
- [ ] Anotar **Key ID** y **Issuer ID**

### Paso 2 — App Store Connect: productos

- [ ] Tu app → Subscriptions → crear grupo `ExpenseManager Pro`
- [ ] Crear `expensemanager_pro_annual` — 1 año, Free Trial 4 días
- [ ] Crear `expensemanager_pro_monthly` — 1 mes, Free Trial 4 días
- [ ] Añadir localización a cada producto (nombre + descripción)

### Paso 3 — RevenueCat: añadir app iOS

- [ ] Apps & providers → Configurations → New App Store app
  - App name: `ExpenseManager (App Store)`
  - Bundle ID: `com.gpm.expensemanagerapp`
  - Subir `.p8`, Key ID e Issuer ID
- [ ] Guardar → copiar la **Public API Key** iOS

### Paso 4 — RevenueCat: Product Catalog (iOS)

- [ ] Product catalog → Products → añadir:
  - `expensemanager_pro_annual` — App Store
  - `expensemanager_pro_monthly` — App Store
- [ ] Adjuntar al entitlement `pro`
- [ ] En el offering `default`, vincular los paquetes con los productos iOS

### Paso 5 — dart_defines.json

```json
{
  "REVENUECAT_IOS_KEY": "appl_XXXXXXXXXXXX"
}
```

### Paso 6 — Verificar iOS

- [ ] `flutter run --dart-define-from-file=dart_defines.json` en dispositivo iOS
- [ ] Usar cuenta Sandbox (Settings → App Store → Sandbox Account)
- [ ] Compra de prueba y verificar entitlement `pro`
