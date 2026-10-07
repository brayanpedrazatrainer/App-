-- Variabilidad de las sesiones Principales según la fase + bloque 4 (cardio) + blindaje en el bloque 1.
-- Aprobado por Brayan el 2026-10-07. Se aplica en una sola transacción.
-- Energía: cada semana tiene su propia copia de la sesión, se cambian los ejercicios en su sitio (mismas series).
-- Lunar: la Principal A/B/C se repetía en varias tarjetas; se crean copias para variar y se re-apuntan las tarjetas.

alter table public.exercises add column if not exists impacto text check (impacto in ('alto','bajo'));

insert into public.variantes (familia, escenario, nombre, video_url) values
 ('woodchop','A','Woodchop con maleta','https://youtube.com/shorts/t_jjQB1-nTQ'),
 ('woodchop','B','Woodchop con mancuerna','https://youtube.com/shorts/COSv0BNBE0k'),
 -- reemplazo de los cardios de impacto alto para perimenopausia y menopausia
 ('bajo_impacto','A','Caminata con levantamiento de talones','https://youtube.com/shorts/ooslH4LpLSI')
on conflict (familia, escenario) do nothing;

-- Cambia un ejercicio del trabajo principal (bloque 3) por otro, conservando series, orden e indicaciones.
-- p_lado: 1 = pasar a "x lado", -1 = pasar a "reps", 0 = igual
create or replace function pg_temp.cambiar(p_ses uuid, p_viejo text, p_nuevo text, p_vid text, p_equipo text, p_familia text, p_patron text, p_lado int)
returns void language sql as $$
  update public.exercises set name = p_nuevo, video_url = 'https://youtube.com/shorts/' || p_vid,
    equipo = p_equipo, familia = p_familia, patron = coalesce(p_patron, patron), carga_kg = null,
    reps_range = case p_lado
      when 1 then regexp_replace(reps_range, '^([0-9–-]+)\s*reps', '\1 x lado')
      when -1 then regexp_replace(reps_range, '^([0-9–-]+)\s*x lado', '\1 reps')
      else reps_range end
  where session_id = p_ses and name = p_viejo and bloque = 3;
$$;

create or replace function pg_temp.clonar(p_ses uuid) returns uuid language plpgsql as $$
declare v uuid;
begin
  insert into public.sessions (program_id, week_number, day_number, session_type)
    select program_id, week_number, day_number, session_type from public.sessions where id = p_ses returning id into v;
  insert into public.exercises (session_id, name, muscle_group, sets_count, reps_range, video_url, order_index, patron, bloque, carga_pct, carga_kg, tempo, cue, familia, equipo, impacto)
    select v, name, muscle_group, sets_count, reps_range, video_url, order_index, patron, bloque, carga_pct, carga_kg, tempo, cue, familia, equipo, impacto
    from public.exercises where session_id = p_ses;
  return v;
end $$;

create or replace function pg_temp.cardio(p_ses uuid, p_nombre text, p_vid text, p_impacto text) returns void language sql as $$
  insert into public.exercises (session_id, name, muscle_group, sets_count, reps_range, video_url, order_index, bloque, equipo, impacto)
  values (p_ses, p_nombre, 'Cardio metabólico', 3, '30 s · 30s desc', 'https://youtube.com/shorts/' || p_vid, 50, 4, 'cuerpo', p_impacto);
$$;

create or replace function pg_temp.blindaje(p_ses uuid, p_orden int, p_nombre text, p_musculo text, p_vid text) returns void language sql as $$
  insert into public.exercises (session_id, name, muscle_group, sets_count, reps_range, video_url, order_index, bloque, equipo)
  values (p_ses, p_nombre, p_musculo, 1, '8 x lado · control', 'https://youtube.com/shorts/' || p_vid, p_orden, 2, 'cuerpo');
$$;

do $$
declare
  -- energía (una sesión por semana)
  p1 uuid[] := array['889104d7-58ab-4deb-b52f-cacb11afabf1','b941a06d-a327-4d6a-bc68-c3b046c92129','4a11fbfb-62eb-4938-8331-fcce253b068a','9035b97a-a647-4739-89a2-36955c6215cb'];
  p2 uuid[] := array['0cea1c85-50f3-43d9-b66b-7786bc475c20','2192fd0d-d65b-4bc2-9893-605dd8455f81','68007c84-adda-4785-b1a7-e7ef46031a49','114724b6-fb82-4592-85e9-49acf61047db'];
  p3 uuid[] := array['388524ec-0ea9-492f-9cb8-528f50513809','5e78a7d3-3d23-4a01-bc43-95387e5d1ae5','6d03f239-8aef-42bd-a103-c3e4b4624f64','a675447a-042a-4383-ba30-b4d29f536906'];
  -- lunar
  la uuid := 'd921285c-26ea-4c1f-81df-ec150cb610c0';
  lb uuid := '091c4369-a1ee-4797-992d-8b25e4fdd325';
  lc uuid := '544b5ab4-53fe-42aa-8b4d-df5849460b07';
  la5 uuid; lam uuid; lb6 uuid; lc7 uuid;
  s uuid; t text;
