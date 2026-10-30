-- Km estimados (Brayan 2026-10-30): si trotó o caminó y puso minutos pero no km, se calculan con su ritmo:
-- solo caminata 5 km/h, solo trote 7,5 km/h, caminata + trote 6 km/h. Si pone km, se usa su número.
alter table public.camino_apariciones add column if not exists km_estimado boolean not null default false;

create or replace function public.camino_aparecer(p_tipo text, p_actividades text[], p_km numeric DEFAULT NULL::numeric, p_minutos integer DEFAULT NULL::integer, p_nota text DEFAULT NULL::text, p_nota_visible boolean DEFAULT true, p_dolor_zona text DEFAULT NULL::text, p_dolor_nivel text DEFAULT NULL::text, p_esfuerzo text DEFAULT NULL::text, p_uso_frase boolean DEFAULT NULL::boolean)
 returns text language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  v_ed uuid; v_inicio date; v_corre boolean; v_hito int := 0; v_est boolean := false; v_ritmo numeric;
begin
  if v_uid is null then raise exception 'Inicia sesión'; end if;
  v_ed := camino_mi_edicion();
  if v_ed is null then raise exception 'No estás inscrita en el camino'; end if;
  select fecha_inicio into v_inicio from camino_ediciones where id = v_ed;
  v_corre := p_actividades && array['trote','caminata'];
  p_nota := nullif(btrim(coalesce(p_nota,'')), '');
  if not v_corre then p_km := null; p_minutos := null; p_dolor_zona := null; p_dolor_nivel := null; p_esfuerzo := null; p_uso_frase := null; end if;
  if p_dolor_zona is null then p_dolor_nivel := null; end if;
  p_km := nullif(p_km, 0); p_minutos := nullif(p_minutos, 0);
  if v_corre and p_km is null and p_minutos is not null then
    v_ritmo := case when p_actividades @> array['trote','caminata'] then 6
                    when 'trote' = any(p_actividades) then 7.5 else 5 end;
    p_km := least(round(p_minutos * v_ritmo / 60.0, 1), 60);
    v_est := true;
  end if;
  insert into camino_apariciones (edicion_id, profile_id, fecha, tipo_dia, actividades, km, km_estimado, minutos, nota, nota_visible,
                                  dolor_zona, dolor_nivel, esfuerzo, uso_frase)
  values (v_ed, v_uid, v_hoy, p_tipo, p_actividades, p_km, v_est, p_minutos, p_nota, coalesce(p_nota_visible,true),
          p_dolor_zona, p_dolor_nivel, p_esfuerzo, p_uso_frase)
  on conflict (edicion_id, profile_id, fecha) do update set
    tipo_dia = excluded.tipo_dia, actividades = excluded.actividades, km = excluded.km, km_estimado = excluded.km_estimado,
    minutos = excluded.minutos, nota = excluded.nota, nota_visible = excluded.nota_visible, dolor_zona = excluded.dolor_zona,
    dolor_nivel = excluded.dolor_nivel, esfuerzo = excluded.esfuerzo, uso_frase = excluded.uso_frase, updated_at = now();
  if p_tipo = 'flojo' and v_hoy >= v_inicio then
    insert into camino_hitos (edicion_id, profile_id, tipo, fecha) values (v_ed, v_uid, 'aparecio_en_flojo', v_hoy)
    on conflict do nothing;
    get diagnostics v_hito = row_count;
  end if;
  return case when v_hito > 0 then 'primer_flojo' else 'ok' end;
end; $function$;

-- El muro le devuelve a cada una su 'est' (km aproximados) junto con sus km.
create or replace function public.camino_muro()
 returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  v_ed uuid := camino_mi_edicion(); e record; r jsonb;
begin
  if v_ed is null then return null; end if;
  select * into e from camino_ediciones where id = v_ed;
  with part as (
    select p.profile_id, coalesce(nullif(btrim(p.apodo),''), split_part(btrim(pr.name),' ',1)) as nombre,
           coalesce(pr.is_admin, false) as coach
      from camino_participantes p join profiles pr on pr.id = p.profile_id
     where p.edicion_id = v_ed and p.activa
  )
  select jsonb_build_object(
    'nombre', e.nombre, 'fecha_evento', e.fecha_evento, 'fecha_inicio', e.fecha_inicio, 'meta', e.meta_km_grupo, 'hoy', v_hoy,
    'total_km', (select coalesce(sum(a.km),0) from camino_apariciones a join part on part.profile_id = a.profile_id
                  where a.edicion_id = v_ed and a.fecha >= e.fecha_inicio),
    'participantes', (select coalesce(jsonb_agg(jsonb_build_object('id', profile_id, 'nombre', nombre, 'yo', profile_id = v_uid, 'coach', coach)
                                                order by coach, lower(nombre)), '[]') from part),
    'marcas', (select coalesce(jsonb_agg(case when a.profile_id = v_uid then
                    jsonb_build_object('p', a.profile_id, 'f', a.fecha, 't', a.tipo_dia, 'n', a.nota, 'vis', a.nota_visible,
                                       'act', a.actividades, 'km', a.km, 'est', a.km_estimado, 'min', a.minutos)
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
end; $function$;
