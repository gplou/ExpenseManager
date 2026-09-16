# 04 — Transacciones (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada, locale=en. Muchos casos aquí
son secuenciales (crean datos que usan casos posteriores) — se indica en
"Precondición extra" cuando aplica.

---

### [TX-01] Crear un gasto vía teclado numérico
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. FAB central → sheet de añadir transacción.
2. Tipo: "Expense" (por defecto).
3. Teclado numérico: introducir `17.50`.
4. Tap en la categoría "Comida" (o la primera disponible del strip rápido).
5. Tap en el botón de guardar/submit del teclado.

Esperado: el sheet se cierra, la transacción aparece en "recent transactions" del dashboard con -17.50€.
Verificar: screenshot del dashboard tras guardar.

---

### [TX-02] Crear un ingreso — el toggle de tipo resetea la categoría
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. FAB → sheet de añadir.
2. Tap en el toggle de tipo para cambiar a "Income".
3. Verificar que la categoría seleccionada se resetea (no queda una categoría de gasto preseleccionada).
4. Introducir `900` y elegir una categoría de ingreso (p.ej. "Salary").
5. Guardar.

Esperado: aparece un ingreso de +900€, categoría de ingreso correcta.
Verificar: screenshot antes de elegir categoría (para confirmar el reset) y después de guardar.

---

### [TX-03] Editar una transacción existente
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Precondición extra: usa la transacción creada en TX-01.

Pasos:
1. Tap en la tile de la transacción de TX-01.
2. Cambiar importe a `42.50` y categoría a "Transporte".
3. Guardar.

Esperado: la tile refleja 42.50€ y categoría "Transporte".
Verificar: screenshot tras guardar.

---

### [TX-04] Borrar transacción vía icono de papelera (modo edición)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Precondición extra: usa la transacción editada en TX-03.

Pasos:
1. Abrir esa transacción para editar.
2. Tap en el icono de papelera del AppBar.
3. Confirmar en el diálogo.

Esperado: la transacción desaparece de la lista/dashboard.
Verificar: screenshot post-borrado.

---

### [TX-05] Swipe-to-delete en la lista
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Precondición extra: crear una transacción rápida nueva primero (repetir TX-01 con otro importe, p.ej. 5.00).

Pasos:
1. Ir a la tab "Activity".
2. Swipe de derecha a izquierda sobre la tile de esa transacción.
3. Confirmar el diálogo de borrado.

Esperado: la transacción se elimina de la lista.
Verificar: screenshot antes/después del swipe y tras confirmar.

---

### [TX-06] Pill de fecha — cambiar fecha
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. FAB → sheet de añadir, introducir un importe cualquiera.
2. Tap en la pill de fecha → sheet rápido de fecha.
3. Elegir una fecha distinta a hoy (p.ej. hace 3 días).
4. Guardar la transacción.

Esperado: la transacción se guarda con la fecha elegida (visible en el detalle/lista si se agrupa por fecha).
Verificar: screenshot del detalle mostrando la fecha correcta.

---

### [TX-07] Pill de nota — añadir descripción
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. En el sheet de añadir, tap en la pill de nota.
2. Escribir "Compra de prueba QA".
3. Guardar la transacción.

Esperado: al reabrir esa transacción para editar, la nota persiste.
Verificar: screenshot mostrando la nota en el formulario de edición.

---

### [TX-08] Pill de subcategoría — crear una nueva
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. En el sheet de añadir, tap en la pill de subcategoría.
2. Usar la opción de crear subcategoría nueva, nombre "QA Sub".
3. Seleccionarla y guardar la transacción.

Esperado: la subcategoría "QA Sub" queda asociada y disponible para futuras transacciones de esa categoría.
Verificar: screenshot del picker mostrando "QA Sub" ya creada.

---

### [TX-09] Pill de recurrencia — marcar como mensual
**Requiere:** ninguno · **Bloqueante conocido:** el copy del diálogo de borrado debe ser distinto para recurrentes (usado también en DASH-11) · **Severidad:** media

Pasos:
1. En el sheet de añadir, tap en la pill de recurrencia.
2. Elegir "Monthly".
3. Guardar.
4. Volver a abrir esa transacción y tap en papelera → observar el texto del diálogo de confirmación.

Esperado: el diálogo de borrado menciona explícitamente que es una serie recurrente (copy distinto al de una transacción normal, ver TX-04).
Verificar: screenshot del diálogo con el copy recurrente. Cancelar el borrado al final para no perder el fixture de DASH-11.

---

### [TX-10] Crear categoría personalizada
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. En el sheet de añadir, abrir el picker completo de categorías ("more"/grid).
2. Tap en "+ new category", nombre "QA Categoria".
3. Seleccionarla y guardar una transacción con ella.

Esperado: la nueva categoría aparece en el grid y queda usable.
Verificar: screenshot del grid con la categoría nueva.

---

### [TX-10b] Renombrar una categoría personalizada
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Precondición extra: usa la categoría creada en TX-10.

Pasos:
1. En el picker de categorías, mantener pulsado o usar la acción de editar sobre "QA Categoria" (según cómo esté cableada la acción de renombrar).
2. Cambiar el nombre a "QA Categoria Renombrada".
3. Confirmar.

