-- ============================================================================
-- 008 — Perfil editável (nome + avatar)
-- ============================================================================
-- 1. Garante que todo usuário tenha uma linha em `profiles`.
-- 2. Permite ao usuário criar/atualizar o próprio perfil.
-- 3. Cria o bucket público `avatars` com isolamento por pasta (`{user_id}/...`).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Backfill dos usuários existentes
-- ---------------------------------------------------------------------------
insert into public.profiles (id, display_name, avatar_url)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(u.raw_user_meta_data->>'name'), ''),
    nullif(split_part(u.email, '@', 1), ''),
    'Usuário'
  ),
  nullif(trim(u.raw_user_meta_data->>'avatar_url'), '')
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Cria o perfil automaticamente em novos cadastros
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'name'), ''),
      nullif(split_part(new.email, '@', 1), ''),
      'Usuário'
    ),
    nullif(trim(new.raw_user_meta_data->>'avatar_url'), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 3. Política de INSERT para o próprio perfil (usada pelo upsert do app)
-- ---------------------------------------------------------------------------
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- 4. Bucket de avatares (público para leitura, upload isolado por usuário)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatares são públicos" on storage.objects;
create policy "Avatares são públicos"
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "Usuário envia o próprio avatar" on storage.objects;
create policy "Usuário envia o próprio avatar"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Usuário atualiza o próprio avatar" on storage.objects;
create policy "Usuário atualiza o próprio avatar"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Usuário apaga o próprio avatar" on storage.objects;
create policy "Usuário apaga o próprio avatar"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
