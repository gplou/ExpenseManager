# 02 — Auth y gestión de cuenta (FREE)

Cuenta activa al entrar: `E2E_FREE` logueada, locale=en (continúa de la
sección 01). Estado de datos: sin transacciones/presupuestos todavía.

---

### [AUTH-01] Logout — cancelar el diálogo de confirmación
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** media

Pasos:
1. Abrir drawer → tap en "Logout".
2. En el diálogo de confirmación, tap en "Cancel".

Esperado: permanece logueado, el drawer se cierra o queda como estaba, no navega a Login.
Verificar: screenshot mostrando que sigue en dashboard/drawer.

---

### [AUTH-02] Logout — confirmar
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** alta

Pasos:
1. Abrir drawer → "Logout" → confirmar en el diálogo.

Esperado: navega a `/login`, sesión cerrada.
Verificar: screenshot de la pantalla de Login.

---

### [AUTH-03] Re-login con E2E_FREE
**Requiere:** FREE · **Bloqueante conocido:** — · **Severidad:** alta

Precondición extra: ejecutar justo después de AUTH-02.

Pasos:
1. Login con las credenciales de `E2E_FREE`.

Esperado: vuelve al dashboard (sin volver a mostrar onboarding/tutorial — ya se marcaron como vistos).
Verificar: screenshot del dashboard, confirmar que NO reaparece el prompt de tutorial de FR-07.

---

### [AUTH-04] Editar nombre de usuario
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Pasos:
1. Abrir drawer → tap en la fila de nombre/perfil (abre bottom sheet).
2. Cambiar el texto a "QA Tester".
3. Tap en "Save".

Esperado: el drawer refleja "QA Tester" inmediatamente.
Verificar: screenshot del drawer con el nuevo nombre.

---

### [AUTH-05] Cambiar contraseña — solo apertura del diálogo
**Requiere:** ninguno · **Bloqueante conocido:** completar el reset real es `REQUIERE HUMANO` (depende de bandeja de correo) · **Severidad:** baja

Pasos:
1. Abrir drawer → "Change password".
2. En el diálogo de confirmación, tap en "Cancel" (no completar el flujo).

Esperado: el diálogo se abre con el texto esperado y se cierra limpiamente al cancelar, sin efectos secundarios.
Verificar: screenshot del diálogo.

---

### [AUTH-06] Toggle de visibilidad de contraseña en Login
**Requiere:** ninguno · **Bloqueante conocido:** — · **Severidad:** baja

Precondición extra: hacer logout primero (o ejecutar antes de AUTH-03 si se reordena).

Pasos:
1. En Login, escribir cualquier texto en el campo password.
2. Tap en el icono de ojo.

Esperado: el texto pasa de oculto a visible y viceversa al volver a tocar.
Verificar: dos screenshots (oculto/visible) comparando el campo.

---

### [AUTH-07] REQUIERE HUMANO — Forgot password (envío real de email)
**Requiere:** REQUIERE HUMANO · **Bloqueante conocido:** necesita acceso a la bandeja de correo de `E2E_FREE` para confirmar la recepción · **Severidad:** baja

Se salta por defecto (`SKIPPED`) en modo autónomo. Si el usuario lo pide
explícitamente: tap en "Forgot password" en Login con el email de
`E2E_FREE` ya escrito, confirmar que no aparece error de inmediato, y pedir
al usuario que confirme fuera de banda si llegó el correo.
