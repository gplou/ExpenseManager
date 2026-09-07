# Capturas de pantalla — iOS (App Store)

34 capturas generadas el 2026-08-03 en el simulador.

- **Formato:** PNG **1320 × 2868**, que es exactamente el tamaño de 6,9" que pide
  App Store Connect (el otro válido es 1290 × 2796). No hace falta reescalar
  nada, a diferencia de la tanda de Android.
- **Dispositivo:** simulador iPhone 17 Pro Max, iOS 26.5.
- **Idioma:** español. La app también está en inglés, francés y alemán
  (`22-idioma.png`); para las fichas de esos mercados hay que repetir la tanda
  cambiando `kLocaleKey` en `tool/screenshots/screenshots_test.dart`.
- **Barra de estado:** el 9:41 canónico de Apple, batería llena y cobertura
  completa, fijados con `simctl status_bar override`. **No** hay retoque en
  post-proceso (en Android sí hubo que repintarla).
- **Datos:** cuenta de demo con 12 meses de historial sembrados en la SQLite
  local. Las cifras son deterministas: repetir la tanda el mismo día da los
  mismos números.

## Índice

| # | Archivo | Qué muestra |
| --- | --- | --- |
| 01 | `01-login.png` | Inicio de sesión (email, Google, Apple) |
| 02 | `02-registro.png` | Alta de cuenta |
| 03 | `03-dashboard-mes.png` | **Pantalla principal**: balance, presupuestos, recientes, FAB de voz/foto |
| 04 | `04-dashboard-semana.png` | Mismo dashboard, periodo semanal |
| 05 | `05-dashboard-anual.png` | Periodo anual (€18.051 ingresos / €14.605 gastos) |
| 06 | `06-rango-personalizado.png` | Selector de rango de fechas a medida |
| 07 | `07-graficos-tarta-gastos.png` | Gráfico de anillo de gastos por categoría |
| 08 | `08-graficos-desglose.png` | Desglose con porcentajes e importes |
| 09 | `09-graficos-barras.png` | Vista de barras |
| 10 | `10-graficos-ingresos.png` | Los mismos gráficos sobre ingresos |
| 11 | `11-graficos-anual.png` | Gráficos del año completo |
| 12 | `12-presupuestos.png` | Presupuestos mensuales con progreso por categoría |
| 13 | `13-presupuesto-nuevo.png` | Alta de presupuesto (categoría + límite) |
| 14 | `14-historial.png` | Historial agrupado por día + exportar a Excel |
| 15 | `15-historial-filtros.png` | Filtro por categoría |
| 16 | `16-historial-busqueda.png` | Búsqueda de texto |
| 17 | `17-nueva-transaccion.png` | Alta manual: teclado propio, categorías, recurrencia |
| 18 | `18-editar-transaccion.png` | Edición de una transacción existente |
| 19 | `19-chat-ia.png` | Asesor financiero con IA (pantalla inicial) |
| 20 | `20-menu.png` | Menú lateral (cuenta, PRO, tutorial) |
| 21 | `21-ajustes.png` | Ajustes: tema, idioma, moneda, formato, bloqueo, recordatorios, copias |
| 22 | `22-idioma.png` | Selector de idioma (es/en/fr/de) |
| 23 | `23-moneda.png` | Selector de moneda |
| 24 | `24-plan-pro.png` | Paywall: qué incluye PRO |
| 25 | `25-oscuro-dashboard.png` | **Modo oscuro** — dashboard |
| 26 | `26-oscuro-graficos.png` | Modo oscuro — gráficos |
| 27 | `27-oscuro-ajustes.png` | Modo oscuro — ajustes |
| 28 | `28-tutorial-invitacion.png` | Invitación al tour en el primer arranque |
| 29-34 | `29-tutorial-1.png` … `34-tutorial-6.png` | Los 6 pasos del tutorial |

## Selección sugerida para la ficha

App Store muestra las 3 primeras en los resultados de búsqueda, y hasta 10 en la
ficha:

1. `03-dashboard-mes.png` — el resumen, lo que vende la app
2. `07-graficos-tarta-gastos.png` — analítica
3. `12-presupuestos.png` — presupuestos con progreso
4. `17-nueva-transaccion.png` — lo rápido que es registrar
5. `19-chat-ia.png` — el gancho de IA
6. `14-historial.png` — historial + exportar a Excel
7. `25-oscuro-dashboard.png` — modo oscuro
8. `24-plan-pro.png` — qué aporta PRO

## Qué NO está capturado y por qué

- **Dictado por voz** y **foto de recibo**: el simulador no trae motor de
  reconocimiento de voz ni cámara real. Requiere un dispositivo físico.
- **Chat de IA con respuesta**: la Edge Function valida la suscripción en el
  **servidor**, así que forzar PRO en el cliente no la desbloquea (devuelve
  `PRO subscription required`). Requiere una cuenta realmente PRO.
- **Precios del paywall**: los sirve RevenueCat vía StoreKit y en el simulador no
  hay tienda, así que la mitad inferior de `/pro` sale con los botones vacíos.
  Por eso solo está la parte de arriba (`24-plan-pro.png`).

## Cómo regenerarlas

```bash
bash tool/screenshots_ios.sh            # iPhone 17 Pro Max por defecto
bash tool/screenshots_ios.sh <udid>     # otro simulador
```

El script arranca el simulador, fija la barra de estado, y hace dos pasadas
(tema claro y tema oscuro) conduciendo la app con
`tool/screenshots/screenshots_test.dart`. Ver
[`tool/screenshots/README.md`](../../tool/screenshots/README.md) para cómo
funciona y qué hay que borrar cuando el andamiaje ya no haga falta.
