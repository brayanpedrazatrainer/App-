-- Migración "seguridad_permisos" (2026-09-27). Rollback: rollback_seguridad_2026-09-27.sql
-- Cierra: cuentas nuevas creadas como admin, clientas editando perfiles ajenos o su propio is_admin,
-- clientas editando programas/sesiones/ejercicios, y tablas del motor/grupos abiertas sin sesión.

-- 1. Ninguna cuenta nueva nace como admin
create or replace function public.handle_new_user()
 returns trigger language plpgsql security definer set search_path = public as $function$
begin
  insert into public.profiles (id, name, is_admin)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'Cliente'), false);
  return new;
end;
$function$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
alter function public.is_admin() set search_path = public;

-- 2. profiles: cada clienta ve y actualiza solo el suyo; el admin todo
drop policy if exists "Solo autenticados" on public.profiles;
drop policy if exists allow_insert_profile on public.profiles;
drop policy if exists authenticated_read_profiles on public.profiles;
drop policy if exists update_own_profile on public.profiles;
create policy "Perfil: lectura propia o admin" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy "Perfil: actualizacion propia o admin" on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy "Perfil: admin crea" on public.profiles for insert to authenticated with check (public.is_admin());
create policy "Perfil: admin borra" on public.profiles for delete to authenticated using (public.is_admin());

-- Una clienta solo puede cambiar su ancla (botón "Me llegó el período").
-- El admin y el panel de Supabase (sin JWT) pueden cambiar todo.
create or replace function public.proteger_perfil()
 returns trigger language plpgsql security definer set search_path = public as $function$
begin
  if coalesce(auth.role(), '') not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  if (to_jsonb(new) - 'ancla') is distinct from (to_jsonb(old) - 'ancla') then
    raise exception 'Solo se puede actualizar la fecha del período';
  end if;
  return new;
end;
$function$;
revoke execute on function public.proteger_perfil() from public, anon, authenticated;
create trigger proteger_perfil before update on public.profiles
  for each row execute function public.proteger_perfil();

-- 3. Contenido de entrenamiento: lectura para clientas, escritura solo admin (políticas "Admin gestiona …" existentes)
drop policy if exists "Solo autenticados" on public.programs;
drop policy if exists "Solo autenticados" on public.sessions;
drop policy if exists "Solo autenticados" on public.exercises;
drop policy if exists "Solo autenticados" on public.client_programs;
create policy "Autenticados leen" on public.programs for select to authenticated using (true);
create policy "Autenticados leen" on public.sessions for select to authenticated using (true);
create policy "Autenticados leen" on public.exercises for select to authenticated using (true);

-- 4. Tablas del motor y grupos: RLS encendido, lectura con sesión, escritura solo admin
do $$
declare t text;
begin
  foreach t in array array['plantillas','plantilla_tarjetas','equivalencias','grupos'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "Autenticados leen" on public.%I for select to authenticated using (true)', t);
    execute format('create policy "Admin gestiona" on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;
