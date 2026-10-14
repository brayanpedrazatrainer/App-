-- Calendario automático (2026-10-14)
-- Antes: el mes había que generarlo a mano; si no, el día 1 la clienta quedaba sin rutina.
-- Ahora cada clienta tiene siempre su calendario hasta el fin del mes siguiente:
--   * asegurar_calendario(clienta): la llama la app al abrir (solo para ella misma) y el admin.
--   * asegurar_calendario_todas(): la corre pg_cron todos los días a las 3 a. m. (Colombia) para las activas.
-- Usa generar_motor, que solo llena fechas vacías: no toca filas manuales ni ya generadas.

create or replace function public.asegurar_calendario(p_client uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_hoy   date := (now() at time zone 'America/Bogota')::date;
  v_hasta date := (date_trunc('month', (now() at time zone 'America/Bogota')::date) + interval '2 month' - interval '1 day')::date;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon')
     and auth.uid() is distinct from p_client and not public.is_admin() then
    raise exception 'Sin permiso';
  end if;
  return public.generar_motor(p_client, v_hoy, v_hasta);
end;
$$;

grant execute on function public.asegurar_calendario(uuid) to authenticated;

create or replace function public.asegurar_calendario_todas()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_total integer := 0; r record;
begin
  for r in select id from profiles
           where not coalesce(is_admin, false) and coalesce(estado, 'activa') = 'activa'
             and ancla is not null and ruta is not null
  loop
    v_total := v_total + public.asegurar_calendario(r.id);
  end loop;
  return v_total;
end;
$$;

-- Solo la tarea programada (y el SQL editor) la ejecuta
revoke execute on function public.asegurar_calendario_todas() from public, anon, authenticated;

create extension if not exists pg_cron;
select cron.schedule('asegurar-calendario', '0 8 * * *', $$select public.asegurar_calendario_todas()$$);  -- 08:00 UTC = 3:00 a. m. Colombia

-- Rollback:
-- select cron.unschedule('asegurar-calendario');
-- drop function if exists public.asegurar_calendario_todas();
-- drop function if exists public.asegurar_calendario(uuid);
