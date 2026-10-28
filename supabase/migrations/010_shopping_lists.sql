-- ============================================================================
-- 010 — Listas de compras (múltiplas listas + itens por setor)
-- ============================================================================
-- Substitui o modelo plano de `pre_shopping_list_items` por listas nomeadas.
-- Visitantes continuam 100% locais; usuários autenticados sincronizam aqui.
-- ============================================================================

create table if not exists public.listas_compras (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  icon text not null default '🛒',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.itens_lista (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  list_id uuid not null
    references public.listas_compras(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  quantity numeric(10,3) not null default 1 check (quantity > 0),
  unit text not null default 'un'
    check (unit in ('un', 'kg', 'g', 'L', 'ml', 'cx', 'pacote', 'dz')),
  estimated_price numeric(10,2)
    check (estimated_price is null or estimated_price >= 0),
  sector text not null default 'outros'
    check (sector in ('hortifruti', 'acougue', 'laticinios', 'limpeza',
                      'mercearia', 'padaria', 'outros')),
  is_bought boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_listas_compras_user_created
  on public.listas_compras (user_id, created_at asc);
create index if not exists idx_itens_lista_list_sector
  on public.itens_lista (list_id, sector, created_at asc);
create index if not exists idx_itens_lista_user
  on public.itens_lista (user_id);

-- --------------------------------------------------------------------------
-- Categorização usada apenas na migração dos itens antigos. O app categoriza
-- novos itens em Dart (ShoppingSector.categorize).
-- --------------------------------------------------------------------------
create or replace function public.shopping_sector_for_name(p_name text)
returns text
language sql
immutable
as $$
  select case
    when lower(p_name) ~ '(leite condensado|leite em po|leite em pó)' then 'mercearia'
    when lower(p_name) ~ '(tomate|alface|maca|maçã|banana|cebola|batata|cenoura|laranja|limao|limão|uva|morango|abacaxi|melancia|brocolis|brócolis|couve|pepino|abobrinha|berinjela|pimentao|pimentão|alho|fruta|verdura|legume)' then 'hortifruti'
    when lower(p_name) ~ '(carne|patinho|moid|frango|peixe|file|filé|picanha|alcatra|costela|linguica|linguiça|salsicha|bacon|camarao|camarão)' then 'acougue'
    when lower(p_name) ~ '(pao|pão|bolo|biscoito|bolacha|cereal|aveia|granola|achocolatado|cafe|café)' then 'padaria'
    when lower(p_name) ~ '(detergente|sabao|sabão|amaciante|desinfetante|agua sanitaria|água sanitária|multiuso|esponja|vassoura|rodo|papel higienico|papel higiênico)' then 'limpeza'
    when lower(p_name) ~ '(leite|queijo|manteiga|margarina|iogurte|requeijao|requeijão|nata|ovos|ovo|presunto|mortadela|salame|sorvete)' then 'laticinios'
    when lower(p_name) ~ '(arroz|feijao|feijão|oleo|óleo|acucar|açúcar|macarrao|macarrão|farinha|sal|molho|atum|sardinha|milho|ervilha|azeite|vinagre|tempero)' then 'mercearia'
    else 'outros'
  end;
$$;

comment on function public.shopping_sector_for_name(text)
  is 'Categoriza nomes de itens nos setores da lista de compras.';

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.listas_compras enable row level security;
alter table public.itens_lista enable row level security;

drop policy if exists "Users can read own shopping lists"
  on public.listas_compras;
create policy "Users can read own shopping lists"
  on public.listas_compras
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own shopping lists"
  on public.listas_compras;
create policy "Users can insert own shopping lists"
  on public.listas_compras
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own shopping lists"
  on public.listas_compras;
create policy "Users can update own shopping lists"
  on public.listas_compras
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own shopping lists"
  on public.listas_compras;
create policy "Users can delete own shopping lists"
  on public.listas_compras
  for delete
  using (auth.uid() = user_id);

drop policy if exists "Users can read own shopping list items"
  on public.itens_lista;
create policy "Users can read own shopping list items"
  on public.itens_lista
  for select
  using (
    auth.uid() = user_id
    and exists (
      select 1 from public.listas_compras l
      where l.id = itens_lista.list_id and l.user_id = auth.uid()
    )
  );

drop policy if exists "Users can insert own shopping list items"
  on public.itens_lista;
create policy "Users can insert own shopping list items"
  on public.itens_lista
  for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.listas_compras l
      where l.id = itens_lista.list_id and l.user_id = auth.uid()
    )
  );

drop policy if exists "Users can update own shopping list items"
  on public.itens_lista;
create policy "Users can update own shopping list items"
  on public.itens_lista
  for update
  using (
    auth.uid() = user_id
    and exists (
      select 1 from public.listas_compras l
      where l.id = itens_lista.list_id and l.user_id = auth.uid()
    )
  )
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.listas_compras l
      where l.id = itens_lista.list_id and l.user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete own shopping list items"
  on public.itens_lista;
create policy "Users can delete own shopping list items"
  on public.itens_lista
  for delete
  using (
    auth.uid() = user_id
    and exists (
      select 1 from public.listas_compras l
      where l.id = itens_lista.list_id and l.user_id = auth.uid()
    )
  );

-- --------------------------------------------------------------------------
-- updated_at
-- --------------------------------------------------------------------------
drop trigger if exists trg_listas_compras_updated_at
  on public.listas_compras;
create trigger trg_listas_compras_updated_at
  before update on public.listas_compras
  for each row execute function public.update_updated_at_column();

drop trigger if exists trg_itens_lista_updated_at
  on public.itens_lista;
create trigger trg_itens_lista_updated_at
  before update on public.itens_lista
  for each row execute function public.update_updated_at_column();

grant select, insert, update, delete
  on public.listas_compras
  to authenticated;
grant select, insert, update, delete
  on public.itens_lista
  to authenticated;

-- --------------------------------------------------------------------------
-- Migração dos itens antigos para uma lista "Minha Lista" por usuário.
-- Idempotente: não cria outra lista se o usuário já tiver uma com esse nome.
-- --------------------------------------------------------------------------
with users_with_items as (
  select distinct user_id
  from public.pre_shopping_list_items
),
inserted_lists as (
  insert into public.listas_compras (user_id, name, icon)
  select u.user_id, 'Minha Lista', '🛒'
  from users_with_items u
  where not exists (
    select 1
    from public.listas_compras l
    where l.user_id = u.user_id and l.name = 'Minha Lista'
  )
  returning id, user_id
)
insert into public.itens_lista (
  user_id,
  list_id,
  name,
  quantity,
  unit,
  sector,
  is_bought,
  created_at,
  updated_at
)
select
  i.user_id,
  l.id,
  i.name,
  1,
  'un',
  public.shopping_sector_for_name(i.name),
  i.is_bought,
  i.created_at,
  i.updated_at
from public.pre_shopping_list_items i
join inserted_lists l on l.user_id = i.user_id;
