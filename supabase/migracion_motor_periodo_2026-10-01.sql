-- Migración "motor_periodo" (2026-10-01)
-- Cuando una clienta marca "Me llegó el período", sus sesiones futuras generadas por el motor se recalculan.
-- Regla de oro: solo se tocan filas con origen='motor' y status 'pending'. Las manuales y las completadas no.
-- Rollback: rollback_motor_periodo_2026-10-01.sql

-- 1. Origen de cada fila. Todo lo anterior queda como 'manual'.
alter table public.scheduled_sessions add column if not exists origen text not null default 'manual';
-- Octubre 2026 lo generó el motor (generar_octubre_2026.sql); no había filas desde esa fecha antes.
update public.scheduled_sessions set origen = 'motor' where scheduled_date >= '2026-10-01';

-- 2. Genera los días que falten entre p_desde y p_hasta (no toca días que ya tienen fila)
create or replace function public.generar_motor(p_client uuid, p_desde date, p_hasta date)
 returns integer language plpgsql security definer set search_path = public as $function$
declare v_n integer;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon')
     and auth.uid() is distinct from p_client and not public.is_admin() then
    raise exception 'Sin permiso';
  end if;
  if p_hasta - p_desde > 92 then
    raise exception 'Rango máximo: 3 meses';
  end if;

  with cl as (
    select id, ruta, coalesce(duracion_ciclo, 28) dur, ancla, dias_presenciales
    from profiles where id = p_client and ancla is not null and ruta is not null
  ), y as (
    select cl.*, d.f::date f,
      case when ruta = 'energia' then ((d.f::date - ancla) % 28) + 1
           else ((d.f::date - ancla) % dur) + 1 end dc
    from cl cross join generate_series(p_desde, p_hasta, '1 day') d(f)
    where d.f >= ancla
  ), z as (
    select y.*, case
      when ruta = 'energia' then 'semana_' || ceil(dc / 7.0)::int
      when dc <= 5 then 'luna_nueva' when dc <= dur - 15 then 'creciente' when dc <= dur - 12 then 'llena'
      when dc <= dur - 5 then 'menguante_a' else 'menguante_b' end fase
    from y
  ), w as (
    select z.*, case
      when ruta = 'energia' then ((dc - 1) % 7) + 1
      when fase = 'luna_nueva' then ((dc - 1) % 5) + 1
      when fase = 'creciente' then ((dc - 6) % 8) + 1
      when fase = 'llena' then ((dc - (dur - 14)) % 3) + 1
      when fase = 'menguante_a' then ((dc - (dur - 11)) % 7) + 1
      else ((dc - (dur - 4)) % 5) + 1 end orden
    from z
  )
  insert into scheduled_sessions (client_id, scheduled_date, session_id, status, session_mode, origen)
  select w.id, w.f, t.session_id, 'pending',
    case when (array['dom','lun','mar','mie','jue','vie','sab'])[extract(dow from w.f)::int + 1]
              = any(coalesce(w.dias_presenciales, '{}'))
         then 'Con Brayan' else 'Sesión Reina' end,
    'motor'
  from w
  join plantillas p on p.ruta = w.ruta and p.activa
  join plantilla_tarjetas t on t.plantilla_id = p.id and t.fase = w.fase and t.orden = w.orden
  where t.session_id is not null
    and not exists (select 1 from scheduled_sessions s where s.client_id = w.id and s.scheduled_date = w.f);
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;

-- 3. Recalcula desde p_desde hasta la última fecha ya generada por el motor
create or replace function public.regenerar_motor(p_client uuid, p_desde date)
 returns integer language plpgsql security definer set search_path = public as $function$
declare v_hasta date;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon')
     and auth.uid() is distinct from p_client and not public.is_admin() then
    raise exception 'Sin permiso';
  end if;
  select max(scheduled_date) into v_hasta
  from scheduled_sessions where client_id = p_client and origen = 'motor';
  if v_hasta is null or v_hasta < p_desde then return 0; end if;
  delete from scheduled_sessions
  where client_id = p_client and origen = 'motor' and coalesce(status, 'pending') = 'pending'
    and scheduled_date between p_desde and v_hasta;
  return public.generar_motor(p_client, p_desde, v_hasta);
end;
$function$;

revoke execute on function public.generar_motor(uuid, date, date) from public, anon;
revoke execute on function public.regenerar_motor(uuid, date) from public, anon;
grant execute on function public.generar_motor(uuid, date, date) to authenticated;
grant execute on function public.regenerar_motor(uuid, date) to authenticated;
