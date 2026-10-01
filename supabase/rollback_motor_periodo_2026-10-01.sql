-- Deshace "motor_periodo" (2026-10-01). Las filas de scheduled_sessions se conservan.
drop function if exists public.regenerar_motor(uuid, date);
drop function if exists public.generar_motor(uuid, date, date);
alter table public.scheduled_sessions drop column if exists origen;
