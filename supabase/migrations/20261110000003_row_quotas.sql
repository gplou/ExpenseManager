-- ─────────────────────────────────────────────────────────────────────────────
-- Tope de filas por usuario (auditoría 2026-11-10)
-- ─────────────────────────────────────────────────────────────────────────────
-- El registro es abierto y RLS solo comprueba la propiedad de la fila: una
-- cuenta podía insertar millones de filas vía PostgREST hasta agotar la cuota
-- de disco del proyecto (denegación de servicio para todos los usuarios).
--
-- Los topes están MUY por encima del uso real (máx. actual: 77 transacciones
-- en una cuenta) — no son un límite de producto, solo un freno al abuso.
--
-- Trigger AFTER INSERT ... FOR EACH STATEMENT con tabla de transición: cuenta
-- una vez por sentencia y usuario (no una vez por fila), así que un upsert
-- masivo legítimo (hidratación / migración FREE→PRO) no paga un count por fila.
-- Si la sentencia deja al usuario por encima del tope, se aborta entera.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.enforce_user_row_quota()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_limit   integer := tg_argv[0]::integer;
  v_user_id uuid;
  v_count   bigint;
begin
  for v_user_id in select distinct user_id from new_rows loop
    execute format('select count(*) from public.%I where user_id = $1', tg_table_name)
       into v_count
      using v_user_id;
    if v_count > v_limit then
      raise exception 'row_quota_exceeded'
        using errcode = 'P0001',
              detail = format('%s: máximo %s filas por usuario', tg_table_name, v_limit);
    end if;
  end loop;
  return null;
end;
$$;

-- Solo la invocan los triggers; nadie necesita EXECUTE directo.
revoke all on function public.enforce_user_row_quota() from public, anon, authenticated;

create trigger transactions_row_quota
  after insert on public.transactions
  referencing new table as new_rows
  for each statement execute function public.enforce_user_row_quota('50000');

create trigger recurring_transactions_row_quota
  after insert on public.recurring_transactions
  referencing new table as new_rows
  for each statement execute function public.enforce_user_row_quota('1000');

create trigger budgets_row_quota
  after insert on public.budgets
  referencing new table as new_rows
  for each statement execute function public.enforce_user_row_quota('500');

create trigger subcategories_row_quota
  after insert on public.subcategories
  referencing new table as new_rows
  for each statement execute function public.enforce_user_row_quota('2000');

create trigger custom_categories_row_quota
  after insert on public.custom_categories
  referencing new table as new_rows
  for each statement execute function public.enforce_user_row_quota('500');