Esperado: el tile refleja el nuevo nombre; las transacciones ya creadas con la categoría antigua muestran el nombre actualizado (la categoría se guarda por referencia, no por copia del string en cada transacción — a confirmar en vivo).
Verificar: screenshot del grid con el nombre actualizado y de una transacción existente que la use.

---

### [TX-11] Ocultar/borrar una categoría personalizada
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Precondición extra: usa la categoría creada en TX-10.

Pasos:
1. En el picker de categorías, tap en la "x" del tile "QA Categoria".
2. Confirmar en el diálogo.

Esperado: la categoría deja de aparecer en el grid.
Verificar: screenshot del grid sin la categoría.

---

### [TX-12] Mic (voz) en cuenta FREE — verificar PRO-gate
**Requiere:** ninguno · **Bloqueante conocido:** la captura de voz real está `BLOCKED` (sin passthrough de audio) — este caso solo verifica el gating, no el reconocimiento · **Severidad:** alta

Pasos:
1. Tap en el icono de micrófono del AppBar (fuera de modo edición).

Esperado: al ser cuenta FREE, redirige a `/pro` (paywall) en vez de iniciar la escucha.
Verificar: screenshot de la pantalla `/pro` tras el tap.

---

### [TX-13] Cámara (foto) en cuenta FREE — verificar PRO-gate
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Tap en el icono de cámara del AppBar.

Esperado: redirige a `/pro` (paywall), igual que TX-12.
Verificar: screenshot de `/pro`.

---

### [TX-14] Búsqueda de transacciones (debounced)
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tab "Activity" → tap en icono de búsqueda.
2. Escribir "QA" (debe matchear notas/categorías creadas antes).
3. Esperar ~500ms (debounce de 300ms).

Esperado: la lista se filtra a las transacciones que contienen "QA".
Verificar: screenshot de la lista filtrada. Tap en "atrás" de la búsqueda debe restaurar la lista completa.

---

### [TX-15] Filtro por categoría
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Tab "Activity" → tap en el icono de filtro (embudo).
2. Elegir "Transporte" (o la categoría usada en TX-03).

Esperado: la lista muestra solo transacciones de esa categoría.
Verificar: screenshot de la lista filtrada.

---

### [TX-16] Selección múltiple y borrado masivo
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Precondición extra: crear al menos 2 transacciones rápidas nuevas antes (repetir TX-01 dos veces con importes distintos).

Pasos:
1. Long-press sobre una tile de la lista → entra en modo selección.
2. Tap en una segunda tile para añadirla a la selección.
3. Tap en "Delete N" (botón inferior).
4. Confirmar si aparece diálogo.

Esperado: ambas transacciones seleccionadas se eliminan, sale del modo selección.
Verificar: screenshot del modo selección con 2 marcadas, y de la lista tras el borrado.

---

### [TX-17] Exportar backup — se abre el selector de formato y el share sheet
**Requiere:** ninguno · **Bloqueante conocido:** no se puede completar el destino del share (fuera del control de la app) — basta con verificar que el sheet nativo de Android aparece · **Severidad:** baja

Pasos:
1. En la lista de transacciones, tap en "Export".
2. Elegir formato "JSON".
3. Observar que se abre el share sheet nativo de Android.
4. Cerrar el share sheet (`keyevent 4`) sin enviar a ningún destino.
5. Repetir con formato "CSV".

Esperado: ambos formatos generan un archivo y abren el share sheet sin error.
Verificar: screenshot del share sheet para cada formato.

---

### [TX-18] Importar backup JSON con preview de dedup
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. `adb push tool/qa/fixtures/import_sample.json /sdcard/Download/`.
2. En Settings (o desde la lista, según dónde esté el entry point), tap en "Import".
3. Seleccionar `import_sample.json` desde el file picker (carpeta Download).
4. Observar el diálogo de preview (cuenta de nuevas/duplicadas/inválidas).
5. Confirmar el import.

Esperado: preview muestra 2 nuevas, 0 duplicadas, 0 inválidas; tras confirmar, ambas transacciones (17.50€ "Comida" y 900€ "Salario") aparecen en la lista.
Verificar: screenshot del preview y de la lista tras importar.

---

### [TX-19] Importar backup CSV
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. `adb push tool/qa/fixtures/import_sample.csv /sdcard/Download/`.
2. Repetir el flujo de import con `import_sample.csv`.

Esperado: preview muestra 2 nuevas (5.30€ "Comida", 1.85€ "Transporte"); tras confirmar, aparecen en la lista.
Verificar: screenshot del preview y de la lista.

---

### [TX-20] Import — dedup al reimportar el mismo archivo
**Requiere:** ninguno · **Bloqueante conocido:** depende de TX-18 ejecutado antes · **Severidad:** media

Pasos:
1. Repetir el import de `import_sample.json` (ya importado en TX-18).
2. Observar el preview.

Esperado: preview muestra 0 nuevas, 2 duplicadas (misma fecha+importe+categoría+descripción); no se insertan copias.
Verificar: screenshot del preview mostrando el conteo de duplicadas; confirmar que la lista no tiene transacciones repetidas tras aceptar (o cancelar el import ya que no hay nada nuevo que aportar).
