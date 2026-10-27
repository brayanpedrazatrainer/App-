-- Nivel inicial (2026-10-27, Brayan): toda clienta nueva empieza en nivel 1 (principiante).
alter table public.profiles alter column nivel set default 1;
-- Rollback: alter table public.profiles alter column nivel set default 2;
