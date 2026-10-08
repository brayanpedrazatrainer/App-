-- 2026-10-08 · Pedido de Brayan: coherencia total por escenario + cardio en todas las sesiones de entrenamiento.
-- Regla nueva (app): cada ejercicio con familia muestra SIEMPRE la versión del escenario elegido.
--   Gimnasio: versión C; si no hay C, la de mancuernas (en el gimnasio hay mancuernas).
--   Mancuernas: versión B. Solo cuerpo: versión A.
-- Cardio (bloque 4): polichilenas, tendidas, skipping, desplazamientos laterales (lista de Brayan).

-- 1. Versiones de los ejercicios nuevos (mismo video; la descripción explica el equipo)
insert into public.variantes (familia, escenario, nombre, video_url, descripcion) values
 ('sentadilla_silla','A','Sentadilla a silla','https://youtube.com/shorts/uzDdE1Tw-Vw',null),
 ('sentadilla_silla','B','Sentadilla a silla con mancuerna','https://youtube.com/shorts/uzDdE1Tw-Vw','Igual que en el video, con una mancuerna al pecho.'),
 ('sentadilla_pausa','A','Sentadilla con pausa','https://youtube.com/shorts/mwGAWUqhNBA',null),
 ('sentadilla_pausa','B','Sentadilla goblet con pausa','https://youtube.com/shorts/mwGAWUqhNBA','Igual que en el video, con una mancuerna al pecho.'),
 ('sentadilla_pausa','C','Sentadilla en Smith con pausa','https://youtube.com/shorts/Dhk2WYZYZe8','Haz una pausa de 2 segundos abajo antes de subir.'),
 ('sentadilla_talon','A','Sentadilla con levantamiento de talón','https://youtube.com/shorts/uIPtf8a1wdc',null),
 ('sentadilla_talon','B','Sentadilla con levantamiento de talón con mancuernas','https://youtube.com/shorts/uIPtf8a1wdc','Igual que en el video, con una mancuerna en cada mano.'),
 ('step_up','A','Step up','https://youtube.com/shorts/I_upAwWJw3g',null),
 ('step_up','B','Step up con mancuernas','https://youtube.com/shorts/I_upAwWJw3g','Igual que en el video, con una mancuerna en cada mano.'),
 ('bulgara','A','Sentadilla búlgara','https://youtube.com/shorts/rjnsNi-2Hx8',null),
 ('bulgara','B','Sentadilla búlgara con mancuernas','https://youtube.com/shorts/rjnsNi-2Hx8','Igual que en el video, con una mancuerna en cada mano.'),
 ('desplantes_atras','A','Desplantes atrás','https://youtube.com/shorts/-TuNt_0ANVg',null),
 ('desplantes_atras','B','Desplantes atrás con mancuernas','https://youtube.com/shorts/-TuNt_0ANVg','Igual que en el video, con una mancuerna en cada mano.'),
 ('desplantes_caminata','A','Desplantes caminata con maleta','https://youtube.com/shorts/Tl9MohMDIss',null),
 ('desplantes_caminata','B','Desplantes caminata con mancuernas','https://youtube.com/shorts/Tl9MohMDIss','Igual que en el video, con una mancuerna en cada mano en lugar de la maleta.'),
 ('sentadilla_una_pierna','A','Sentadilla a una pierna a silla','https://youtube.com/shorts/HuIkD2lSflU',null),
 ('sentadilla_una_pierna','B','Sentadilla a una pierna a silla con mancuerna','https://youtube.com/shorts/HuIkD2lSflU','Igual que en el video, con una mancuerna al pecho.'),
 ('empuje_cadera','A','Empuje de cadera','https://youtube.com/shorts/90j0eMzTD70',null),
 ('empuje_cadera','B','Hip thrust con mancuerna sobre cadera','https://youtube.com/shorts/GtSaWk_H25M',null),
 ('empuje_cadera','C','Hip thrust en Smith','https://youtube.com/shorts/Rk4O-UzF_uk',null),
 ('empuje_una_pierna','A','Empuje de cadera a una pierna','https://youtube.com/shorts/ABeSp-Pc5q4',null),
 ('empuje_una_pierna','B','Empuje de cadera a una pierna con mancuerna','https://youtube.com/shorts/ABeSp-Pc5q4','Igual que en el video, con una mancuerna sobre la cadera.'),
 ('empuje_explosivo','A','Empuje de cadera explosivo con maleta','https://youtube.com/shorts/ZCHI_v5wNUQ',null),
 ('empuje_explosivo','B','Empuje de cadera explosivo con mancuerna','https://youtube.com/shorts/ZCHI_v5wNUQ','Igual que en el video, con una mancuerna sobre la cadera en lugar de la maleta.')
on conflict (familia, escenario) do update set nombre = excluded.nombre, video_url = excluded.video_url, descripcion = excluded.descripcion;

