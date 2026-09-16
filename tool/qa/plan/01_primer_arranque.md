# 01 — Primer arranque, onboarding y tutorial

Cuenta activa al entrar: ninguna (app recién instalada). Estado de datos:
ninguno. **Requiere `adb shell pm clear com.gpm.expensemanager_app` antes del
primer caso** (ver `00_mecanica_y_entorno.md`).

Todos los pasos de esta sección se ejecutan con el locale del dispositivo
por defecto (probablemente español) — el caso `FR-10` es el que fija inglés
para el resto del plan.

---

### [FR-01] App recién instalada redirige a Login
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. `adb shell pm clear com.gpm.expensemanager_app`.
2. Lanzar la app (`adb shell am start -n com.gpm.expensemanager_app/.MainActivity` o relanzar desde `flutter run`).

Esperado: sin sesión activa, la app redirige a `/login` (no a `/dashboard`).
Verificar: screenshot muestra la pantalla de Login (campos email/password).
Si fluctúa: no aplica.

---

### [FR-02] Validación de Login — campos vacíos
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. En Login, dejar email y password vacíos.
2. Tap en "Sign in".

Esperado: errores de validación bajo los campos, no navega ni muestra spinner.
Verificar: screenshot con los mensajes de error visibles.

---

### [FR-03] Validación de Login — email con formato inválido
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Email: `no-es-un-email`. Password: cualquier valor.
2. Tap en "Sign in".

Esperado: error de formato de email, no intenta autenticar contra Supabase.
Verificar: screenshot con el mensaje de error.

---

### [FR-04] Login con contraseña incorrecta muestra error de auth
**Requiere:** ninguno (red) · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Email de `E2E_FREE` (leer de `dart_defines_e2e.json`), password deliberadamente incorrecto.
2. Tap en "Sign in".

Esperado: snackbar/mensaje de error de credenciales inválidas; permanece en Login.
Verificar: screenshot del snackbar de error.
Si fluctúa (red): reintentar una vez; si el error no aparece en 10s, FAIL (no BLOCKED — es un fallo de manejo de error, no de infraestructura).

---

### [FR-05] Login exitoso con E2E_FREE
**Requiere:** FREE · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Email/password correctos de `E2E_FREE`.
2. Tap en "Sign in".

Esperado: navega fuera de Login (a onboarding o a dashboard — documentar cuál ocurre realmente, el orden exacto no estaba confirmado en la exploración de código).
Verificar: screenshot post-login.

---

### [FR-06] Onboarding — recorrido completo (si aparece)
**Requiere:** ninguno · **Bloqueante conocido:** solo aplica si FR-05 mostró onboarding · **Severidad:** media

Pasos:
1. Si el onboarding (7 páginas: Welcome/Manual/Photo/Voice/List/Charts/Done) se mostró tras FR-05, swipe hacia la derecha (`input swipe` de derecha a izquierda) por cada página.
2. Verificar que el contador de puntos avanza y que "Skip" desaparece en la última página.
3. En la última página, tap en "Start"/"Next".

Esperado: navega a dashboard (o al prompt de tutorial). El botón "Skip" no está presente en la página final.
Verificar: screenshot de cada página relevante (al menos primera, intermedia y última).

---

### [FR-07] Prompt inicial de tutorial — aceptar
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Precondición extra: primera visita al dashboard tras FR-05/FR-06 (flags de primer-arranque intactos).

Pasos:
1. En el dashboard debería aparecer un diálogo "¿Empezar el tutorial?" con opciones Start/Later.
2. Tap en "Start".

Esperado: comienza el overlay de tutorial (spotlight sobre el primer elemento, contador "1 / 6").
Verificar: screenshot del diálogo y luego del primer paso del tutorial.

---

### [FR-08] Tutorial paso 1 — FAB (añadir/voz/foto)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Tap sobre el elemento resaltado (FAB central).

Esperado: avanza al paso 2, contador cambia a "2 / 6".
Verificar: screenshot mostrando el nuevo spotlight.

---

### [FR-09] Tutorial pasos 2-6 — completar el recorrido
**Requiere:** ninguno · **Bloqueante conocido:** el paso 4 (chat IA) debe auto-saltarse en cuenta FREE (`skipIfKeyMissing`) · **Severidad:** media

Pasos:
1. Repetir tap sobre cada elemento resaltado: balance card (paso 2), botón Charts (paso 3), enlace "See all" del historial (paso 5 en FREE, el paso 4/chat se salta solo), icono de drawer/settings (paso 6).
2. Confirmar que el contador nunca muestra "4 / 6" con el icono de chat resaltado en esta cuenta FREE (verificar que ese paso no aparece, o si aparece reporta FAIL — contradice el diseño documentado).
3. Tras el último paso, confirmar que el overlay se cierra.

Esperado: tutorial completo sin quedarse atascado en ningún paso; el icono de chat nunca se resalta en FREE.
Verificar: screenshot de cada paso + screenshot final sin overlay.

---

### [FR-09b] Tutorial — botón "Skip" (en una repetición posterior)
**Requiere:** ninguno · **Bloqueante conocido:** requiere reiniciar el tutorial desde el drawer (ver `03_dashboard_navegacion.md` DASH-12) para tener un segundo pase · **Severidad:** baja

Pasos:
1. Reiniciar el tutorial desde el drawer.
2. En el paso 2 o 3, tap en "Skip"/"Omitir".

Esperado: el overlay se cierra inmediatamente, sin completar los pasos restantes.
Verificar: screenshot mostrando que el overlay desaparece tras "Skip".

---

### [FR-10] Fijar idioma inglés y moneda EUR (setup para el resto del plan)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta (bloquea determinismo del resto del plan si no se hace)

Pasos:
1. Abrir drawer (icono gear) → "App Settings".
2. Tap en la fila "Language" → seleccionar "English".
3. Tap en la fila "Currency" → seleccionar "EUR".
4. Volver al dashboard.

Esperado: toda la UI pasa a mostrar cadenas en inglés inmediatamente, sin reiniciar la app. Símbolo de moneda "€" en los importes.
Verificar: screenshot de Settings en inglés y del dashboard con "€".
Nota: a partir de aquí, todos los demás archivos del plan asumen locale=en.
