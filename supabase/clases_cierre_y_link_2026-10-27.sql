-- Clases: link fijo de Brayan y cierre de inscripciones (2026-10-27)
-- Link fijo de Meet en todas las clases (y por defecto en las nuevas).
-- Las inscripciones cierran 10 horas antes de la clase (6 a. m. → 8 p. m. del día anterior; 8 p. m. → 10 a. m.),
-- para que Brayan sepa la noche antes quién viene. Cancelar sigue permitido hasta la hora de la clase.

alter table public.clases_horario alter column link set default 'https://meet.google.com/znc-bcav-yyf';
update public.clases_horario set link = 'https://meet.google.com/znc-bcav-yyf';

create or replace function public.inscribir_clase(p_horario bigint, p_fecha date)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  v_uid uuid := auth.uid();
  v_ahora timestamp := now() at time zone 'America/Bogota';
  h record; v_plan text; v_estado text; n int;
begin
  if v_uid is null then raise exception 'Inicia sesión para inscribirte'; end if;
  perform pg_advisory_xact_lock(hashtext(v_uid::text));
  select plan, estado into v_plan, v_estado from profiles where id = v_uid;
  if coalesce(v_plan,'') not in ('presencial','compania','corona') then raise exception 'Tu plan no incluye clases en vivo'; end if;
  if coalesce(v_estado,'activa') <> 'activa' then raise exception 'Tu plan está en pausa'; end if;
  select * into h from clases_horario where id = p_horario and activo;
  if not found then raise exception 'Esa clase no está disponible'; end if;
  if h.tipo = 'en_vivo' then raise exception 'El en vivo semanal no necesita inscripción: entra con el link ese día'; end if;
  if (array['dom','lun','mar','mie','jue','vie','sab'])[extract(dow from p_fecha)::int + 1] <> h.dia then raise exception 'Fecha no válida para esa clase'; end if;
  if (p_fecha + h.hora) <= v_ahora then raise exception 'Esa clase ya empezó'; end if;
  if (p_fecha + h.hora) - interval '10 hours' <= v_ahora then raise exception 'Las inscripciones para esta clase ya cerraron: se cierran 10 horas antes'; end if;
  if p_fecha > (date_trunc('week', v_ahora) + interval '13 days')::date then raise exception 'Solo puedes inscribirte en esta semana y la siguiente'; end if;
  if exists (select 1 from clases_inscripciones where client_id = v_uid and horario_id = p_horario and fecha = p_fecha) then return 'ok'; end if;
  select count(*) into n from clases_inscripciones
   where client_id = v_uid and date_trunc('week', fecha) = date_trunc('week', p_fecha);
  if n >= 2 then raise exception 'Ya tienes tus 2 clases de corrección de esa semana'; end if;
  if h.cupo is not null then
    select count(*) into n from clases_inscripciones where horario_id = p_horario and fecha = p_fecha;
    if n >= h.cupo then raise exception 'Esa clase ya está llena'; end if;
  end if;
  insert into clases_inscripciones (client_id, horario_id, fecha) values (v_uid, p_horario, p_fecha);
  return 'ok';
end; $$;
