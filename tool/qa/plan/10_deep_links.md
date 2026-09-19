# 10 — Deep links del widget de home (`expensemanager://widget/*`)

Ejecutar dos veces: una con `E2E_FREE` logueada y otra con `E2E_PRO` (si el
fixture existe), ya que el comportamiento difiere por gating PRO.

**Comando correcto (importante)**: el botón real del widget (`HomeWidgetProvider.kt`)
lanza el intent vía `HomeWidgetLaunchIntent.getActivity()` del paquete
`home_widget`, cuya acción es `es.antonborri.home_widget.action.LAUNCH` — **no**
`android.intent.action.VIEW`. `HomeWidgetPlugin.kt` (`initiallyLaunchedFromHomeWidget`)
comprueba esa acción explícitamente, así que un `am start -a android.intent.action.VIEW
-d "expensemanager://..."` (que sí abre la app vía el intent-filter del
`AndroidManifest`, pero con la acción equivocada) nunca es reconocido como
"lanzado desde el widget" y no dispara ninguna acción — un falso `FAIL` ya
verificado una vez (2026-09-16). Usar siempre:
```bash
adb shell am start -a es.antonborri.home_widget.action.LAUNCH \
  -n com.gpm.expensemanager_app/.MainActivity \
  -d "expensemanager://widget/<add|voice|chat|photo>"
```

---

### [DL-01] `widget/add`
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Con la app en background o cerrada:
   ```bash
   adb shell am start -a es.antonborri.home_widget.action.LAUNCH \
     -n com.gpm.expensemanager_app/.MainActivity \
     -d "expensemanager://widget/add"
   ```

Esperado: abre la app y muestra directamente el sheet de añadir transacción (mismo comportamiento en FREE y PRO).
Verificar: screenshot del sheet abierto.

---

### [DL-02] `widget/voice`
**Requiere:** ninguno (FREE) / PRO · **Bloqueante conocido:** reconocimiento de voz real sigue `BLOCKED` · **Severidad:** media

Pasos:
1. ```bash
   adb shell am start -a es.antonborri.home_widget.action.LAUNCH \
     -n com.gpm.expensemanager_app/.MainActivity \
     -d "expensemanager://widget/voice"
   ```

Esperado FREE: redirige a `/pro`. Esperado PRO: intenta iniciar la escucha de voz (sin redirigir a `/pro`).
Verificar: screenshot en cada cuenta.

---

### [DL-03] `widget/chat`
**Requiere:** ninguno (FREE) / PRO · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. ```bash
   adb shell am start -a es.antonborri.home_widget.action.LAUNCH \
     -n com.gpm.expensemanager_app/.MainActivity \
     -d "expensemanager://widget/chat"
   ```

Esperado FREE: redirige a `/pro` (igual que PRO-05). Esperado PRO: abre `/chat` directamente.
Verificar: screenshot en cada cuenta.

---

### [DL-04] `widget/photo`
**Requiere:** ninguno (FREE) / PRO · **Bloqueante conocido:** foto real solo si el picker permite galería · **Severidad:** media

Pasos:
1. ```bash
   adb shell am start -a es.antonborri.home_widget.action.LAUNCH \
     -n com.gpm.expensemanager_app/.MainActivity \
     -d "expensemanager://widget/photo"
   ```

Esperado FREE: redirige a `/pro`. Esperado PRO: abre el selector de origen (cámara/galería), igual que PROB-05.
Verificar: screenshot en cada cuenta.
