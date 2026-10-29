-- Mi Camino 10K (2026-10-29): sección aparte para las inscritas al 10K del 13 de marzo de 2027.
-- Spec de Brayan "Módulo El Camino" + documento "Calentamiento y fuerza para correr — Plan 10K".
-- NO toca el motor: tablas propias con prefijo camino_. Retirar a alguien = activa false (la pestaña desaparece).
-- Reglas que la base de datos garantiza: nadie lee los km, minutos, dolor ni esfuerzo de otra persona
-- (las clientas solo leen sus filas; el muro y el contador salen de camino_muro(), que devuelve nombre, tipo de día
-- y nota visible). Escribir solo por camino_aparecer() (una aparición por día, upsert).

create table if not exists public.camino_ediciones (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  fecha_evento date not null,
  fecha_inicio date not null,
  meta_km_grupo numeric not null default 1000,
  activa boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.camino_participantes (
  id uuid primary key default gen_random_uuid(),
  edicion_id uuid not null references public.camino_ediciones(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  apodo text,                                   -- nombre en el muro (si es null, el primer nombre del perfil)
  fecha_ingreso date not null default (now() at time zone 'America/Bogota')::date,
  motivo_ingreso text,                          -- privado: solo ella y el admin
  salud jsonb,                                  -- preguntas de salud de la entrada (privado)
  distancia_objetivo text not null default '10k' check (distancia_objetivo in ('10k','5k')),
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  unique (edicion_id, profile_id)
);

create table if not exists public.camino_apariciones (
  id uuid primary key default gen_random_uuid(),
  edicion_id uuid not null references public.camino_ediciones(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  fecha date not null,
  tipo_dia text not null check (tipo_dia in ('fuerte','medio','flojo')),
  actividades text[] not null check (cardinality(actividades) between 1 and 4
                                     and actividades <@ array['fuerza','trote','caminata','movilidad']),
  km numeric(5,2) check (km is null or (km > 0 and km <= 60)),
  minutos int check (minutos is null or minutos between 1 and 600),
  nota text check (nota is null or char_length(nota) <= 140),
  nota_visible boolean not null default true,
  -- Solo trote/caminata, privado (ella y Brayan): reglas del documento de entrenamiento
  dolor_zona text check (dolor_zona is null or dolor_zona in ('rodilla','tibia','talon','cadera','otra')),
  dolor_nivel text check (dolor_nivel is null or dolor_nivel in ('molesta','duele')),
  esfuerzo text check (esfuerzo is null or esfuerzo in ('comodo','exigente','al_limite')),
  uso_frase boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (edicion_id, profile_id, fecha)
);

create table if not exists public.camino_hitos (
  id uuid primary key default gen_random_uuid(),
  edicion_id uuid not null references public.camino_ediciones(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  tipo text not null check (tipo in ('primer_trote_sin_parar','aparecio_en_flojo','ciclo_completo','cambio_visible')),
  fecha date not null,
  celebrado boolean not null default false,
  unique (edicion_id, profile_id, tipo)
);

alter table public.camino_ediciones enable row level security;
alter table public.camino_participantes enable row level security;
alter table public.camino_apariciones enable row level security;
alter table public.camino_hitos enable row level security;

create policy camino_ed_leer on public.camino_ediciones for select to authenticated using (true);
create policy camino_ed_admin on public.camino_ediciones for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy camino_pa_leer on public.camino_participantes for select to authenticated using (profile_id = auth.uid() or public.is_admin());
create policy camino_pa_admin on public.camino_participantes for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy camino_ap_leer on public.camino_apariciones for select to authenticated using (profile_id = auth.uid() or public.is_admin());
create policy camino_ap_admin on public.camino_apariciones for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy camino_hi_leer on public.camino_hitos for select to authenticated using (profile_id = auth.uid() or public.is_admin());
create policy camino_hi_admin on public.camino_hitos for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant select, insert, update, delete on public.camino_ediciones, public.camino_participantes,
  public.camino_apariciones, public.camino_hitos to authenticated;

-- Edición activa de la clienta (o null)
create or replace function public.camino_mi_edicion()
returns uuid language sql stable security definer set search_path to 'public' as $$
  select p.edicion_id from camino_participantes p join camino_ediciones e on e.id = p.edicion_id
   where p.profile_id = auth.uid() and p.activa and e.activa
   order by e.fecha_evento limit 1;
$$;

-- "Aparecí hoy": una por día (si vuelve a registrar, se actualiza). Fecha = hoy en Colombia.
create or replace function public.camino_aparecer(
  p_tipo text, p_actividades text[], p_km numeric default null, p_minutos int default null,
  p_nota text default null, p_nota_visible boolean default true,
  p_dolor_zona text default null, p_dolor_nivel text default null, p_esfuerzo text default null,
  p_uso_frase boolean default null)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  v_uid uuid := auth.uid();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  v_ed uuid; v_inicio date; v_corre boolean; v_hito int := 0;
begin
  if v_uid is null then raise exception 'Inicia sesión'; end if;
  v_ed := camino_mi_edicion();
  if v_ed is null then raise exception 'No estás inscrita en el camino'; end if;
  select fecha_inicio into v_inicio from camino_ediciones where id = v_ed;
  v_corre := p_actividades && array['trote','caminata'];
  p_nota := nullif(btrim(coalesce(p_nota,'')), '');
  if not v_corre then p_km := null; p_minutos := null; p_dolor_zona := null; p_dolor_nivel := null; p_esfuerzo := null; p_uso_frase := null; end if;
  if p_dolor_zona is null then p_dolor_nivel := null; end if;
  insert into camino_apariciones (edicion_id, profile_id, fecha, tipo_dia, actividades, km, minutos, nota, nota_visible,
                                  dolor_zona, dolor_nivel, esfuerzo, uso_frase)
  values (v_ed, v_uid, v_hoy, p_tipo, p_actividades, nullif(p_km,0), nullif(p_minutos,0), p_nota, coalesce(p_nota_visible,true),
          p_dolor_zona, p_dolor_nivel, p_esfuerzo, p_uso_frase)
  on conflict (edicion_id, profile_id, fecha) do update set
    tipo_dia = excluded.tipo_dia, actividades = excluded.actividades, km = excluded.km, minutos = excluded.minutos,
    nota = excluded.nota, nota_visible = excluded.nota_visible, dolor_zona = excluded.dolor_zona,
    dolor_nivel = excluded.dolor_nivel, esfuerzo = excluded.esfuerzo, uso_frase = excluded.uso_frase, updated_at = now();
  -- Hito automático: la primera vez que aparece en un día flojo (desde que abre el camino)
  if p_tipo = 'flojo' and v_hoy >= v_inicio then
    insert into camino_hitos (edicion_id, profile_id, tipo, fecha) values (v_ed, v_uid, 'aparecio_en_flojo', v_hoy)
    on conflict do nothing;
    get diagnostics v_hito = row_count;
  end if;
  return case when v_hito > 0 then 'primer_flojo' else 'ok' end;
end; $$;

-- Muro, contador del grupo y voces. De las demás solo sale nombre, tipo de día y nota visible.
create or replace function public.camino_muro()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_uid uuid := auth.uid();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  v_ed uuid := camino_mi_edicion(); e record; r jsonb;
begin
  if v_ed is null then return null; end if;
  select * into e from camino_ediciones where id = v_ed;
  with part as (
    select p.profile_id, coalesce(nullif(btrim(p.apodo),''), split_part(btrim(pr.name),' ',1)) as nombre
      from camino_participantes p join profiles pr on pr.id = p.profile_id
     where p.edicion_id = v_ed and p.activa
  )
  select jsonb_build_object(
    'nombre', e.nombre, 'fecha_evento', e.fecha_evento, 'fecha_inicio', e.fecha_inicio, 'meta', e.meta_km_grupo, 'hoy', v_hoy,
    'total_km', (select coalesce(sum(a.km),0) from camino_apariciones a join part on part.profile_id = a.profile_id
                  where a.edicion_id = v_ed and a.fecha >= e.fecha_inicio),
    'participantes', (select coalesce(jsonb_agg(jsonb_build_object('id', profile_id, 'nombre', nombre, 'yo', profile_id = v_uid)
                                                order by lower(nombre)), '[]') from part),
    'marcas', (select coalesce(jsonb_agg(case when a.profile_id = v_uid then
                    jsonb_build_object('p', a.profile_id, 'f', a.fecha, 't', a.tipo_dia, 'n', a.nota, 'vis', a.nota_visible,
                                       'act', a.actividades, 'km', a.km, 'min', a.minutos)
                  else jsonb_build_object('p', a.profile_id, 'f', a.fecha, 't', a.tipo_dia, 'n', case when a.nota_visible then a.nota end) end), '[]')
                 from camino_apariciones a join part on part.profile_id = a.profile_id
                where a.edicion_id = v_ed and a.fecha > v_hoy - 14),
    'voces', (select coalesce(jsonb_agg(v order by v->>'f' desc, v->>'c' desc), '[]') from (
                select jsonb_build_object('nombre', part.nombre, 'n', a.nota, 'f', a.fecha, 'c', a.updated_at) v
                  from camino_apariciones a join part on part.profile_id = a.profile_id
                 where a.edicion_id = v_ed and a.nota_visible and a.nota is not null
                 order by a.fecha desc, a.updated_at desc limit 10) x),
    'mias', (select jsonb_build_object('total', count(*), 'flojos', count(*) filter (where tipo_dia = 'flojo'))
               from camino_apariciones where edicion_id = v_ed and profile_id = v_uid)
  ) into r;
  return r;
end; $$;

revoke execute on function public.camino_mi_edicion() from public, anon;
revoke execute on function public.camino_aparecer(text, text[], numeric, int, text, boolean, text, text, text, boolean) from public, anon;
revoke execute on function public.camino_muro() from public, anon;
grant execute on function public.camino_mi_edicion() to authenticated;
grant execute on function public.camino_aparecer(text, text[], numeric, int, text, boolean, text, text, text, boolean) to authenticated;
grant execute on function public.camino_muro() to authenticated;

-- Primera edición + las 7 del grupo (Brayan 2026-10-29: Yeraldine, Natalia, Gina, Patricia, Sara, Laura, Lorena)
insert into public.camino_ediciones (nombre, fecha_evento, fecha_inicio, meta_km_grupo)
select 'Camino 10K Marzo 2027', '2027-03-13', '2026-11-01', 1000
where not exists (select 1 from public.camino_ediciones where nombre = 'Camino 10K Marzo 2027');

insert into public.camino_participantes (edicion_id, profile_id)
select e.id, p.id from public.camino_ediciones e, public.profiles p
 where e.nombre = 'Camino 10K Marzo 2027'
   and p.name in ('Yeraldine Melo','Natalia Ovalle','Gina Paola','Nubia Patricia','Sara','Laura','Lorena Reyes')
on conflict (edicion_id, profile_id) do nothing;

-- Rollback:
-- drop function if exists public.camino_muro(); drop function if exists public.camino_aparecer(text, text[], numeric, int, text, boolean, text, text, text, boolean);
-- drop function if exists public.camino_mi_edicion();
-- drop table if exists public.camino_hitos, public.camino_apariciones, public.camino_participantes, public.camino_ediciones;
