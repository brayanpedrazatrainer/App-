-- Las clases en vivo (corrección y en vivo semanal) ahora son en Skool; ya no se usa Meet (Brayan 2026-10-30).
-- Link por defecto: el calendario de la comunidad, donde se entra a la llamada en vivo.
alter table public.clases_horario alter column link set default 'https://www.skool.com/gym-virtual-ciclico-6444/calendar';
update public.clases_horario set link='https://www.skool.com/gym-virtual-ciclico-6444/calendar' where link is null or link ilike '%meet.google%';
update public.grupos set zoom_url='https://www.skool.com/gym-virtual-ciclico-6444/calendar' where zoom_url ilike '%meet.google%';
