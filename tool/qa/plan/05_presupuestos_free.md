# 05 — Presupuestos (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada, locale=en. Precondición
recomendada: haber ejecutado la sección 04 (hay transacciones/categorías de
prueba disponibles).

---

### [BUD-01] Crear el primer presupuesto (permitido en FREE)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Tab "Budgets" → FAB "+".
2. Elegir categoría "Comida", importe `50`.
3. Guardar.

Esperado: el presupuesto aparece en la lista con progreso 0% (o el % correspondiente si ya hay gasto en "Comida" de la sección 04).
Verificar: screenshot de la lista de presupuestos.

---

### [BUD-02] Segundo presupuesto en FREE — dialog de límite
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Tab "Budgets" → FAB "+" de nuevo.

Esperado: en vez de abrir el formulario, aparece el diálogo de upgrade (límite FREE=1) con CTA a `/pro`.
Verificar: screenshot del diálogo. Tap en "Cancel"/cerrar sin ir a `/pro` (o seguir el CTA y verificar que aterriza en `/pro`, luego volver atrás).

---

### [BUD-03] Editar presupuesto existente
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en el tile del presupuesto de BUD-01.
2. Cambiar el importe a `80`.
3. Guardar.

Esperado: el tile refleja el nuevo importe y recalcula el % de progreso.
Verificar: screenshot tras guardar.

---

### [BUD-04] Alerta de progreso al 80%
**Requiere:** ninguno · **Bloqueante conocido:** requiere generar gasto real vía UI (no hay seed por código) · **Severidad:** media

Pasos:
1. Con el presupuesto de "Comida" en 80€ (de BUD-03), crear transacciones de gasto en "Comida" hasta sumar ≥64€ (80% de 80) pero <80€.
2. Volver al dashboard (donde se dispara `ref.listen` de `BudgetAlerts`).

Esperado: aparece un snackbar de alerta de 80% una sola vez.
Verificar: screenshot del snackbar. Volver a refrescar el dashboard (pull-to-refresh) y confirmar que el snackbar NO vuelve a aparecer (dedup por budget+mes+umbral).

---

### [BUD-05] Alerta de progreso al 100%
**Requiere:** ninguno · **Bloqueante conocido:** depende de BUD-04 · **Severidad:** media

Pasos:
1. Añadir más gasto en "Comida" hasta superar 80€ (100%+).
2. Volver al dashboard.

Esperado: snackbar de alerta de 100% (distinto del de 80%), una sola vez.
Verificar: screenshot del snackbar; el tile del presupuesto debe mostrar "+exceso" en vez de "restante".

---

### [BUD-06] Colores de la barra de progreso
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Observar el tile del presupuesto de "Comida" (ya en >100% tras BUD-05).
2. Si es posible, crear un segundo presupuesto temporal (borrar el de BUD-01 primero, dado el límite FREE=1) con gasto <80% para comparar color.

Esperado: <80% color "accent", 80-100% color de "warning", >100% color "negative"/error.
Verificar: screenshot comparando ambos estados de color.

---

### [BUD-07] Borrar presupuesto
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en el icono de papelera del tile del presupuesto.
2. Confirmar en el diálogo.

Esperado: el presupuesto desaparece de la lista; el dashboard vuelve a mostrar el estado vacío/CTA de presupuestos.
Verificar: screenshot tras el borrado.
