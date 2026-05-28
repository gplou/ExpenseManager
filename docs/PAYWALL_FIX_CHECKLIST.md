# Paywall Security Fix — Checklist de Activación

> **Contexto:** El cliente Flutter ya no llama a `apply_rc_entitlement` directamente.
> Ahora solo lee el estado desde Supabase. El webhook de RevenueCat es el único
> escritor autorizado de suscripciones de tienda.
>
> Este checklist describe los pasos que quedan para sellar completamente la
> vulnerabilidad (revocar acceso público a la función SQL).

---

## Estado actual

| Paso | Estado |
|---|---|
| Cliente Flutter deja de llamar `apply_rc_entitlement` | ✅ Hecho (este PR) |
| Secret del webhook corregido en Supabase | ⏳ Pendiente |
| Webhook probado con compra sandbox | ⏳ Pendiente |
| Migración SQL de revocación aplicada | ⏳ Pendiente |

---

## Paso 1 — Corregir el nombre del secret en Supabase

El webhook lee la variable de entorno con este nombre exacto:

```
REVENUECAT_WEBHOOK_SECRET
```

(ver `supabase/functions/revenuecat-webhook/index.ts` línea 21)

Si el secret en Supabase tiene un nombre distinto, el webhook devuelve
`500 server misconfigured` en cada llamada de RevenueCat, lo que significa que
**ninguna suscripción de tienda está siendo registrada en Supabase**.

### Opciones

**Opción A — Renombrar el secret en Supabase (recomendado)**

1. Ir a [Supabase Dashboard](https://supabase.com/dashboard) → tu proyecto → **Edge Functions** → **Secrets**
2. Borrar el secret con el nombre incorrecto
3. Crear uno nuevo con el nombre exacto: `REVENUECAT_WEBHOOK_SECRET`
4. Pegar el mismo valor (el token largo que está configurado en el dashboard de RevenueCat)

**Opción B — Actualizar el código del webhook**

Editar `supabase/functions/revenuecat-webhook/index.ts` línea 21:

```typescript
// Cambiar esto:
const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ?? ''

// Por el nombre real de tu secret, p.ej.:
const WEBHOOK_SECRET = Deno.env.get('RC_WEBHOOK_SECRET') ?? ''
```

Luego re-desplegar la función:

```bash
supabase functions deploy revenuecat-webhook
```

---

## Paso 2 — Verificar que el webhook está configurado en RevenueCat

1. Ir a [RevenueCat Dashboard](https://app.revenuecat.com) → tu proyecto → **Integrations** → **Webhooks**
2. Confirmar que la URL apunta a:
   ```
   https://<tu-project-ref>.supabase.co/functions/v1/revenuecat-webhook
   ```
3. Confirmar que el **Authorization** header usa el mismo valor que el secret `REVENUECAT_WEBHOOK_SECRET`
4. Usar el botón **"Send test event"** del dashboard de RC → debe responder `200 OK`

Si responde `500 server misconfigured` → el Paso 1 no está completo.

---

## Paso 3 — Probar con una compra sandbox

1. En iOS: usar una cuenta de sandbox de Apple (Settings → App Store → Sandbox Account)
2. En Android: usar una cuenta de tester configurada en Google Play Console
3. Hacer la compra PRO desde la app
4. Esperar ~10 segundos y verificar en **Supabase → Table Editor → subscriptions**
   que aparece una fila con `expires_at` en el futuro y `source = 'app_store'` o `'play_store'`

Si la fila no aparece:
- Revisar **Supabase → Edge Functions → revenuecat-webhook → Logs**
- Un log de error con `server misconfigured` indica el Paso 1 incompleto
- Un log de error con `invalid authorization` indica que el token en RC no coincide con el secret

---

## Paso 4 — Aplicar la migración SQL (revocar acceso)

Una vez confirmado que el webhook funciona (Paso 3 exitoso), ejecutar en
**Supabase → SQL Editor**:

```sql
revoke execute on function public.apply_rc_entitlement(timestamptz, text, text)
  from authenticated;
```

El archivo de migración ya existe en el repo:
`supabase/migrations/20260528000001_lock_apply_rc_entitlement.sql`

Después de ejecutarlo, verificar:

```sql
-- Debe devolver 0 filas (ningún privilegio para authenticated)
select grantee, privilege_type
from information_schema.routine_privileges
where routine_name = 'apply_rc_entitlement'
  and grantee = 'authenticated';
```

---

## Paso 5 — Prueba de regresión de seguridad

Intentar el bypass directamente con un JWT de usuario:

```bash
curl -X POST \
  'https://<tu-project-ref>.supabase.co/rest/v1/rpc/apply_rc_entitlement' \
  -H 'apikey: <anon-key>' \
  -H 'Authorization: Bearer <jwt-de-usuario-real>' \
  -H 'Content-Type: application/json' \
  -d '{"p_expires_at": "2027-01-01T00:00:00Z", "p_source": "unknown", "p_store_tx_id": "fake-123"}'
```

**Resultado esperado:** `{"code":"42501","details":null,"hint":null,"message":"permission denied for function apply_rc_entitlement"}`

Si devuelve `200` con datos → la migración del Paso 4 no se aplicó correctamente.

---

## Notas adicionales

- El cliente Flutter ya aplica el estado PRO de forma optimista tras la compra
  (mostrando PRO inmediatamente) y luego verifica en background cada 5 segundos
  hasta que la fila aparece en Supabase (máx. 50 segundos de espera).
- Si el webhook nunca llega, el usuario ve PRO solo hasta que reinicia la app
  (el cache expira). Esto es el comportamiento correcto — sin pago real, no hay
  confirmación permanente.
- El trial gratuito y los promo codes siguen funcionando por su propia vía
  (`start_free_trial` y `redeem_promo_code` son RPCs separados que solo puede
  llamar el usuario para sí mismo, con validación server-side).
