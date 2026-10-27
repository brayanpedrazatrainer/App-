-- Motor adaptativo (2026-10-27, aprobado por Brayan)
-- La sesión del día se decide con el ciclo (techo e intención) + lo que ella registra: check-in, días seguidos
-- entrenados, días sin entrenar y cuántas veces subió por "Encendida" en la semana. La decisión la calcula la app
-- (decidirSesionHoy) y la guarda con ajustar_sesion_hoy, que solo toca la fila de HOY generada por el motor,
-- pendiente y sin series marcadas. Las filas manuales nunca se tocan (regla de oro).
-- session_original: lo que el calendario había puesto. ajuste: por qué se cambió.

alter table public.scheduled_sessions add column if not exists session_original uuid;
alter table public.scheduled_sessions add column if not exists ajuste text;

create or replace function public.ajustar_sesion_hoy(p_session uuid, p_ajuste text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  v_uid uuid := auth.uid();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  r record; v_ruta text;
begin
  if v_uid is null then raise exception 'Sin sesión'; end if;
  select * into r from scheduled_sessions where client_id = v_uid and scheduled_date = v_hoy for update;
  if not found then return 'sin_fila'; end if;
  if coalesce(r.origen,'manual') <> 'motor' then return 'manual'; end if;
  if coalesce(r.status,'pending') <> 'pending' then return 'hecha'; end if;
  select ruta into v_ruta from profiles where id = v_uid;
  -- La sesión nueva debe ser del motor de su ruta
  if not exists (select 1 from plantilla_tarjetas t join plantillas p on p.id = t.plantilla_id
                 where t.session_id = p_session and p.ruta = v_ruta and p.activa) then
    raise exception 'Sesión no válida';
  end if;
  if p_ajuste is not null and p_ajuste not in ('rojo','amarillo','encendida','recuperacion_4','vuelta_media','vuelta_larga',
                                                'sin_entreno_recup','freno','peri_freno') then
    raise exception 'Ajuste no válido';
  end if;
  update scheduled_sessions
     set session_original = coalesce(session_original, session_id),
         session_id = p_session,
         ajuste = case when p_session = coalesce(session_original, session_id) then null else p_ajuste end
   where id = r.id;
  return 'ok';
end; $$;

revoke execute on function public.ajustar_sesion_hoy(uuid, text) from public, anon;
grant execute on function public.ajustar_sesion_hoy(uuid, text) to authenticated;

-- Al regenerar (período marcado), las filas pendientes se borran y se recrean: el ajuste se recalcula al abrir la app.

-- Rollback:
-- drop function if exists public.ajustar_sesion_hoy(uuid, text);
-- alter table public.scheduled_sessions drop column if exists ajuste, drop column if exists session_original;
