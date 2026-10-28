-- ============================================================================
-- 009 — Lista de compras prévia (checklist de planejamento)
-- ============================================================================
-- Visitantes salvam apenas no dispositivo. Utilizadores autenticados têm a
-- lista sincronizada nesta tabela, sempre isolada por `user_id` via RLS.
-- ============================================================================

create table if not exists public.pre_shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  is_bought boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_pre_shopping_list_user_created
  on public.pre_shopping_list_items (user_id, created_at asc);

alter table public.pre_shopping_list_items enable row level security;

drop policy if exists "Users can read own pre shopping list"
  on public.pre_shopping_list_items;
create policy "Users can read own pre shopping list"
  on public.pre_shopping_list_items
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own pre shopping list"
  on public.pre_shopping_list_items;
create policy "Users can insert own pre shopping list"
  on public.pre_shopping_list_items
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own pre shopping list"
  on public.pre_shopping_list_items;
create policy "Users can update own pre shopping list"
  on public.pre_shopping_list_items
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own pre shopping list"
  on public.pre_shopping_list_items;
create policy "Users can delete own pre shopping list"
  on public.pre_shopping_list_items
  for delete
  using (auth.uid() = user_id);

drop trigger if exists trg_pre_shopping_list_updated_at
  on public.pre_shopping_list_items;
create trigger trg_pre_shopping_list_updated_at
  before update on public.pre_shopping_list_items
  for each row execute function public.update_updated_at_column();

grant select, insert, update, delete
  on public.pre_shopping_list_items
  to authenticated;
