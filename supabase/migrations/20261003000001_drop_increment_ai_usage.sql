-- increment_ai_usage era SECURITY DEFINER, ejecutable por `authenticated` y
-- aceptaba un p_user_id arbitrario sin comprobar auth.uid(): cualquier usuario
-- logueado podía inflar los contadores de otro. Ni la app ni ninguna Edge
-- Function la llaman (la tabla ai_usage está vacía); el rate limiting real va
-- por increment_rate_limit. Se elimina en vez de parchearla.
drop function if exists public.increment_ai_usage(uuid, date, text);
