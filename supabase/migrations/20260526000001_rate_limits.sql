-- ─────────────────────────────────────────────────────────────────────────────
-- Rate Limits
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.rate_limits (
  user_id      uuid        not null references auth.users(id) on delete cascade,
  endpoint     text        not null,
  window_start timestamptz not null,
  count        integer     not null default 1,
  primary key (user_id, endpoint, window_start)
);

-- No direct client access — only the SECURITY DEFINER function may write.
revoke all on public.rate_limits from anon, authenticated;
alter table public.rate_limits enable row level security;

create or replace function public.increment_rate_limit(
  p_user_id    uuid,
  p_endpoint   text,
  p_window_start timestamptz,
  p_limit      integer
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  -- Callers may only check their own rate limit bucket.
  if (select auth.uid()) <> p_user_id then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  insert into public.rate_limits (user_id, endpoint, window_start, count)
  values (p_user_id, p_endpoint, p_window_start, 1)
  on conflict (user_id, endpoint, window_start)
  do update set count = rate_limits.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;

revoke all on function public.increment_rate_limit(uuid, text, timestamptz, integer) from public;
grant execute on function public.increment_rate_limit(uuid, text, timestamptz, integer) to authenticated;

-- Housekeeping: remove expired windows (run via pg_cron or a service_role call).
create or replace function public.cleanup_rate_limits()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.rate_limits
   where window_start < now() - interval '1 hour';
end;
$$;

revoke all on function public.cleanup_rate_limits() from public, authenticated;
grant execute on function public.cleanup_rate_limits() to service_role;
