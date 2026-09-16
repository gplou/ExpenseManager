# 07 — Ajustes (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada. Locale ya fijado a inglés en
`FR-10` — algunos casos aquí lo cambian temporalmente, revertir a inglés al
terminar la sección para no romper el resto del plan.

---

### [SET-01] Dark mode
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Drawer → App Settings.
2. Tap en el switch "Dark mode".

Esperado: el tema cambia instantáneamente en toda la app (sin reiniciar).
Verificar: screenshot antes/después. Volver a dejarlo en el estado que prefieras para el resto de capturas (recomendado: claro, para que el resto del plan tenga screenshots consistentes).

---

### [SET-02] Cambio de idioma (round-trip)
**Requiere:** ninguno · **Bloqueante conocido:** revertir a English al final de este caso · **Severidad:** media

Pasos:
1. Tap en la fila "Language" → elegir "Español".
2. Verificar que la UI cambia a español inmediatamente.
3. Volver a la fila de idioma → elegir "English" de nuevo.

Esperado: cambio instantáneo en ambas direcciones, sin reiniciar la app.
Verificar: dos screenshots (es/en) de la misma pantalla de Settings.

---

### [SET-03] Cambio de moneda — solo visual, no convierte histórico
**Requiere:** ninguno · **Bloqueante conocido:** revertir a EUR al final · **Severidad:** alta

Pasos:
1. Anotar el importe mostrado de una transacción ya existente (p.ej. la de TX-03, 42.50€).
2. Cambiar la moneda a "USD" en Settings.
3. Volver a la lista de transacciones y mirar esa misma transacción.

Esperado: el símbolo cambia a "$" pero el número sigue siendo 42.50 (no se recalcula/convierte). Confirma el comportamiento "display-only" documentado.
Verificar: screenshot antes/después mostrando el mismo número con distinto símbolo.

---

### [SET-04] Formato numérico (separador decimal)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Tap en la fila de formato numérico → alternar entre punto y coma decimal.

Esperado: los importes ya existentes cambian de "42.50" a "42,50" (o viceversa) de forma consistente en toda la app.
Verificar: screenshot de un importe en ambos formatos.

---

### [SET-05] App Lock — activar (requiere huella enrolada)
**Requiere:** hardware (biometría enrolada en el AVD — prerrequisito manual, ver `00_mecanica_y_entorno.md`) · **Bloqueante conocido:** si no hay huella enrolada, marcar `BLOCKED` en vez de intentarlo · **Severidad:** alta

Pasos:
1. Tap en el switch "App Lock".
2. Si aparece un prompt biométrico, autenticar con `adb -s emulator-5554 emu finger touch 1`.

Esperado: si hay biometría disponible y la auth tiene éxito, el switch queda activado. Si no hay biometría configurada, debe mostrarse un snackbar de "no disponible" (no debe activarse silenciosamente sin autenticar).
Verificar: screenshot del prompt y del switch tras el resultado.

---

### [SET-06] App Lock — bloqueo en background/resume
**Requiere:** hardware (depende de SET-05 activado) · **Bloqueante conocido:** `BLOCKED` si SET-05 quedó `BLOCKED` · **Severidad:** alta

Pasos:
1. Con App Lock activado, enviar la app a background (`adb shell input keyevent 3` para ir a home).
2. Volver a abrir la app (`adb shell am start -n com.gpm.expensemanager_app/.MainActivity`).

Esperado: aparece el overlay opaco de bloqueo con botón de huella, antes de mostrar cualquier contenido.
Verificar: screenshot del overlay. Desbloquear con `emu finger touch 1` y confirmar que vuelve a la pantalla donde estabas.

---

### [SET-07] App Lock — desactivar
**Requiere:** hardware (depende de SET-05) · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en el switch "App Lock" para desactivarlo.

Esperado: se desactiva inmediatamente sin pedir autenticación adicional.
Verificar: screenshot del switch desactivado. Repetir SET-06 (background/resume) y confirmar que ya NO aparece el overlay.

---

### [SET-08] Recordatorios recurrentes — activar
**Requiere:** ninguno · **Bloqueante conocido:** puede requerir conceder el permiso de notificaciones del sistema (diálogo OS) · **Severidad:** media

Pasos:
1. Tap en el switch de "Recurring reminders".
2. Si aparece el diálogo de permiso de notificaciones de Android, concederlo (`adb shell pm grant com.gpm.expensemanager_app android.permission.POST_NOTIFICATIONS` como alternativa si el diálogo no es interactuable, o tap directo en "Allow").

Esperado: el switch queda activado tras conceder el permiso; si se deniega, aparece un snackbar de "notifications denied" y el switch vuelve a apagado.
Verificar: screenshot del diálogo de permiso y del estado final del switch. Probar ambos caminos (conceder / denegar) si el tiempo lo permite.

---

### [SET-09] Recordatorios recurrentes — desactivar
**Requiere:** ninguno · **Bloqueante conocido:** depende de SET-08 activado · **Severidad:** baja

Pasos:
1. Tap en el switch para desactivarlo.

Esperado: se desactiva inmediatamente.
Verificar: screenshot.

---

### [SET-10] Backup export desde Settings
**Requiere:** ninguno · **Bloqueante conocido:** referencia cruzada con TX-17 (mismo flujo, distinto punto de entrada) · **Severidad:** baja

Pasos:
1. Tap en "Backup Export" en Settings.
2. Elegir formato JSON o CSV.

Esperado: mismo comportamiento que TX-17 (share sheet nativo).
Verificar: screenshot del share sheet.

---

### [SET-11] Backup import desde Settings
**Requiere:** ninguno · **Bloqueante conocido:** referencia cruzada con TX-18/TX-19 · **Severidad:** baja

Pasos:
1. Tap en "Backup Import" en Settings.

Esperado: mismo flujo que TX-18 (file picker → preview → confirmar).
Verificar: no repetir el import completo si ya se hizo en la sección 04; basta con confirmar que el entry point abre el mismo flujo.

---

### [SET-12] Privacy Policy
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Tap en "Privacy Policy".

Esperado: se abre `LegalScreen` con contenido no vacío.
Verificar: screenshot del contenido.

---

### [SET-13] Terms of Service
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Tap en "Terms of Service".

Esperado: se abre `LegalScreen` con contenido distinto al de Privacy Policy.
Verificar: screenshot del contenido.

---

### [SET-14] Data recovery (solo build debug) — baja prioridad
**Requiere:** ninguno · **Bloqueante conocido:** solo visible si la app corre en modo debug (`kDebugMode`); si se está probando un build release, marcar `BLOCKED (no aplica en release)` · **Severidad:** baja

Pasos:
1. Si la fila "Recuperar datos locales" está visible en Settings, entrar.
2. Observar el escaneo automático de SQLite local.
3. NO tocar "Subir a la nube" salvo que el usuario lo pida explícitamente (escribe datos reales en Supabase).

Esperado: la pantalla escanea y muestra el conteo de transacciones/recurrentes locales sin error.
Verificar: screenshot de la pantalla tras el escaneo.
