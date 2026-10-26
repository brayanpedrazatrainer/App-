-- Clases en vivo con inscripción (2026-10-26)
-- Brayan publica su disponibilidad semanal (clases_horario). Las clientas de plan Compañía/Corona se inscriben
-- desde la app: máximo 3 clases por semana (lunes a domingo), solo esta semana y la siguiente, y nunca a una
-- clase que ya empezó. Cancelar se puede hasta la hora de la clase. Brayan ve quiénes asistirán.
-- Las clientas solo leen sus propias inscripciones; escriben únicamente por las funciones de abajo.

create table if not exists public.clases_horario (
  id bigint generated always as identity primary key,
  dia text not null check (dia in ('lun','mar','mie','jue','vie','sab','dom')),
  hora time not null,
  link text,
  cupo integer check (cupo is null or cupo > 0),
  activo boolean not null default true,
  unique (dia, hora)
);

create table if not exists public.clases_inscripciones (
  id bigint generated always as identity primary key,
  client_id uuid not null references public.profiles(id) on delete cascade,
  horario_id bigint not null references public.clases_horario(id) on delete cascade,
  fecha date not null,
  created_at timestamptz not null default now(),
  unique (client_id, horario_id, fecha)
);
create index if not exists clases_inscripciones_fecha on public.clases_inscripciones (fecha);

alter table public.clases_horario enable row level security;
alter table public.clases_inscripciones enable row level security;
drop policy if exists "Horario: lectura autenticadas" on public.clases_horario;
create policy "Horario: lectura autenticadas" on public.clases_horario for select to authenticated using (true);
drop policy if exists "Horario: admin gestiona" on public.clases_horario;
create policy "Horario: admin gestiona" on public.clases_horario for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Inscripciones: propias o admin" on public.clases_inscripciones;
create policy "Inscripciones: propias o admin" on public.clases_inscripciones for select to authenticated using (client_id = auth.uid() or public.is_admin());
drop policy if exists "Inscripciones: admin gestiona" on public.clases_inscripciones;
create policy "Inscripciones: admin gestiona" on public.clases_inscripciones for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.clases_horario, public.clases_inscripciones to authenticated;

-- Disponibilidad de Brayan: 6 a. m. martes a viernes; 8 p. m. martes, miércoles y viernes
insert into public.clases_horario (dia, hora) values
  ('mar','06:00'),('mie','06:00'),('jue','06:00'),('vie','06:00'),
  ('mar','20:00'),('mie','20:00'),('vie','20:00')
on conflict (dia, hora) do nothing;

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
  if coalesce(v_plan,'') not in ('compania','corona') then raise exception 'Tu plan no incluye clases en vivo'; end if;
  if coalesce(v_estado,'activa') <> 'activa' then raise exception 'Tu plan está en pausa'; end if;
  select * into h from clases_horario where id = p_horario and activo;
  if not found then raise exception 'Esa clase no está disponible'; end if;
  if (array['dom','lun','mar','mie','jue','vie','sab'])[extract(dow from p_fecha)::int + 1] <> h.dia then raise exception 'Fecha no válida para esa clase'; end if;
  if (p_fecha + h.hora) <= v_ahora then raise exception 'Esa clase ya empezó'; end if;
  if p_fecha > (date_trunc('week', v_ahora) + interval '13 days')::date then raise exception 'Solo puedes inscribirte en esta semana y la siguiente'; end if;
  if exists (select 1 from clases_inscripciones where client_id = v_uid and horario_id = p_horario and fecha = p_fecha) then return 'ok'; end if;
  select count(*) into n from clases_inscripciones
   where client_id = v_uid and date_trunc('week', fecha) = date_trunc('week', p_fecha);
  if n >= 3 then raise exception 'Ya tienes tus 3 clases de esa semana'; end if;
  if h.cupo is not null then
    select count(*) into n from clases_inscripciones where horario_id = p_horario and fecha = p_fecha;
    if n >= h.cupo then raise exception 'Esa clase ya está llena'; end if;
  end if;
  insert into clases_inscripciones (client_id, horario_id, fecha) values (v_uid, p_horario, p_fecha);
  return 'ok';
end; $$;

create or replace function public.cancelar_clase(p_id bigint)
returns text language plpgsql security definer set search_path to 'public' as $$
declare v_ahora timestamp := now() at time zone 'America/Bogota'; n int;
begin
  delete from clases_inscripciones i using clases_horario h
   where i.id = p_id and i.client_id = auth.uid() and h.id = i.horario_id and (i.fecha + h.hora) > v_ahora;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'No se pudo cancelar: la clase ya empezó o no es tuya'; end if;
  return 'ok';
end; $$;

revoke execute on function public.inscribir_clase(bigint, date) from public, anon;
revoke execute on function public.cancelar_clase(bigint) from public, anon;
grant execute on function public.inscribir_clase(bigint, date) to authenticated;
grant execute on function public.cancelar_clase(bigint) to authenticated;

-- Rollback:
-- drop function if exists public.cancelar_clase(bigint); drop function if exists public.inscribir_clase(bigint, date);
-- drop table if exists public.clases_inscripciones; drop table if exists public.clases_horario;