begin
  -- Copias lunares (antes de modificar las originales)
  la5 := pg_temp.clonar(la); lam := pg_temp.clonar(la); lb6 := pg_temp.clonar(lb); lc7 := pg_temp.clonar(lc);
  update public.plantilla_tarjetas t2 set session_id = la5 from public.plantillas p where p.id = t2.plantilla_id and p.ruta = 'lunar' and t2.fase = 'creciente' and t2.orden = 5;
  update public.plantilla_tarjetas t2 set session_id = lam from public.plantillas p where p.id = t2.plantilla_id and p.ruta = 'lunar' and t2.fase = 'menguante_a' and t2.orden = 4;
  update public.plantilla_tarjetas t2 set session_id = lb6 from public.plantillas p where p.id = t2.plantilla_id and p.ruta = 'lunar' and t2.fase = 'creciente' and t2.orden = 6;
  update public.plantilla_tarjetas t2 set session_id = lc7 from public.plantillas p where p.id = t2.plantilla_id and p.ruta = 'lunar' and t2.fase = 'creciente' and t2.orden = 7;

  -- ENERGÍA · Principal 1 · Tren inferior
  perform pg_temp.cambiar(p1[1], 'Sentadilla goblet', 'Sentadilla a silla', 'uzDdE1Tw-Vw', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[1], 'Hip thrust con mancuerna sobre cadera', 'Empuje de cadera', '90j0eMzTD70', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[1], 'Zancada estática', 'Desplantes atrás', '-TuNt_0ANVg', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[2], 'Sentadilla goblet', 'Step up', 'I_upAwWJw3g', 'cuerpo', null, null, 1);
  perform pg_temp.cambiar(p1[2], 'Zancada estática', 'Desplantes caminata con maleta', 'Tl9MohMDIss', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[3], 'Sentadilla goblet', 'Sentadilla búlgara', 'rjnsNi-2Hx8', 'cuerpo', null, null, 1);
  perform pg_temp.cambiar(p1[3], 'Hip thrust con mancuerna sobre cadera', 'Empuje de cadera a una pierna', 'ABeSp-Pc5q4', 'cuerpo', null, null, 1);
  perform pg_temp.cambiar(p1[3], 'Zancada estática', 'Sentadilla a una pierna a silla', 'HuIkD2lSflU', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[4], 'Sentadilla goblet', 'Sentadilla con pausa', 'mwGAWUqhNBA', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[4], 'Hip thrust con mancuerna sobre cadera', 'Empuje de cadera', '90j0eMzTD70', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p1[4], 'Zancada estática', 'Sentadilla con levantamiento de talón', 'uIPtf8a1wdc', 'cuerpo', null, null, -1);

  -- ENERGÍA · Principal 2 · Tren superior (semanas 2 y 3 se quedan con gimnasio)
  foreach s in array array[p2[1], p2[4]] loop
    perform pg_temp.cambiar(s, 'Press de pecho con mancuernas', 'Flexión sobre rodillas', 'tSnVup1OzGg', 'cuerpo', 'press_pecho', null, 0);
    perform pg_temp.cambiar(s, 'Press militar con mancuernas', 'Press de hombro sentada con mancuernas', '6xMiXKRbO-w', 'mancuernas', 'press_hombro', null, 0);
  end loop;
  perform pg_temp.cambiar(p2[1], 'Remo con barra', 'Remo solo cuerpo', 'tlqlLuuDI2g', 'cuerpo', 'remo', null, 0);
  perform pg_temp.cambiar(p2[1], 'Jalón en máquina', 'Jalón acostado con toalla', 'U7k4i4yVXEI', 'cuerpo', 'jalon', null, 0);
  perform pg_temp.cambiar(p2[4], 'Remo con barra', 'Remo con mancuerna a un brazo', 'XxYHzVP8tjw', 'mancuernas', 'remo', null, 1);
  perform pg_temp.cambiar(p2[4], 'Jalón en máquina', 'Jalón con banda', '8a2E_4MV-0U', 'banda', 'jalon', null, 0);

  -- ENERGÍA · Principal 3 · Cuerpo completo: el core rota (semana 3 se queda con Pallof)
  perform pg_temp.cambiar(p3[1], 'Pallof press con banda', 'Plancha lateral con rotación', 'w8_PMlazKhc', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(p3[2], 'Pallof press con banda', 'Woodchop con mancuerna', 'COSv0BNBE0k', 'mancuernas', 'woodchop', null, 0);
  perform pg_temp.cambiar(p3[4], 'Pallof press con banda', 'Toque de talones en plancha', 'q-tE2_uG5Uk', 'cuerpo', null, null, 0);

  -- LUNAR · Principal A
  perform pg_temp.cambiar(la, 'Zancada estática', 'Sentadilla búlgara', 'rjnsNi-2Hx8', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(la5, 'Sentadilla en Smith', 'Step up', 'I_upAwWJw3g', 'cuerpo', null, null, 1);
  perform pg_temp.cambiar(la5, 'Hip thrust en Smith', 'Empuje de cadera a una pierna', 'ABeSp-Pc5q4', 'cuerpo', null, null, 1);
  perform pg_temp.cambiar(la5, 'Zancada estática', 'Desplantes atrás', '-TuNt_0ANVg', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(lam, 'Sentadilla en Smith', 'Sentadilla con pausa', 'mwGAWUqhNBA', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(lam, 'Zancada estática', 'Sentadilla con levantamiento de talón', 'uIPtf8a1wdc', 'cuerpo', null, null, -1);
  -- LUNAR · Principal B (la copia varía; la original se queda)
  perform pg_temp.cambiar(lb6, 'Remo con barra', 'Remo con mancuerna a un brazo', 'XxYHzVP8tjw', 'mancuernas', 'remo', null, 1);
  perform pg_temp.cambiar(lb6, 'Press militar con mancuernas', 'Press de hombro sentada con mancuernas', '6xMiXKRbO-w', 'mancuernas', 'press_hombro', null, 0);
  perform pg_temp.cambiar(lb6, 'Jalón en máquina', 'Jalón acostado con toalla', 'U7k4i4yVXEI', 'cuerpo', 'jalon', null, 0);
  -- LUNAR · Principal C
  perform pg_temp.cambiar(lc, 'Pallof press con banda', 'Woodchop con mancuerna', 'COSv0BNBE0k', 'mancuernas', 'woodchop', null, 0);
  perform pg_temp.cambiar(lc7, 'Sentadilla goblet con mancuerna', 'Desplantes caminata con maleta', 'Tl9MohMDIss', 'cuerpo', null, null, 1);
  perform pg_temp.cambiar(lc7, 'Hip thrust en Smith', 'Empuje de cadera explosivo con maleta', 'ZCHI_v5wNUQ', 'cuerpo', null, null, 0);
  perform pg_temp.cambiar(lc7, 'Pallof press con banda', 'Plancha lateral con rotación', 'w8_PMlazKhc', 'cuerpo', null, null, 0);

  -- Indicaciones de equipo que ya no aplican al ejercicio nuevo
  update public.exercises e set reps_range = replace(reps_range, 'Mancuerna ligera', 'Ligera')
    where e.bloque = 3 and coalesce(e.equipo, '') <> 'mancuernas' and reps_range like '%Mancuerna ligera%'
      and e.session_id in (select session_id from public.plantilla_tarjetas);
  update public.exercises e set reps_range = regexp_replace(reps_range, '\s*·\s*Banda (media|ligera)', '')
    where e.bloque = 3 and e.name not ilike '%banda%' and reps_range ~ 'Banda (media|ligera)'
      and e.session_id in (select session_id from public.plantilla_tarjetas);

  -- BLOQUE 4 · Cardio (al final del trabajo principal, antes del cierre)
  perform pg_temp.cardio(p1[1], 'Caminata con levantamiento de talones', 'ooslH4LpLSI', 'bajo');
  perform pg_temp.cardio(p1[2], 'Skipping', 'GDL6UsMJtWM', 'alto');
  perform pg_temp.cardio(p1[3], 'Desplazamientos laterales en jumping jacks', '1aK4icjrisw', 'alto');
  perform pg_temp.cardio(p1[4], 'Caminata con levantamiento de talones', 'ooslH4LpLSI', 'bajo');
  perform pg_temp.cardio(p2[1], 'Marcha con maleta abajo', 'lKjr4nvABiM', 'bajo');
  perform pg_temp.cardio(p2[2], 'Skipping con brazos arriba', 'TFFUn3z1wHQ', 'alto');
  perform pg_temp.cardio(p2[3], 'Marcha con maleta arriba', 'y8b_e1jV39s', 'bajo');
  perform pg_temp.cardio(p2[4], 'Marcha con mochila a un lado', 'ubET7FO0seo', 'bajo');
  perform pg_temp.cardio(p3[1], 'Caminata con levantamiento de talones', 'ooslH4LpLSI', 'bajo');
  perform pg_temp.cardio(p3[2], 'Desplantes hacia adelante con rotación de tronco', '1Wl_MzfBnLY', 'bajo');
  perform pg_temp.cardio(p3[3], 'Desplazamientos laterales en jumping jacks', '1aK4icjrisw', 'alto');
  perform pg_temp.cardio(p3[4], 'Marcha con maleta abajo', 'lKjr4nvABiM', 'bajo');
  perform pg_temp.cardio(la, 'Skipping', 'GDL6UsMJtWM', 'alto');
  perform pg_temp.cardio(la5, 'Desplazamientos laterales en jumping jacks', '1aK4icjrisw', 'alto');
  perform pg_temp.cardio(lam, 'Desplantes hacia adelante con rotación de tronco', '1Wl_MzfBnLY', 'bajo');
  perform pg_temp.cardio(lb, 'Skipping con brazos arriba', 'TFFUn3z1wHQ', 'alto');
  perform pg_temp.cardio(lb6, 'Marcha con maleta arriba', 'y8b_e1jV39s', 'bajo');
  perform pg_temp.cardio(lc, 'Skipping', 'GDL6UsMJtWM', 'alto');
  perform pg_temp.cardio(lc7, 'Desplazamientos laterales en jumping jacks', '1aK4icjrisw', 'alto');

  -- BLOQUE 1 · Blindaje según el tipo de día (después de la Movilidad, en todas las sesiones de entrenamiento del motor)
  for s, t in select distinct x.id, x.session_type from public.sessions x join public.plantilla_tarjetas pt on pt.session_id = x.id
             where x.session_type not ilike 'Recuperaci%' loop
    if t ilike '%Tren Inferior%' then
      perform pg_temp.blindaje(s, 2, 'Movilidad de tobillo en semi-rodilla', 'Blindaje · tobillo', 'NFtolzVDlDw');
      perform pg_temp.blindaje(s, 3, 'Bisagra a una pierna con alcance', 'Blindaje · tobillo, rodilla y cadera', 'fCyo94-Y2Vs');
      perform pg_temp.blindaje(s, 4, 'Equilibrio a una pierna con rodilla arriba', 'Blindaje · tobillo y rodilla', '8mD9DHn2eik');
    elsif t ilike '%Tren Superior%' then
      perform pg_temp.blindaje(s, 2, 'Rotación de tronco en 90/90', 'Movilidad · columna y cadera', 'uCszPKmZr8Q');
      perform pg_temp.blindaje(s, 3, '90/90 con brazos abiertos', 'Movilidad · cadera', 'B6HmWp7O_Ac');
    else
      perform pg_temp.blindaje(s, 2, 'Limpiaparabrisas de cadera', 'Movilidad · cadera', 'sKVd-J1hwdU');
      perform pg_temp.blindaje(s, 3, 'Abducción de cadera acostada de lado', 'Blindaje · cadera y glúteo medio', '79YXDJk531o');
      perform pg_temp.blindaje(s, 4, 'Cambio 90/90 con brazos cruzados', 'Movilidad · cadera', 'lrS1Nchm91M');
    end if;
  end loop;

  -- Recuperación Activa: blindaje ligero de rodilla y cadera después de los Ejercicios 1-7 de tobillo
  for s in select distinct x.id from public.sessions x join public.plantilla_tarjetas pt on pt.session_id = x.id
           where x.session_type ilike 'Recuperaci%' loop
    update public.exercises set order_index = 99 where session_id = s and name = 'Recuperación muscular';
    perform pg_temp.blindaje(s, 10, 'Zancada isométrica con inclinación', 'Blindaje ligero · rodilla y cadera', 'tiEKyJ6siQ0');
    perform pg_temp.blindaje(s, 11, 'Sentadilla a una pierna con pierna al frente', 'Blindaje ligero · rodilla', '2tb1YwY6xw8');
    perform pg_temp.blindaje(s, 12, 'Levantarse de la silla a una pierna', 'Blindaje ligero · rodilla', 'Su8QycF5aqA');
    perform pg_temp.blindaje(s, 13, 'Cambio 90/90 con brazos al frente', 'Blindaje ligero · cadera', 'f5JYgOawcaM');
    perform pg_temp.blindaje(s, 14, 'Abducción de cadera acostada de lado (otro lado)', 'Blindaje ligero · cadera y glúteo medio', 'xljtfZQIJfI');
  end loop;

  -- Las clientas lunares tienen octubre generado con las sesiones anteriores: recalcular lo pendiente desde hoy
  for s in select id from public.profiles where ruta = 'lunar' loop
    perform public.regenerar_motor(s, '2026-10-07');
  end loop;
end $$;
