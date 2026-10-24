-- Límite de calorías y suplementos (2026-10-24)
-- profiles.actividad: actividad diaria SIN contar el entreno (sedentaria ×1.2, ligera ×1.3, activa ×1.45). La pone Brayan.
-- suplementos: los que toma cada clienta (nombre + dosis). suplementos_log: marca de "tomado" por día.
-- Cada clienta lo suyo; el admin lee todo.

alter table public.profiles add column if not exists actividad text;
alter table public.profiles drop constraint if exists profiles_actividad_check;
alter table public.profiles add constraint profiles_actividad_check
  check (actividad is null or actividad in ('sedentaria','ligera','activa'));

create table if not exists public.suplementos (
  id bigint generated always as identity primary key,
  client_id uuid not null references public.profiles(id) on delete cascade,
  nombre text not null check (length(nombre) between 1 and 60),
  dosis text check (dosis is null or length(dosis) <= 60),
  activo boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.suplementos_log (
  client_id uuid not null references public.profiles(id) on delete cascade,
  suplemento_id bigint not null references public.suplementos(id) on delete cascade,
  fecha date not null,
  primary key (suplemento_id, fecha)
);
create index if not exists suplementos_log_cliente_fecha on public.suplementos_log (client_id, fecha);

alter table public.suplementos enable row level security;
alter table public.suplementos_log enable row level security;
drop policy if exists "Suplementos: propios" on public.suplementos;
create policy "Suplementos: propios" on public.suplementos for all to authenticated using (client_id = auth.uid()) with check (client_id = auth.uid());
drop policy if exists "Suplementos: admin lee" on public.suplementos;
create policy "Suplementos: admin lee" on public.suplementos for select to authenticated using (public.is_admin());
drop policy if exists "Suplementos log: propios" on public.suplementos_log;
create policy "Suplementos log: propios" on public.suplementos_log for all to authenticated using (client_id = auth.uid()) with check (client_id = auth.uid());
drop policy if exists "Suplementos log: admin lee" on public.suplementos_log;
create policy "Suplementos log: admin lee" on public.suplementos_log for select to authenticated using (public.is_admin());
grant select, insert, update, delete on public.suplementos, public.suplementos_log to authenticated;

-- Rollback:
-- drop table if exists public.suplementos_log; drop table if exists public.suplementos;
-- alter table public.profiles drop constraint if exists profiles_actividad_check, drop column if exists actividad;
