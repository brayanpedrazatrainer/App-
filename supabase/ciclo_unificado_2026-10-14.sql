-- Ciclo unificado (2026-10-14)
-- La pestaña Ciclo y las rutinas usan el mismo dato: profiles.ancla (primer día del período) y
-- profiles.duracion_ciclo. "Mi sangrado" y la barra de duración de la app actualizan el perfil
-- y reorganizan las rutinas (regenerar_motor). Antes "Mi sangrado" solo guardaba en cycle_logs.
-- La clienta puede cambiar en su perfil solo: ancla y duracion_ciclo.

create or replace function public.proteger_perfil()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if coalesce(auth.role(), '') not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  if (to_jsonb(new) - 'ancla' - 'duracion_ciclo') is distinct from (to_jsonb(old) - 'ancla' - 'duracion_ciclo') then
    raise exception 'Solo se puede actualizar la fecha del período y la duración del ciclo';
  end if;
  return new;
end;
$$;

-- Rango que entiende el motor (fuera de 22–40 todo caería en menguante B)
alter table public.profiles drop constraint if exists profiles_duracion_ciclo_check;
alter table public.profiles add constraint profiles_duracion_ciclo_check check (duracion_ciclo between 22 and 40);

-- Laura: su período empezó el 9 de octubre (lo marcó en "Mi sangrado", que no llegaba a las rutinas)
-- update profiles set ancla = '2026-10-09' where name = 'Laura';  -- aplicado a mano el 2026-10-14
-- select regenerar_motor((select id from profiles where name = 'Laura'), '2026-10-14');

-- Rollback: volver a la versión anterior del trigger (solo 'ancla') y
-- alter table public.profiles drop constraint if exists profiles_duracion_ciclo_check;
