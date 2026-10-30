-- Brayan también camina/trota el 10K (2026-10-30): se inscribe con su cuenta de admin y registra desde admin1.html.
-- Sus km suman al grupo. En el muro su fila va aparte, al final ("coach"), con los mismos colores por tipo de día.

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
end; $function$;

insert into public.camino_participantes (edicion_id, profile_id, apodo)
select e.id, p.id, 'Brayan' from public.camino_ediciones e, public.profiles p
 where e.activa and p.is_admin
on conflict (edicion_id, profile_id) do update set activa = true;
