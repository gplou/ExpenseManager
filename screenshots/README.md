# Capturas de pantalla — Expense Manager

37 capturas de la app en Android, generadas el 2026-07-31.

- **Formato:** PNG 1080×1920 (9:16 exacto — válido para el listado de teléfono
  de Google Play, que exige entre 16:9 y 2:1). El emulador es 1080×2424 (2.24:1)
  y **habría sido rechazado**, así que se forzó `wm size 1080x1920` antes de capturar.
- **Dispositivo:** emulador Pixel 10 (Android 16, arm64), densidad 420.
- **Idioma:** español. La app también está en inglés, francés y alemán
  (`24-idioma.png`) — para las fichas de esos mercados hay que repetir la tanda
  cambiando el idioma en Ajustes.
- **Barra de estado:** repintada en post-proceso. El emulador dibujaba iconos de
  notificación de Google (Play Protect, Photos) y un wifi duplicado del modo demo;
  ninguno debía salir en material de tienda.

## Índice

| # | Archivo | Qué muestra |
| --- | --- | --- |
| 01 | `01-login.png` | Inicio de sesión (email + Google) |
| 02 | `02-registro.png` | Alta de cuenta |
| 03 | `03-dashboard-mes.png` | **Pantalla principal**: balance, presupuestos, FAB de voz/foto |
| 04 | `04-dashboard-semana.png` | Mismo dashboard, periodo semanal |
| 05 | `05-dashboard-anual.png` | Periodo anual (€19.595 ingresos / €9.981 gastos) |
| 06 | `06-dashboard-recientes.png` | Scroll: presupuestos + últimas transacciones |
| 07 | `07-selector-periodo.png` | Semana / Mes / Año / Rango personalizado |
| 08 | `08-graficos-tarta-gastos.png` | Gráfico de tarta de gastos por categoría |
| 09 | `09-graficos-desglose.png` | Desglose con porcentajes e importes |
| 10 | `10-graficos-barras.png` | Vista de barras |
| 11 | `11-graficos-ingresos.png` | Los mismos gráficos sobre ingresos |
| 12 | `12-graficos-anual.png` | Gráficos del año completo |
| 13 | `13-presupuestos.png` | Presupuestos mensuales con progreso por categoría |
| 14 | `14-presupuesto-nuevo.png` | Alta de presupuesto (categoría + límite) |
| 15 | `15-historial.png` | Historial agrupado por día + exportar a Excel |
| 16 | `16-historial-filtros.png` | Filtro por categoría |
| 17 | `17-historial-busqueda.png` | Búsqueda de texto |
| 18 | `18-nueva-transaccion.png` | Alta manual: teclado propio, categorías, recurrencia |
| 19 | `19-editar-transaccion.png` | Edición de una transacción existente |
| 20 | `20-chat-ia.png` | Asesor financiero con IA (pantalla inicial) |
| 21 | `21-menu.png` | Menú lateral (cuenta, PRO, tutorial) |
| 22 | `22-ajustes.png` | Ajustes: tema, idioma, moneda, formato, bloqueo, recordatorios |
| 23 | `23-ajustes-copias.png` | Copia de seguridad, importar, legal |
| 24 | `24-idioma.png` | Selector de idioma (es/en/fr/de) |
| 25 | `25-moneda.png` | Selector de moneda |
| 26 | `26-plan-pro.png` | Paywall: qué incluye PRO |
| 27 | `27-plan-pro-precio.png` | Prueba de 3 días y precio mensual |
| 28 | `28-oscuro-dashboard.png` | **Modo oscuro** — dashboard |
| 29 | `29-oscuro-graficos.png` | Modo oscuro — gráficos |
| 30 | `30-oscuro-ajustes.png` | Modo oscuro — ajustes |
| 31 | `31-tutorial-invitacion.png` | Invitación al tour al primer arranque |
| 32-37 | `32-tutorial-1.png` … `37-tutorial-6.png` | Los 6 pasos del tutorial |

## Selección sugerida para la ficha de tienda

Google Play muestra las 8 primeras y solo las 2-3 primeras se ven sin deslizar:

1. `03-dashboard-mes.png` — el resumen, lo que vende la app
2. `08-graficos-tarta-gastos.png` — analítica
3. `13-presupuestos.png` — presupuestos con progreso
4. `18-nueva-transaccion.png` — lo rápido que es registrar
5. `20-chat-ia.png` — el gancho de IA
6. `15-historial.png` — historial + exportar a Excel
7. `28-oscuro-dashboard.png` — modo oscuro
8. `26-plan-pro.png` — qué aporta PRO

## Qué NO está capturado y por qué

- **Dictado por voz** y **foto de recibo**: el emulador no trae motor de
  reconocimiento de voz ni cámara real, así que la hoja de escucha no llega a
  abrirse. Requiere un dispositivo físico.
- **Chat de IA con respuesta**: la Edge Function valida la suscripción en el
  **servidor**, así que forzar PRO en el cliente no la desbloquea
  (devuelve `PRO subscription required`). Requiere una cuenta realmente PRO.

## Cómo regenerarlas

Las capturas se tomaron con un modo de andamiaje temporal (`SCREENSHOT_MODE`)
que desbloqueaba la UI PRO y sembraba datos de demo en el SQLite local, sin
tocar Supabase. Ese andamiaje **ya no está en el código**; para repetir la tanda
hay que reintroducirlo (ver el informe de la sesión) o usar una cuenta PRO real.
