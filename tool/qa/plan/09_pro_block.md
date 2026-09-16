# 09 — Bloque PRO (requiere fixture E2E_PRO)

**Si `dart_defines_e2e_pro.json` no existe, toda esta sección se marca
`BLOCKED (fixture ausente)` de antemano — no intentar ninguno de estos
casos ni contarlo como fallo del plan.** Ver `00_mecanica_y_entorno.md` para
cómo se crea ese fixture (manual, fuera del alcance de Claude).

Cuenta activa al entrar: `E2E_PRO`. Recomendado: `adb shell pm clear
com.gpm.expensemanager_app` antes de esta sección para partir de estado
limpio, luego login con `E2E_PRO` y repetir `FR-10` (fijar inglés/EUR) si
hace falta.

---

### [PROB-01] Login PRO — sin anuncios
**Requiere:** PRO · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Login con `E2E_PRO`.
2. Observar la barra inferior del dashboard.

Esperado: no hay `AdBannerFooter` visible (oculto para PRO).
Verificar: screenshot del dashboard completo.

---

### [PROB-02] Chat IA — mensaje real
**Requiere:** PRO (red + IA) · **Bloqueante conocido:** respuesta de IA puede tardar/fluctuar · **Severidad:** alta

Pasos:
1. Confirmar que el icono de chat SÍ aparece en el AppBar del dashboard (a diferencia de PRO-05).
2. Tap en el icono → `/chat`.
3. Tap en uno de los chips de sugerencia (envío inmediato) o escribir una pregunta simple ("¿cuánto gasté este mes?").
4. Esperar la respuesta (poll hasta 30s, con indicador de "escribiendo" mientras tanto).

Esperado: respuesta de la IA visible, sin error; el indicador de carga desaparece al llegar la respuesta.
Verificar: screenshot del indicador de carga y de la respuesta final.
Si fluctúa: reintentar el envío una vez si no hay respuesta en 30s; si persiste, FAIL (no está probado el manejo de error del chat en el código — es justo lo que este caso busca revelar).

---

### [PROB-03] Presupuestos ilimitados
**Requiere:** PRO · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Crear un primer presupuesto (categoría cualquiera, importe 100).
2. Crear un segundo presupuesto (categoría distinta).

Esperado: el segundo se crea sin mostrar el diálogo de upgrade (a diferencia de BUD-02 en FREE).
Verificar: screenshot de la lista con 2 presupuestos.

---

### [PROB-04] Mic — sin PRO-gate (voz real sigue BLOCKED)
**Requiere:** PRO · **Bloqueante conocido:** el reconocimiento de voz en sí sigue `BLOCKED` (sin passthrough de audio) — este caso solo verifica que NO redirige a `/pro` · **Severidad:** media

Pasos:
1. Tap en el icono de micrófono.

Esperado: intenta iniciar la escucha (posible error de "mic unavailable" en el emulador, pero NO debe redirigir a `/pro`).
Verificar: screenshot mostrando el estado de "escuchando" o el error de mic, nunca la pantalla `/pro`.

---

### [PROB-05] Foto — parseo con IA usando fixture
**Requiere:** PRO (red + IA) · **Bloqueante conocido:** `BLOCKED` si el picker fuerza cámara en vivo sin opción de galería · **Severidad:** media

Pasos:
1. `adb push tool/qa/fixtures/test_receipt.jpg /sdcard/Pictures/`.
2. Tap en el icono de cámara → elegir "Gallery" en el selector de origen.
3. Seleccionar `test_receipt.jpg`.
4. Esperar el parseo de IA (poll hasta 30s).

Esperado: se abre el sheet de añadir transacción prellenado con datos coherentes con el recibo (total ~17.50, categoría razonable).
Verificar: screenshot del sheet prellenado.
Si fluctúa: reintentar una vez; si el parseo falla de forma consistente, FAIL.

---

### [PROB-06] Tutorial — paso de chat visible en PRO
**Requiere:** PRO · **Bloqueante conocido:** requiere reiniciar el tutorial desde el drawer · **Severidad:** baja

Pasos:
1. Drawer → "Tutorial" (reiniciar).
2. Avanzar hasta el paso que resalta el icono de chat.

Esperado: a diferencia de FR-09 (FREE), este paso SÍ se muestra (no se auto-salta) porque el icono de chat existe en la UI.
Verificar: screenshot del spotlight sobre el icono de chat.

---

### [PROB-07] Sync offline — crear transacción en modo avión (PRO)
**Requiere:** PRO · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Activar modo avión: `adb shell svc wifi disable && adb shell svc data disable`.
2. Crear una transacción nueva vía UI.
3. Confirmar que se guarda localmente sin error visible.
4. Desactivar modo avión: `adb shell svc wifi enable && adb shell svc data enable`.
5. Esperar unos segundos y hacer pull-to-refresh.

Esperado: la transacción se crea sin bloquear la UI estando offline (cola de sync), y al recuperar conexión se sincroniza (verificable indirectamente si hay algún indicador de sync, o al menos confirmando que no hay error visible tras reconectar).
Verificar: screenshots en cada fase (offline creando, tras reconectar).

---

### [PROB-08] Sync offline — presupuestos fallan explícito (sin cola)
**Requiere:** PRO · **Bloqueante conocido:** este es el comportamiento documentado (a diferencia de transacciones, budgets no tienen cola de sync) · **Severidad:** alta

Pasos:
1. Activar modo avión.
2. Intentar crear/editar un presupuesto.

Esperado: falla explícitamente con un mensaje de error de red (no un guardado silencioso ni una cola invisible).
Verificar: screenshot del mensaje de error. Desactivar modo avión al terminar.

---

### [PROB-09] Refresh de estado de suscripción
**Requiere:** PRO (red) · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. En `/pro`, con la card de "Active PRO" visible, tap en "Refresh status".

Esperado: re-sincroniza sin error, la card sigue mostrando PRO activo.
Verificar: screenshot antes/después.
