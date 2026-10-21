-- SomaAí - Purchase history and monthly spending
-- Run after 001_initial_schema.sql
--
-- The app is local-first: purchases are always written to SharedPreferences.
-- When there is an authenticated Supabase user, CheckoutService mirrors the
-- summary here. Monthly spending is derived from purchases, never stored twice.

create table if not exists purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  store_name text not null default 'Mercado',
  total numeric(12, 2) not null check (total >= 0),
  savings numeric(12, 2) not null default 0 check (savings >= 0),
  item_count int not null default 0 check (item_count >= 0),
  purchased_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_purchases_user_date
  on purchases (user_id, purchased_at desc);

create table if not exists purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references purchases(id) on delete cascade,
  name text not null,
  unit text not null default 'un',
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  quantity int not null check (quantity > 0),
  total_price numeric(12, 2) generated always as (unit_price * quantity) stored,
  created_at timestamptz not null default now()
);

create index if not exists idx_purchase_items_purchase
  on purchase_items (purchase_id);

alter table purchases enable row level security;
alter table purchase_items enable row level security;

create policy "Users can read own purchases"
  on purchases for select
  using (auth.uid() = user_id);

create policy "Users can insert own purchases"
  on purchases for insert
  with check (auth.uid() = user_id);

create policy "Users can update own purchases"
  on purchases for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own purchases"
  on purchases for delete
  using (auth.uid() = user_id);

create policy "Users can read own purchase items"
  on purchase_items for select
  using (
    exists (
      select 1
      from purchases p
      where p.id = purchase_items.purchase_id
        and p.user_id = auth.uid()
    )
  );

create policy "Users can insert own purchase items"
  on purchase_items for insert
  with check (
    exists (
      select 1
      from purchases p
      where p.id = purchase_items.purchase_id
        and p.user_id = auth.uid()
    )
  );

create policy "Users can delete own purchase items"
  on purchase_items for delete
  using (
    exists (
      select 1
      from purchases p
      where p.id = purchase_items.purchase_id
        and p.user_id = auth.uid()
    )
  );

-- One row per user/month. `security_invoker` keeps RLS of purchases active.
create or replace view monthly_spending
with (security_invoker = true) as
select
  user_id,
  date_trunc('month', purchased_at)::date as month,
  sum(total)::numeric(12, 2) as total
from purchases
group by user_id, date_trunc('month', purchased_at);
