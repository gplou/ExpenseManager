# 03 — Dashboard y navegación (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada, locale=en. Estado de datos: sin
transacciones todavía (se crean en la sección 04) — algunos casos aquí
observan estados vacíos, otros se re-visitan tras 04/05 para ver datos
reales (indicado en cada caso).

---

### [DASH-01] Tabs inferiores preservan estado (IndexedStack)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en la tab "Activity". Hacer scroll si hay contenido.
2. Tap en "Budgets", luego en "Insights".
3. Volver a tap en "Activity".

Esperado: "Activity" conserva el scroll/estado en el que se dejó, no se resetea al volver.
Verificar: screenshot antes y después de volver a la tab.

---

### [DASH-02] Re-tap en la tab activa vuelve a su raíz
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Desde "Activity", navegar dentro de esa tab a una pantalla anidada (p.ej. abrir el sheet de editar una transacción, o si no hay datos, abrir el filtro).
2. Tap de nuevo en el icono "Activity" de la barra inferior.

Esperado: vuelve a la raíz de esa tab (cierra el sheet/sub-pantalla).
Verificar: screenshot mostrando el retorno a la lista raíz.

---

### [DASH-03] FAB central abre el sheet de añadir transacción
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Tap en el FAB central de la barra inferior.

Esperado: se abre un bottom sheet al ~94% de la altura con el formulario de añadir transacción (no navega de página completa).
Verificar: screenshot del sheet abierto; tap en "atrás" (`keyevent 4`) debe cerrarlo sin guardar.

---

### [DASH-04] Chips de periodo (Week/Month/Year)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en el chip "Week".
2. Tap en "Month".
3. Tap en "Year".

Esperado: el resumen (balance/gasto) y la lista de "recent transactions" se recalculan para cada rango sin crashear; el chip seleccionado se resalta.
Verificar: screenshot tras cada tap.

---

### [DASH-05] Rango de fechas personalizado
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en el icono de calendario (rango custom, `TestKeys.dashboardDateRangeButton` — documentación, no selector).
2. Elegir un rango, p.ej. 01/01/2026 a 28/02/2026.
3. Confirmar.

Esperado: el resumen refleja solo ese rango; los chips Week/Month/Year quedan deseleccionados.
Verificar: screenshot del selector y del resultado aplicado.

---

### [DASH-06] Pull-to-refresh
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. En el dashboard, hacer swipe hacia abajo desde la parte superior (`input swipe` con distancia y duración que dispare el refresh).

Esperado: aparece brevemente un indicador de carga y los datos se refrescan sin error.
Verificar: screenshot capturando el indicador (puede requerir dos capturas rápidas).
Si fluctúa (red): reintentar una vez el swipe si no se aprecia el indicador.

---

### [DASH-07] "View charts" navega a Insights
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Tap en el enlace/botón "View charts" de la sección de resumen.

Esperado: navega a `/charts` (o cambia a la tab Insights).
Verificar: screenshot de la pantalla de charts.

---

### [DASH-08] Accesos de la sección de presupuestos
**Requiere:** ninguno (repetir tras crear un presupuesto en 05 para ver el estado no-vacío) · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Estado vacío: tap en la fila/CTA vacía de presupuestos → debe ir a `/budgets`.
2. (Tras 05) Con un presupuesto creado: tap en "Manage" → `/budgets`; tap en el tile del presupuesto → `/budgets`.

Esperado: ambos casos navegan correctamente a Budgets.
Verificar: screenshot de cada navegación.

---

### [DASH-09] "See all" del historial reciente
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Tap en "See all" junto al listado de transacciones recientes.

Esperado: navega a `/transactions` (tab Activity) con la lista completa.
Verificar: screenshot.

---

### [DASH-10] Tap en una transacción reciente abre edición
**Requiere:** ninguno (requiere al menos una transacción — ejecutar tras 04) · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en cualquier tile de "recent transactions".

Esperado: se abre el sheet de edición con los datos de esa transacción precargados.
Verificar: screenshot del sheet con los valores correctos.

---

### [DASH-11] Upcoming Bills — verificar si es interactivo
**Requiere:** ninguno (requiere una transacción recurrente — ejecutar tras TX-09) · **Bloqueante conocido:** hallazgo de exploración: el widget soporta `onTap` pero `dashboard_screen.dart` no lo cablea — puede ser intencional (solo lectura) o un target de tap olvidado · **Severidad:** baja

Pasos:
1. Tap sobre la card "Upcoming Bills".

Esperado a confirmar en vivo: documentar si no pasa nada (comportamiento actual esperado según el código) o si navega a algún sitio. No es un FAIL si no hace nada — es una nota de producto a registrar en el informe, no un defecto asumido.
Verificar: screenshot antes/después del tap.

---

### [DASH-12] Drawer — orden e items
**Requiere:** ninguno · **Bloqueante conocido:** icono de "AI Chat" no debe aparecer en cuenta FREE · **Severidad:** media

Pasos:
1. Abrir drawer desde el icono gear.

Esperado: aparecen, en este orden aproximado: nombre/editar, change password, App Settings, Tutorial (reiniciar), fila de plan PRO (con CTA a `/pro`), Promo code, Logout, Delete account. Sin icono de chat en el AppBar del dashboard (solo visible para PRO).
Verificar: screenshot completo del drawer.

---

### [DASH-13] Reinicio manual del tutorial desde el drawer
**Requiere:** ninguno · **Bloqueante conocido:** usar este caso como precondición de `FR-09b` · **Severidad:** baja

Pasos:
1. Drawer → "Tutorial".

Esperado: el overlay de tutorial se reinicia desde el paso 1.
Verificar: screenshot del paso 1 reapareciendo.