-- 2. Familia de cada ejercicio del motor
update public.exercises set familia = case name
    when 'Sentadilla a silla' then 'sentadilla_silla'
    when 'Sentadilla con pausa' then 'sentadilla_pausa'
    when 'Sentadilla con levantamiento de talón' then 'sentadilla_talon'
    when 'Step up' then 'step_up'
    when 'Sentadilla búlgara' then 'bulgara'
    when 'Desplantes atrás' then 'desplantes_atras'
    when 'Desplantes caminata con maleta' then 'desplantes_caminata'
    when 'Sentadilla a una pierna a silla' then 'sentadilla_una_pierna'
    when 'Empuje de cadera' then 'empuje_cadera'
    when 'Empuje de cadera a una pierna' then 'empuje_una_pierna'
    when 'Empuje de cadera explosivo con maleta' then 'empuje_explosivo'
    when 'Remo con banda' then 'remo' end
  where name in ('Sentadilla a silla','Sentadilla con pausa','Sentadilla con levantamiento de talón','Step up','Sentadilla búlgara',
    'Desplantes atrás','Desplantes caminata con maleta','Sentadilla a una pierna a silla','Empuje de cadera',
    'Empuje de cadera a una pierna','Empuje de cadera explosivo con maleta','Remo con banda');
update public.exercises set equipo = 'banda' where name = 'Remo con banda';

-- 3. Cardio: se reemplaza el anterior y se agrega a Suaves e Integradoras
create or replace function pg_temp.cardio(p_ses uuid, p_nombre text, p_rondas int) returns void language sql as $$
  insert into public.exercises (session_id, name, muscle_group, sets_count, reps_range, video_url, order_index, bloque, equipo, impacto)
  values (p_ses, p_nombre, 'Cardio metabólico', p_rondas, '30 s · 30s desc',
    case p_nombre when 'Skipping' then 'https://youtube.com/shorts/GDL6UsMJtWM'
                  when 'Skipping con brazos arriba' then 'https://youtube.com/shorts/TFFUn3z1wHQ'
                  when 'Desplazamientos laterales' then 'https://youtube.com/shorts/1aK4icjrisw'
                  else '' end,
    50, 4, 'cuerpo', 'alto');
$$;

do $$
declare
  p1 uuid[] := array['889104d7-58ab-4deb-b52f-cacb11afabf1','b941a06d-a327-4d6a-bc68-c3b046c92129','4a11fbfb-62eb-4938-8331-fcce253b068a','9035b97a-a647-4739-89a2-36955c6215cb'];
  p2 uuid[] := array['0cea1c85-50f3-43d9-b66b-7786bc475c20','2192fd0d-d65b-4bc2-9893-605dd8455f81','68007c84-adda-4785-b1a7-e7ef46031a49','114724b6-fb82-4592-85e9-49acf61047db'];
  p3 uuid[] := array['388524ec-0ea9-492f-9cb8-528f50513809','5e78a7d3-3d23-4a01-bc43-95387e5d1ae5','6d03f239-8aef-42bd-a103-c3e4b4624f64','a675447a-042a-4383-ba30-b4d29f536906'];
  rot text[] := array['Polichilenas','Skipping','Desplazamientos laterales','Skipping con brazos arriba'];
  s uuid; t text; i int := 0;
begin
  delete from public.exercises where bloque = 4 and session_id in (select session_id from public.plantilla_tarjetas);

  -- Energía Principales (3 rondas)
  perform pg_temp.cardio(p1[1], 'Desplazamientos laterales', 3);
  perform pg_temp.cardio(p1[2], 'Skipping', 3);
  perform pg_temp.cardio(p1[3], 'Tendidas', 3);
  perform pg_temp.cardio(p1[4], 'Polichilenas', 3);
  perform pg_temp.cardio(p2[1], 'Polichilenas', 3);
  perform pg_temp.cardio(p2[2], 'Skipping con brazos arriba', 3);
  perform pg_temp.cardio(p2[3], 'Desplazamientos laterales', 3);
  perform pg_temp.cardio(p2[4], 'Skipping', 3);
  perform pg_temp.cardio(p3[1], 'Skipping', 3);
  perform pg_temp.cardio(p3[2], 'Tendidas', 3);
  perform pg_temp.cardio(p3[3], 'Polichilenas', 3);
  perform pg_temp.cardio(p3[4], 'Desplazamientos laterales', 3);

  -- Lunar Principales (3 rondas), por tarjeta
  for s, t in select distinct pt.session_id, pt.fase || '#' || pt.orden from public.plantilla_tarjetas pt
              join public.plantillas p on p.id = pt.plantilla_id join public.sessions x on x.id = pt.session_id
              where p.ruta = 'lunar' and x.session_type ilike 'Sesión Principal%' order by 2 loop
    if not exists (select 1 from public.exercises where session_id = s and bloque = 4) then
      i := i + 1;
      perform pg_temp.cardio(s, (array['Skipping','Polichilenas','Desplazamientos laterales','Tendidas','Skipping con brazos arriba'])[((i - 1) % 5) + 1], 3);
    end if;
  end loop;

  -- Suaves e Integradoras (2 rondas, más ligero)
  i := 0;
  for s in select distinct pt.session_id from public.plantilla_tarjetas pt join public.sessions x on x.id = pt.session_id
           where x.session_type ilike 'Sesión Suave%' or x.session_type ilike 'Sesión Integradora%' loop
    i := i + 1;
    perform pg_temp.cardio(s, rot[((i - 1) % 4) + 1], 2);
  end loop;
end $$;
