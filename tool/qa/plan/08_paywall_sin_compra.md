# 08 — Paywall / suscripción sin completar una compra (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada, locale=en. Esta sección
verifica todo lo que rodea al paywall sin llegar a comprar ni a iniciar un
trial real (eso vive en `11_destructivos_y_manuales.md`).

---

### [PRO-01] Pantalla /pro — elementos visuales
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Drawer → fila de plan PRO (o cualquier CTA a `/pro`, p.ej. desde BUD-02).

Esperado: se ve la lista de beneficios, el `PlanPicker` (anual preseleccionado), botón "Subscribe", "Restore purchases", enlace de promo code, disclaimer legal. Botón "Subscribe" no debe estar deshabilitado permanentemente (solo mientras carga).
Verificar: screenshot completo de la pantalla (con scroll si hace falta).

---

### [PRO-02] Promo code — código inválido
**Requiere:** ninguno (red) · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en "Promo code" (desde `/pro` o el drawer).
2. Escribir un código inventado, p.ej. `QANOEXISTE123`.
3. Tap en "Apply".

Esperado: mensaje de error específico del servidor (código inválido/expirado), el diálogo permanece abierto para reintentar.
Verificar: screenshot del mensaje de error.
Si fluctúa (red): reintentar una vez si no hay respuesta en 30s.

---

### [PRO-03] Promo code — cooldown tras 3 fallos
**Requiere:** ninguno (red) · **Bloqueante conocido:** depende de PRO-02, cuenta como el primer intento fallido · **Severidad:** media

Pasos:
1. Repetir el intento de PRO-02 dos veces más con códigos inválidos distintos (total 3 fallos).
2. Intentar una cuarta vez.

Esperado: mensaje de cooldown (bloqueo temporal ~30s) en vez de "código inválido".
Verificar: screenshot del mensaje de cooldown. Esperar los 30s y confirmar que vuelve a aceptar intentos.

---

### [PRO-04] Restore purchases sin compra previa
**Requiere:** ninguno (red + tienda) · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. En `/pro`, tap en "Restore purchases".

Esperado: mensaje de "nada que restaurar" (no debe otorgar PRO ni crashear).
Verificar: screenshot del mensaje resultante.

---

### [PRO-05] Chat gateado — icono ausente y deep-link redirige
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Confirmar en el dashboard que NO hay icono de chat en el AppBar (ya cubierto en DASH-12, revalidar aquí en contexto de paywall).
2. `adb shell am start -a android.intent.action.VIEW -d "expensemanager://widget/chat"`.

Esperado: el deep link a chat, en cuenta FREE, redirige a `/pro` en vez de abrir el chat.
Verificar: screenshot tras el deep link.

---

### [PRO-06] Free trial — solo observar, no iniciar
**Requiere:** ninguno · **Bloqueante conocido:** iniciar el trial es `REQUIERE HUMANO` (compromiso real con la tienda) — ver `11_destructivos_y_manuales.md` MAN-08 · **Severidad:** baja

Pasos:
1. En `/pro`, observar si aparece la `FreeTrialCard` ("Start free trial").

Esperado: si `E2E_FREE` es elegible, la card aparece con el CTA visible. NO tocar el botón.
Verificar: screenshot de la card (o su ausencia, si la cuenta ya no es elegible — documentar cuál es el caso).
