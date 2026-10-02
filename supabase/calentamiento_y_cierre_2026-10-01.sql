-- Agrega calentamiento (bloques 1-2) y cierre (bloque 5) a las sesiones de entrenamiento del motor.
-- Fuente: la sesión de Recuperación Activa dc41632a-… (Movilidad, Blindaje + Ejercicios 1-7, Recuperación muscular).
-- Los ejercicios existentes no cambian, solo se corren de order_index 1..5 a 11..15.

-- Rollback:
--   delete from exercises where session_id in (<sesiones>) and (order_index between 1 and 9 or order_index = 99);
--   update exercises set order_index = order_index - 10 where session_id in (<sesiones>);

with destino as (
  select distinct t.session_id from plantilla_tarjetas t join sessions s on s.id = t.session_id
  where s.session_type not ilike 'Recuperaci%'
)
update exercises set order_index = order_index + 10 where session_id in (select session_id from destino);

with destino as (
  select distinct t.session_id from plantilla_tarjetas t join sessions s on s.id = t.session_id
  where s.session_type not ilike 'Recuperaci%'
), fuente as (
  select * from exercises where session_id = 'dc41632a-4daa-4e2b-9cec-a35729b20579'
)
insert into exercises (session_id, name, muscle_group, sets_count, reps_range, video_url, order_index, bloque)
select d.session_id, f.name, f.muscle_group, f.sets_count, f.reps_range, f.video_url,
  case when f.name = 'Recuperación muscular' then 99 else f.order_index end,
  case when f.name ilike 'Movilidad%' then 1 when f.name = 'Recuperación muscular' then 5 else 2 end
from destino d cross join fuente f;

-- Bloques también en las sesiones de Recuperación Activa
update exercises e set bloque = case when e.name ilike 'Movilidad%' then 1 when e.name = 'Recuperación muscular' then 5 else 2 end
where e.session_id in (select distinct t.session_id from plantilla_tarjetas t join sessions s on s.id = t.session_id
                       where s.session_type ilike 'Recuperaci%') and e.bloque is null;
