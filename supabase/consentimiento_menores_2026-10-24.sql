-- Consentimiento de acudientes para clientas menores de edad (2026-10-24)
-- Brayan genera un enlace (token de un solo uso, 30 días) desde la ficha; el acudiente lo abre en consentimiento.html
-- sin cuenta, firma con el dedo y queda guardado el texto exacto que firmó, con fecha y hora del servidor.
-- El acudiente (anon) nunca lee ni escribe tablas: solo las dos funciones de abajo, que validan el token.

create table if not exists public.consentimiento_solicitudes (
  token uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  creado timestamptz not null default now(),
  vence timestamptz not null default now() + interval '30 days',
  usado boolean not null default false
);

create table if not exists public.consentimientos (
  id bigint generated always as identity primary key,
  client_id uuid not null references public.profiles(id) on delete cascade,
  token uuid not null,
  acudiente_nombre text not null,
  acudiente_documento text not null,
  parentesco text not null,
  acudiente_email text,
  acudiente_telefono text,
  autoriza_fotos boolean not null default false,
  texto_version text not null,
  texto_firmado text not null,
  firma text not null,
  user_agent text,
  firmado_at timestamptz not null default now()
);

alter table public.consentimiento_solicitudes enable row level security;
alter table public.consentimientos enable row level security;
drop policy if exists "Solicitudes: admin" on public.consentimiento_solicitudes;
create policy "Solicitudes: admin" on public.consentimiento_solicitudes for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Consentimientos: admin lee" on public.consentimientos;
create policy "Consentimientos: admin lee" on public.consentimientos for select to authenticated using (public.is_admin());
drop policy if exists "Consentimientos: la clienta ve el suyo" on public.consentimientos;
create policy "Consentimientos: la clienta ve el suyo" on public.consentimientos for select to authenticated using (client_id = auth.uid());
grant select, insert, update, delete on public.consentimiento_solicitudes to authenticated;
grant select on public.consentimientos to authenticated;

-- Lo que ve el acudiente al abrir el enlace: el primer nombre de la menor, si el enlace sirve
create or replace function public.datos_consentimiento(p_token uuid)
returns json language plpgsql security definer set search_path to 'public' as $$
declare r record;
begin
  select s.usado, s.vence, p.name into r
  from consentimiento_solicitudes s join profiles p on p.id = s.client_id where s.token = p_token;
  if not found then return json_build_object('estado','no_existe'); end if;
  if r.usado then return json_build_object('estado','usado'); end if;
  if r.vence < now() then return json_build_object('estado','vencido'); end if;
  return json_build_object('estado','ok','menor', r.name);
end; $$;

create or replace function public.firmar_consentimiento(
  p_token uuid, p_nombre text, p_documento text, p_parentesco text, p_email text, p_telefono text,
  p_fotos boolean, p_version text, p_texto text, p_firma text, p_ua text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare v_client uuid;
begin
  select client_id into v_client from consentimiento_solicitudes
  where token = p_token and not usado and vence >= now() for update;
  if v_client is null then raise exception 'El enlace no es válido, ya se usó o venció'; end if;
  if coalesce(length(trim(p_nombre)),0) < 3 or coalesce(length(trim(p_documento)),0) < 4 or coalesce(length(trim(p_parentesco)),0) < 3 then
    raise exception 'Faltan datos del acudiente'; end if;
  if p_firma is null or left(p_firma, 22) <> 'data:image/png;base64,' or length(p_firma) > 400000 then
    raise exception 'Firma no válida'; end if;
  if p_texto is null or length(p_texto) < 200 or length(p_texto) > 20000 then raise exception 'Texto no válido'; end if;
  insert into consentimientos (client_id, token, acudiente_nombre, acudiente_documento, parentesco, acudiente_email, acudiente_telefono,
                               autoriza_fotos, texto_version, texto_firmado, firma, user_agent)
  values (v_client, p_token, left(trim(p_nombre),120), left(trim(p_documento),40), left(trim(p_parentesco),40),
          nullif(left(trim(coalesce(p_email,'')),120),''), nullif(left(trim(coalesce(p_telefono,'')),40),''),
          coalesce(p_fotos,false), left(p_version,40), p_texto, p_firma, left(p_ua,300));
  update consentimiento_solicitudes set usado = true where token = p_token;
  return 'ok';
end; $$;

revoke execute on function public.datos_consentimiento(uuid) from public;
revoke execute on function public.firmar_consentimiento(uuid,text,text,text,text,text,boolean,text,text,text,text) from public;
grant execute on function public.datos_consentimiento(uuid) to anon, authenticated;
grant execute on function public.firmar_consentimiento(uuid,text,text,text,text,text,boolean,text,text,text,text) to anon, authenticated;

-- Rollback:
-- drop function if exists public.firmar_consentimiento(uuid,text,text,text,text,text,boolean,text,text,text,text);
-- drop function if exists public.datos_consentimiento(uuid);
-- drop table if exists public.consentimientos; drop table if exists public.consentimiento_solicitudes;
