-- Auditoría de coherencia: correr DESPUÉS de cada cambio a sesiones, ejercicios o perfiles.
-- Todas las columnas de conteo deben dar 0 (salvo dias_desde_hoy). Una clienta con 0 días = sin mes generado.
with oct as (
  select p.id cid, ss.scheduled_date d, ss.session_id sid, ss.origen, s.session_type st,
    exists(select 1 from plantilla_tarjetas t where t.session_id = ss.session_id) motor
  from profiles p join scheduled_sessions ss on ss.client_id = p.id left join sessions s on s.id = ss.session_id
  where not p.is_admin and ss.scheduled_date >= current_date
), chk as (
  select o.*,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque = 1) b1,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque = 2) b2,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque = 4) b4,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque = 5) b5,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque is null) sin_bloque,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque = 3 and e.familia is null
           and e.name !~* '(banda|bird dog|dead bug|plancha|toque)') sin_familia,
    exists(select 1 from exercises e where e.session_id = o.sid and e.bloque = 4 and e.impacto = 'alto'
           and not exists (select 1 from variantes v where v.familia = e.familia and v.escenario = 'L')) cardio_sin_version_sin_salto
  from oct o
)
select p.name, p.plan, p.ruta, p.sub_perfil, p.nivel, p.ancla, p.escenario_default,
  count(c.d) dias_desde_hoy,
  count(*) filter (where c.d is not null and not c.motor) no_motor,
  count(*) filter (where c.st not ilike 'Recuperaci%' and not c.b4) sin_cardio,
  count(*) filter (where not c.b1) sin_b1, count(*) filter (where not c.b2) sin_blindaje, count(*) filter (where not c.b5) sin_cierre,
  count(*) filter (where c.sin_bloque) ej_sin_bloque, count(*) filter (where c.sin_familia) ej_sin_versiones,
  count(*) filter (where c.cardio_sin_version_sin_salto) cardio_sin_salto_faltante
from profiles p left join chk c on c.cid = p.id where not p.is_admin
group by 1,2,3,4,5,6,7 order by 1;

-- Familias usadas en el motor sin versión A o B
select distinct e.familia, (select string_agg(v.escenario, '' order by v.escenario) from variantes v where v.familia = e.familia) versiones
from exercises e where e.bloque = 3 and e.familia is not null
  and e.session_id in (select session_id from plantilla_tarjetas)
  and (not exists (select 1 from variantes v where v.familia = e.familia and v.escenario = 'A')
    or not exists (select 1 from variantes v where v.familia = e.familia and v.escenario = 'B'));
