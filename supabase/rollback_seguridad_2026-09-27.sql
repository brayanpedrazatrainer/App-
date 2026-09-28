-- Deshace la migración "seguridad_permisos" (2026-09-27) y deja los permisos como estaban antes.
-- Ejecutar en Supabase → SQL Editor solo si la app deja de funcionar tras el cambio.

-- profiles
drop trigger if exists proteger_perfil on public.profiles;
drop function if exists public.proteger_perfil();
drop policy if exists "Perfil: lectura propia o admin" on public.profiles;
drop policy if exists "Perfil: actualizacion propia o admin" on public.profiles;
drop policy if exists "Perfil: admin crea" on public.profiles;
drop policy if exists "Perfil: admin borra" on public.profiles;
create policy "Solo autenticados" on public.profiles for all to authenticated using (true) with check (true);
create policy allow_insert_profile on public.profiles for insert to public with check (true);
create policy authenticated_read_profiles on public.profiles for select to public using (auth.role() = 'authenticated');
create policy update_own_profile on public.profiles for update to public using (auth.uid() = id);

-- programas, sesiones, ejercicios, asignaciones
drop policy if exists "Autenticados leen" on public.programs;
drop policy if exists "Autenticados leen" on public.sessions;
drop policy if exists "Autenticados leen" on public.exercises;
create policy "Solo autenticados" on public.programs for all to authenticated using (true) with check (true);
create policy "Solo autenticados" on public.sessions for all to authenticated using (true) with check (true);
create policy "Solo autenticados" on public.exercises for all to authenticated using (true) with check (true);
create policy "Solo autenticados" on public.client_programs for all to authenticated using (true) with check (true);

-- tablas del motor y grupos
do $$
declare t text;
begin
  foreach t in array array['plantillas','plantilla_tarjetas','equivalencias','grupos'] loop
    execute format('drop policy if exists "Autenticados leen" on public.%I', t);
    execute format('drop policy if exists "Admin gestiona" on public.%I', t);
    execute format('alter table public.%I disable row level security', t);
  end loop;
end $$;

-- funciones
create or replace function public.handle_new_user()
 returns trigger language plpgsql security definer as $function$
begin
  insert into public.profiles (id, name, is_admin)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'Cliente'),
          coalesce((new.raw_user_meta_data->>'is_admin')::boolean, false));
  return new;
end;
$function$;
alter function public.handle_new_user() reset search_path;
alter function public.is_admin() reset search_path;
grant execute on function public.handle_new_user() to anon, authenticated;
