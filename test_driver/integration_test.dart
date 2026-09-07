// ANDAMIAJE TEMPORAL — driver de la tanda de capturas de tienda.
//
// El trabajo de captura NO ocurre aquí: `integrationDriver` solo entrega los
// bytes de `takeScreenshot` cuando el test ya ha terminado, así que todas las
// imágenes saldrían con el estado final de la pantalla. En su lugar, el test
// deja una petición en un buzón dentro del contenedor de la app y el script
// `tool/screenshots/daemon.sh` —que corre en el host— captura con `simctl` en
// ese instante exacto (y con la barra de estado del sistema, que el plugin de
// iOS no dibuja).
//
// Uso: `bash tool/screenshots_ios.sh`.
//
// Borrar junto con el resto del andamiaje cuando termine la tanda.

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver();
}
