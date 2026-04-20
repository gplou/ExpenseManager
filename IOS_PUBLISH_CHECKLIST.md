# iOS App Store — Checklist Publicación

## SIN PAGAR ($0)

### Código / Config (ya hecho)
- [x] Info.plist permisos (mic, cámara, fotos)
- [x] PrivacyInfo.xcprivacy
- [x] Runner.entitlements declarado
- [x] Bundle ID `com.gpm.expensemanagerapp`
- [x] App icon set completo
- [x] `ITSAppUsesNonExemptEncryption = false`

### Pendiente (gratis)
- [x] **Privacy policy** — publicada en GitHub Pages.
- [x] **Support URL** — https://gplou.github.io/ExpenseManager/support.html
- [ ] **Screenshots App Store** — tomar con simulador iOS (6.5" iPhone 14 Pro Max + 5.5" iPhone 8 Plus mínimo)
  - Skills: `/simulator-utils` (capturar + redimensionar), `/ui-ux-pro-max` (composición visual)
- [x] **Metadata** — nombre app, subtítulo (≤30 chars), descripción, keywords (≤100 chars) → `store.config.json`
  - Skills: `/apple-aso` (optimización ASO: keywords, título, descripción para máximo ranking)
- [ ] **Age rating questionnaire** — preparar respuestas (sin violencia, sin contenido adulto, etc.)
- [ ] **RevenueCat dashboard** — verificar iOS products configurados
- [ ] **AdMob** — confirmar app iOS registrada y ad unit IDs correctos para iOS
- [ ] **Build local iOS** — `flutter build ios --dart-define-from-file=dart_defines.json` sin errores
  - Skills: `/ios-dev`

---

## REQUIERE PAGAR ($99/año Apple Developer)

- [ ] **Enrollar Apple Developer Program**
- [ ] **Registrar Bundle ID** en Developer portal + activar capabilities:
  - [ ] Sign in with Apple
  - [ ] App Groups `group.com.gpm.expensemanagerapp`
  - Skills: `/ios-dev`
- [ ] **DEVELOPMENT_TEAM** — asignar en Xcode (automatic signing)
  - Skills: `/ios-dev`
- [ ] **Distribution certificate + provisioning profile**
  - Skills: `/ios-dev`
- [ ] **App Store Connect** — crear app record
- [ ] **In-App Purchases / Subscriptions** — configurar en App Store Connect
  - Skills: `/storekit` (StoreKit 2, productos, suscripciones, transacciones)
- [ ] **TestFlight** — subir build y probar en device real
  - Skills: `/ios-dev`
- [ ] **App Review** — submit y esperar aprobación (1-3 días)
