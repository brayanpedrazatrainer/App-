-- Genera octubre 2026 en scheduled_sessions para las clientas con datos completos.
-- Misma lógica que generarMes() de admin1.html, con una diferencia: en ruta lunar proyecta ciclos
-- de duracion_ciclo días (dc = dias % dur + 1) en vez de quedarse en menguante_b cuando el ciclo se pasa.
-- Solo inserta días sin fila previa (regla de oro: no se modifica nada existente).

-- 1. Datos de perfil confirmados por Brayan el 2026-10-01
update profiles set plan='presencial', ruta='energia', sub_perfil='anticonceptivo_sin_caja',
  ancla='2026-10-01', dias_presenciales=array['vie','sab','dom']
where name='Lorena Reyes';                       -- cambió a Kyleena; arranca hoy en semana 1
update profiles set ancla='2026-09-12' where name='Laura';  -- período registrado en cycle_logs

-- 2. Filas de octubre
with cl as (
  select id, name, ruta, coalesce(duracion_ciclo,28) dur, ancla, dias_presenciales
  from profiles where name in ('Claudia Vivas','Gina Paola','Sara','Laura','Lorena Reyes')
), y as (
  select cl.*, d.f,
    case when ruta='energia' then ((d.f-ancla)%28)+1 else ((d.f-ancla)%dur)+1 end dc
  from cl cross join generate_series('2026-10-01'::date,'2026-10-31'::date,'1 day') d(f)
  where d.f >= ancla
), z as (
  select y.*, case
    when ruta='energia' then 'semana_'||ceil(dc/7.0)::int
    when dc<=5 then 'luna_nueva' when dc<=dur-15 then 'creciente' when dc<=dur-12 then 'llena'
    when dc<=dur-5 then 'menguante_a' else 'menguante_b' end fase
  from y
), w as (
  select z.*, case
    when ruta='energia' then ((dc-1)%7)+1
    when fase='luna_nueva' then ((dc-1)%5)+1
    when fase='creciente' then ((dc-6)%8)+1
    when fase='llena' then ((dc-(dur-14))%3)+1
    when fase='menguante_a' then ((dc-(dur-11))%7)+1
    else ((dc-(dur-4))%5)+1 end orden
  from z
)
insert into scheduled_sessions (client_id, scheduled_date, session_id, status, session_mode)
select w.id, w.f::date, t.session_id, 'pending',
  case when (array['dom','lun','mar','mie','jue','vie','sab'])[extract(dow from w.f)::int+1] = any(coalesce(w.dias_presenciales,'{}'))
       then 'Con Brayan' else 'Sesión Reina' end
from w
join plantillas p on p.ruta=w.ruta and p.activa
join plantilla_tarjetas t on t.plantilla_id=p.id and t.fase=w.fase and t.orden=w.orden
where t.session_id is not null
  and not exists (select 1 from scheduled_sessions s where s.client_id=w.id and s.scheduled_date=w.f::date);
