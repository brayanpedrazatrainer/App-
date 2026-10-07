-- Migración "variantes" (2026-10-02)
-- Cada ejercicio de fuerza pertenece a una familia (movimiento) y tiene un equipo.
-- La app reemplaza el ejercicio según el escenario que elige la clienta:
--   C Gimnasio: nunca reemplaza (en el gimnasio hay de todo).
--   B Mancuernas: reemplaza solo si equipo = 'gimnasio' (máquina o barra).
--   A Solo cuerpo: reemplaza si equipo in ('mancuernas','gimnasio'). La banda se queda.
-- Las series, repeticiones, tempo e indicaciones del ejercicio programado no cambian.
-- Rollback: drop table public.variantes; alter table public.exercises drop column familia, drop column equipo;

create table if not exists public.variantes (
  familia text not null,
  escenario text not null check (escenario in ('A','B','C')),
  nombre text not null,
  video_url text,
  descripcion text,
  primary key (familia, escenario)
);
alter table public.variantes enable row level security;
create policy "Autenticados leen" on public.variantes for select to authenticated using (true);
create policy "Admin gestiona" on public.variantes for all to authenticated using (public.is_admin()) with check (public.is_admin());

alter table public.exercises add column if not exists familia text;
alter table public.exercises add column if not exists equipo text check (equipo in ('cuerpo','mancuernas','banda','gimnasio'));

-- Versiones dictadas por Brayan el 2026-10-02 (las existentes toman el video que ya tenían)
insert into public.variantes (familia, escenario, nombre, video_url, descripcion) values
 ('peso_muerto_rumano','A','Peso muerto rumano sin peso','https://youtube.com/shorts/QLauVjByhGY','Igual que en el video, pero sin mancuernas.'),
 ('peso_muerto_rumano','B','Peso muerto rumano con mancuernas','https://youtube.com/shorts/QLauVjByhGY',null),
 ('peso_muerto_rumano','C','Peso muerto rumano con barra','https://youtube.com/shorts/1jvfocvQARU',null),
 ('sentadilla','A','Sentadilla peso corporal','https://youtube.com/shorts/DcGCOTtXbyk',null),
 ('sentadilla','B','Sentadilla goblet','https://youtube.com/shorts/s7zhYdR1pUk',null),
 ('sentadilla','C','Sentadilla en Smith','https://youtube.com/shorts/Dhk2WYZYZe8',null),
 ('zancada','A','Zancada estática sin peso','https://youtube.com/shorts/CamwCHDbWqc','Igual que en el video, pero sin mancuernas.'),
 ('zancada','B','Zancada estática con mancuernas','https://youtube.com/shorts/CamwCHDbWqc',null),
 ('press_pecho','A','Flexión sobre rodillas','https://youtube.com/shorts/tSnVup1OzGg',null),
 ('press_pecho','B','Press de pecho con mancuernas','https://youtube.com/shorts/WkyZgj4y89U',null),
 ('press_hombro','A','Press de hombro sin peso','https://youtube.com/shorts/6xMiXKRbO-w','Igual que en el video, pero sin mancuernas.'),
 ('press_hombro','B','Press de hombro sentada con mancuernas','https://youtube.com/shorts/6xMiXKRbO-w',null),
 ('press_hombro','C','Press militar con mancuernas','https://youtube.com/shorts/5nY5xmEoRB0',null),
 ('hip_thrust','A','Puente de glúteo','https://youtube.com/shorts/LdxuIIRc_EA',null),
 ('hip_thrust','B','Hip thrust con mancuerna sobre cadera','https://youtube.com/shorts/GtSaWk_H25M',null),
 ('hip_thrust','C','Hip thrust en Smith','https://youtube.com/shorts/Rk4O-UzF_uk',null),
 ('remo','A','Remo solo cuerpo','https://youtube.com/shorts/tlqlLuuDI2g',null),
 ('remo','B','Remo con mancuerna a un brazo','https://youtube.com/shorts/XxYHzVP8tjw',null),
 ('remo','C','Remo con barra','https://youtube.com/shorts/NFU8wtM-5Xs',null),
 ('jalon','B','Jalón con banda','https://youtube.com/shorts/8a2E_4MV-0U',null),
 ('jalon','C','Jalón en máquina','https://youtube.com/shorts/oKbpKEJCf38',null)
on conflict (familia, escenario) do nothing;

-- Familia y equipo de los ejercicios existentes
update public.exercises set familia='peso_muerto_rumano', equipo = case when name ilike '%barra%' then 'gimnasio' else 'mancuernas' end
  where name ilike 'Peso muerto rumano%';
update public.exercises set familia='sentadilla', equipo = case when name ilike '%Smith%' then 'gimnasio' when name ilike '%goblet%' then 'mancuernas' else 'cuerpo' end
  where name ilike 'Sentadilla en Smith%' or name ilike 'Sentadilla goblet%' or name = 'Sentadilla peso corporal';
update public.exercises set familia='zancada', equipo='mancuernas' where name ilike 'Zancada estática%';
update public.exercises set familia='press_pecho', equipo='mancuernas' where name ilike 'Press de pecho con mancuernas%';
update public.exercises set familia='press_hombro', equipo='mancuernas' where name = 'Press hombro sentada con mancuernas';
update public.exercises set familia='hip_thrust', equipo = case when name ilike '%Smith%' then 'gimnasio' when name ilike '%mancuerna%' then 'mancuernas' else 'cuerpo' end
  where name ilike 'Hip thrust%' or name ilike 'Puente de glúteo%';
update public.exercises set familia='remo', equipo='mancuernas' where name = 'Remo con mancuerna a un brazo';
update public.exercises set familia='jalon', equipo='banda' where name = 'Jalón con banda';

-- 2026-10-07: faltaba este permiso; sin él la app de las clientas no podía leer las versiones y no reemplazaba nada
grant select, insert, update, delete on public.variantes to authenticated;
-- 2026-10-07: versiones Solo cuerpo de jalón y pallof
insert into public.variantes (familia, escenario, nombre, video_url) values
 ('jalon','A','Jalón acostado con toalla','https://youtube.com/shorts/U7k4i4yVXEI'),
 ('pallof','A','Pallof con mano','https://youtube.com/shorts/Gon_UpBO-ZU'),
 ('pallof','B','Pallof press con banda','https://youtube.com/shorts/KFgtBsL_kkM')
on conflict (familia, escenario) do nothing;
update public.exercises set familia='pallof', equipo='banda' where name='Pallof press con banda';
