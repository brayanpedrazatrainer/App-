-- Perfil de alimentación (2026-10-22): campos que pone Brayan en la ficha de cada clienta.
-- objetivo: tonificar | bajar_grasa | recomposicion (para proteína y calorías).
-- anticonceptivo_metodo + anticonceptivo_nombre (marca comercial): para el tip según el método.
-- La clienta no los puede cambiar (proteger_perfil solo le deja ancla y duracion_ciclo).
alter table public.profiles
  add column if not exists objetivo text,
  add column if not exists anticonceptivo_metodo text,
  add column if not exists anticonceptivo_nombre text;

alter table public.profiles drop constraint if exists profiles_objetivo_check;
alter table public.profiles add constraint profiles_objetivo_check
  check (objetivo is null or objetivo in ('tonificar','bajar_grasa','recomposicion'));

alter table public.profiles drop constraint if exists profiles_anticonceptivo_check;
alter table public.profiles add constraint profiles_anticonceptivo_check
  check (anticonceptivo_metodo is null or anticonceptivo_metodo in
    ('pildora_combinada','pildora_progestina','anillo','parche','inyeccion_mensual','inyeccion_trimestral','implante','diu_hormonal','diu_cobre','otro'));

-- Rollback:
-- alter table public.profiles drop constraint if exists profiles_objetivo_check, drop constraint if exists profiles_anticonceptivo_check;
-- alter table public.profiles drop column if exists objetivo, drop column if exists anticonceptivo_metodo, drop column if exists anticonceptivo_nombre;
