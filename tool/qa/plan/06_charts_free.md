# 06 — Charts / Insights (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada, locale=en. Precondición
recomendada: sección 04 ejecutada (hay transacciones de varias categorías).

---

### [CHART-01] Toggle de modo Pie/Bar
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tab "Insights".
2. Tap en el modo "Pie" (si no está ya activo).
3. Tap en el modo "Bar".

Esperado: el gráfico cambia de representación sin error ni datos vacíos (dado que hay transacciones de la sección 04).
Verificar: screenshot de cada modo.

---

### [CHART-02] Selector de periodo
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tap en el botón de periodo (`chartsPeriodButton`).
2. Cambiar entre las opciones disponibles (semana/mes/año).

Esperado: el gráfico se recalcula para cada periodo.
Verificar: screenshot tras cada cambio.

---

### [CHART-03] El gráfico refleja las categorías usadas
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. En modo Pie, observar los segmentos/leyenda.

Esperado: aparecen las categorías usadas en la sección 04 ("Comida", "Transporte", etc.) con proporciones coherentes con los importes introducidos.
Verificar: screenshot con la leyenda visible, comparar mentalmente contra los importes conocidos de la sección 04.
