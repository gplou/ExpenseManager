# 11 — Casos destructivos / que requieren intervención humana

**Todos los casos de este archivo se marcan `SKIPPED` por defecto en modo
autónomo.** Solo se ejecutan si el usuario los pide explícitamente por su
ID, y varios de ellos (MAN-01, MAN-07, MAN-08) tienen efectos reales e
irreversibles — confirmar con el usuario antes de tocarlos aunque los pida
por nombre, si hay cualquier ambigüedad sobre qué cuenta/entorno se va a
usar.

---

### [MAN-01] Compra real de suscripción (sandbox)
**Requiere:** REQUIERE HUMANO (tienda sandbox) · **Motivo:** RevenueCat necesita un tester sandbox real de Play/App Store; no se puede completar solo con `adb`/capturas.

Si se ejecuta: usar una cuenta de prueba de licencia (Play Console) o
sandbox tester (App Store Connect) dedicada — nunca una cuenta personal
real. Verificar que tras el cobro sandbox, `/pro` refleja el estado PRO y
`PROB-01` en adelante pasan a poder ejecutarse con esta misma cuenta.

---

### [MAN-02] Restore purchases con historial real
**Requiere:** REQUIERE HUMANO (tienda sandbox con compra previa) · **Motivo:** depende de que MAN-01 se haya ejecutado antes en el mismo dispositivo/tienda.

---

### [MAN-03] Google Sign-In completo
**Requiere:** REQUIERE HUMANO · **Motivo:** riesgo de seguridad/fragilidad al automatizar credenciales reales de Google vía `adb input text` en un WebView OAuth.

Si se ejecuta: como mucho, Claude verifica que el botón "Continue with
Google" abre el flujo nativo de selección de cuenta y cancela sin completar
el login; el login efectivo lo hace el humano.

---

### [MAN-04] Apple Sign-In completo (solo iOS/macOS)
**Requiere:** REQUIERE HUMANO · **Motivo:** mismo riesgo que MAN-03, y además iOS ya está fuera del modo autónomo por defecto (ver `00_mecanica_y_entorno.md`).

Verificación mínima no interactiva: confirmar que el botón NO aparece en
Android (solo en iOS/macOS) — esto sí es automatizable como parte de
`02_auth_free.md` si se quiere, revisando un screenshot del login en Android.

---

### [MAN-05] Forgot/reset password con bandeja de correo real
**Requiere:** REQUIERE HUMANO · **Motivo:** Claude no tiene acceso a la bandeja de `E2E_FREE`/`E2E_PRO` para confirmar la recepción y completar el enlace. Ver `AUTH-07` para la parte automatizable (apertura del flujo).

---

### [MAN-06] Registro de cuenta nueva con confirmación por email
**Requiere:** REQUIERE HUMANO (si el proyecto Supabase exige confirmación por correo) · **Motivo:** sin acceso a bandeja de entrada.

Antes de descartar este caso por completo, comprobar una vez (manualmente,
por el humano) si el proyecto Supabase de verdad exige confirmación. Si NO
la exige, este caso puede degradarse a automatizable con una identidad
desechable y moverse fuera de este archivo en una futura revisión del plan.

---

### [MAN-07] Borrar cuenta
**Requiere:** REQUIERE HUMANO · **Motivo:** destructivo e irreversible sobre un usuario real. Nunca ejecutar sobre `E2E_FREE` ni `E2E_PRO` (son fixtures reutilizables para todo el resto del plan) — solo sobre una cuenta desechable creada para este único propósito.

---

### [MAN-08] Iniciar un free trial real
**Requiere:** REQUIERE HUMANO · **Motivo:** compromiso real con la tienda (aunque sea trial, registra un método de pago/consume la elegibilidad de por vida de la cuenta). Ver `PRO-06` para la parte automatizable (solo observar que la card aparece).
