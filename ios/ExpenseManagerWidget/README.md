# Widget iOS (A7) — pasos manuales en Xcode

El código Swift del widget ya está escrito (`ExpenseManagerWidget.swift`), pero
crear el target de extensión, el App Group y el signing **requiere Xcode**.
Son ~10 minutos:

## 1. Crear el target

1. Abre `ios/Runner.xcworkspace` en Xcode.
2. File → New → Target… → **Widget Extension**.
3. Product Name: `ExpenseManagerWidget` (exacto — debe coincidir con el
   `iOSName` de `lib/core/services/home_widget_gateway.dart` y con el `kind`
   del Swift).
4. Desmarca "Include Configuration App Intent" (usamos StaticConfiguration).
5. "Activate scheme": sí.

## 2. Sustituir el código generado

1. Borra el contenido del `ExpenseManagerWidget.swift` que genera Xcode (y el
   archivo `*Bundle.swift`/`*Liveactivity.swift` si los crea).
2. Reemplázalo con el contenido de `ios/ExpenseManagerWidget/ExpenseManagerWidget.swift`
   (este directorio). Puedes arrastrar este archivo al grupo del target y
   eliminar el generado.

## 3. App Group (en ambos targets)

1. Target **Runner** → Signing & Capabilities → + Capability → App Groups →
   añade `group.com.gpm.expensemanagerapp` (es el id que ya usa
   `HomeWidget.setAppGroupId` en `lib/main.dart`).
2. Target **ExpenseManagerWidget** → igual, mismo grupo.
3. Esto requiere que el App Group exista en el Apple Developer portal
   (Identifiers → App Groups) y que los perfiles de aprovisionamiento de
   ambos bundle ids lo incluyan. Con "Automatically manage signing" Xcode lo
   hace solo.

## 4. Deployment target

Pon el iOS Deployment Target del widget igual o superior al de Runner
(mínimo iOS 14, recomendado igualar al de Runner para evitar warnings).

## 5. Probar

1. `cd ios && pod install` (por las deps nuevas de la fase 3).
2. Ejecuta el scheme del widget en un simulador/dispositivo, o ejecuta la app,
   añade una transacción y comprueba que el widget muestra Gastado/Balance.
3. La app repinta el widget tras cada CRUD/sync vía
   `homeWidgetDataSyncProvider` → `HomeWidget.updateWidget(iOSName: 'ExpenseManagerWidget')`.

## Notas

- Claves leídas del App Group: `month_spent` y `balance` (strings ya
  formateados desde Dart; el widget no formatea nada).
- Al cerrar sesión la app borra ambas claves y el widget muestra el estado
  vacío ("Abre la app para ver tus datos").
- Textos del widget en español (coherente con el widget Android, cuyos labels
  también son solo-español de momento).
