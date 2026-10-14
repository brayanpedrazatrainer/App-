-- Acceso y pago por clienta (2026-10-13)
-- estado: 'activa' entra normal; 'pausada' ve una pantalla de pausa en la app.
-- pagado_hasta: último día pagado. La app avisa 5 días antes y cuando vence (no bloquea sola).
-- Las clientas no pueden cambiar estos campos: el trigger proteger_perfil solo les deja cambiar "ancla".
alter table public.profiles
  add column if not exists estado text not null default 'activa',
  add column if not exists pagado_hasta date;

alter table public.profiles drop constraint if exists profiles_estado_check;
alter table public.profiles add constraint profiles_estado_check check (estado in ('activa','pausada'));

-- Rollback:
-- alter table public.profiles drop constraint if exists profiles_estado_check;
-- alter table public.profiles drop column if exists estado, drop column if exists pagado_hasta;
