-- Mercado App - Initial Database Schema
-- Run in Supabase SQL Editor

-- Enable required extensions
create extension if not exists postgis;
create extension if not exists pg_trgm;
create extension if not exists "uuid-ossp";

-- ============================================
-- PROFILES (Users)
-- ============================================
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  avatar_url text,
  trust_score int default 100 check (trust_score >= 0 and trust_score <= 1000),
  total_scans int default 0,
  total_confirmations int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table profiles enable row level security;

create policy "Users can read all profiles" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

-- ============================================
-- STORES (Supermarkets)
-- ============================================
create table stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  chain text, -- e.g., 'Carrefour', 'Assaí', 'Mercado Local'
  location geography(Point, 4326) not null,
  address text,
  phone text,
  opening_hours jsonb, -- { "mon": "08:00-22:00", ... }
  verified boolean default false,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_stores_location on stores using gist (location);
create index idx_stores_chain on stores (chain);
create index idx_stores_verified on stores (verified) where verified = true;

alter table stores enable row level security;
create policy "Anyone can read stores" on stores for select using (true);
create policy "Verified users can create stores" on stores for insert with check (
  exists (select 1 from profiles where id = auth.uid() and trust_score >= 50)
);
create policy "Store creator or admin can update" on stores for update using (
  created_by = auth.uid() or exists (select 1 from profiles where id = auth.uid() and trust_score >= 500)
);

-- ============================================
-- PRODUCTS (Catalog)
-- ============================================
create table products (
  id uuid primary key default gen_random_uuid(),
  ean text unique, -- EAN-13 normalized (no leading zeros)
  name text not null,
  brand text,
  category text,
  unit text default 'un', -- 'un', 'kg', 'g', 'L', 'ml', 'cx', 'pt'
  normalized_name tsvector generated always as (to_tsvector('portuguese', name)) stored,
  image_url text,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_products_ean on products (ean) where ean is not null;
create index idx_products_name_trgm on products using gin (name gin_trgm_ops);
create index idx_products_fts on products using gin (normalized_name);
create index idx_products_brand on products (brand) where brand is not null;

alter table products enable row level security;
create policy "Anyone can read products" on products for select using (true);
create policy "Authenticated users can create products" on products for insert with check (auth.uid() is not null);

-- ============================================
-- COMMUNITY PRICES (Core Community Feature)
-- ============================================
create table community_prices (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  store_id uuid not null references stores(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete set null,

  price numeric(10,2) not null check (price > 0),
  unit_price numeric(10,4) generated always as (
    case when quantity is not null and quantity > 0 then price / quantity else null end
  ) stored,
  quantity numeric(10,3), -- quantity in package
  unit text, -- unit of quantity

  captured_at timestamptz not null default now(),
  expires_at timestamptz generated always as (captured_at + interval '72 hours') stored,
  is_promo boolean default false,
  promo_ends_at timestamptz,

  -- Validation metadata
  confirmation_count int default 0,
  dispute_count int default 0,
  status text default 'active' check (status in ('active', 'expired', 'disputed', 'confirmed')),

  -- Proof
  receipt_photo_path text, -- Supabase Storage path
  notes text,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Critical indexes for ultra-fast lookups
create index idx_cp_product_store_active on community_prices (product_id, store_id)
  where status = 'active' and expires_at > now();

create index idx_cp_store_active on community_prices (store_id)
  where status = 'active' and expires_at > now();

create index idx_cp_product_active on community_prices (product_id)
  where status = 'active' and expires_at > now();

create index idx_cp_user_recent on community_prices (user_id, captured_at desc)
  where status = 'active';

create index idx_cp_geo_temporal on community_prices (captured_at desc)
  where status = 'active' and expires_at > now();

-- Partial index for promo prices
create index idx_cp_promo_active on community_prices (product_id, store_id)
  where is_promo = true and promo_ends_at > now();

alter table community_prices enable row level security;

create policy "Read active prices" on community_prices
  for select using (status = 'active' and expires_at > now());

create policy "Insert own price" on community_prices
  for insert with check (auth.uid() = user_id);

create policy "Update own price" on community_prices
  for update using (auth.uid() = user_id);

create policy "Users can confirm prices" on community_prices
  for update using (
    auth.uid() is not null and
    status = 'active' and
    user_id != auth.uid() -- Can't confirm own price
  ) with check (
    confirmation_count > 0 or
    dispute_count > 0
  );

-- ============================================
-- PRICE CONFIRMATIONS (User validations)
-- ============================================
create table price_confirmations (
  id uuid primary key default gen_random_uuid(),
  price_id uuid not null references community_prices(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  confirmed boolean not null, -- true = confirm, false = dispute
  created_at timestamptz default now(),
  unique (price_id, user_id)
);

alter table price_confirmations enable row level security;
create policy "Read confirmations" on price_confirmations for select using (true);
create policy "Insert own confirmation" on price_confirmations for insert with check (auth.uid() = user_id);

-- Trigger to update confirmation/dispute counts
create or replace function update_price_counts()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    update community_prices set
      confirmation_count = confirmation_count + case when new.confirmed then 1 else 0 end,
      dispute_count = dispute_count + case when new.confirmed then 0 else 1 end,
      updated_at = now()
    where id = new.price_id;
  elsif tg_op = 'DELETE' then
    update community_prices set
      confirmation_count = confirmation_count - case when old.confirmed then 1 else 0 end,
      dispute_count = dispute_count - case when old.confirmed then 0 else 1 end,
      updated_at = now()
    where id = old.price_id;
  elsif tg_op = 'UPDATE' and old.confirmed != new.confirmed then
    update community_prices set
      confirmation_count = confirmation_count + case when new.confirmed then 1 else -1 end,
      dispute_count = dispute_count + case when new.confirmed then -1 else 1 end,
      updated_at = now()
    where id = new.price_id;
  end if;
  return new;
end;
$$;

create trigger trg_update_price_counts
after insert or update or delete on price_confirmations
for each row execute function update_price_counts();

-- ============================================
-- RPC FUNCTIONS FOR ULTRA-FAST QUERIES
-- ============================================

-- Find nearby stores
create or replace function find_stores_nearby(
  p_lat double precision,
  p_lon double precision,
  p_radius_km double precision default 10,
  p_limit int default 20
)
returns table (
  id uuid,
  name text,
  chain text,
  distance_km numeric,
  address text,
  verified boolean
) language plpgsql as $$
begin
  return query
  select
    s.id,
    s.name,
    s.chain,
    round((st_distance(s.location, st_makepoint(p_lon, p_lat)::geography) / 1000)::numeric, 2) as distance_km,
    s.address,
    s.verified
  from stores s
  where st_dwithin(
    s.location,
    st_makepoint(p_lon, p_lat)::geography,
    p_radius_km * 1000
  )
  order by distance_km asc
  limit p_limit;
end;
$$;

-- Find better prices nearby (THE KEY FUNCTION)
create or replace function find_better_prices_nearby(
  p_ean text,
  p_user_lat double precision,
  p_user_lon double precision,
  p_radius_km double precision default 15,
  p_limit int default 5
)
returns table (
  product_id uuid,
  product_name text,
  product_brand text,
  store_id uuid,
  store_name text,
  store_chain text,
  price numeric,
  unit_price numeric,
  quantity numeric,
  unit text,
  distance_km numeric,
  captured_at timestamptz,
  confirmation_count int,
  dispute_count int,
  savings numeric,
  savings_pct numeric,
  is_promo boolean
) language plpgsql as $$
declare
  v_product_id uuid;
  v_current_price numeric;
begin
  -- Resolve product by EAN
  select id into v_product_id from products where ean = p_ean;
  if v_product_id is null then
    return;
  end if;

  -- Get current price from context (would be passed in real implementation)
  -- For now, we'll return all cheaper prices and let client filter

  return query
  select
    cp.product_id,
    pr.name as product_name,
    pr.brand as product_brand,
    cp.store_id,
    s.name as store_name,
    s.chain as store_chain,
    cp.price,
    cp.unit_price,
    cp.quantity,
    cp.unit,
    round((st_distance(s.location, st_makepoint(p_user_lon, p_user_lat)::geography) / 1000)::numeric, 2) as distance_km,
    cp.captured_at,
    cp.confirmation_count,
    cp.dispute_count,
    (v_current_price - cp.price) as savings,
    round(((v_current_price - cp.price) / v_current_price * 100)::numeric, 1) as savings_pct,
    cp.is_promo
  from community_prices cp
  join stores s on s.id = cp.store_id
  join products pr on pr.id = cp.product_id
  where cp.product_id = v_product_id
    and cp.status = 'active'
    and cp.expires_at > now()
    and cp.unit_price is not null
    and st_dwithin(
      s.location,
      st_makepoint(p_user_lon, p_user_lat)::geography,
      p_radius_km * 1000
    )
  order by cp.unit_price asc, cp.captured_at desc
  limit p_limit;
end;
$$;

-- ============================================
-- MATERIALIZED VIEW FOR BEST PRICES
-- ============================================
create materialized view mv_best_prices_nearby as
select
  cp.product_id,
  cp.store_id,
  s.location,
  cp.price,
  cp.unit_price,
  cp.captured_at,
  cp.confirmation_count,
  row_number() over (partition by cp.product_id order by cp.unit_price asc nulls last, cp.captured_at desc) as rank
from community_prices cp
join stores s on s.id = cp.store_id
where cp.status = 'active'
  and cp.expires_at > now()
  and cp.unit_price is not null;

create unique index on mv_best_prices_nearby (product_id, store_id);

-- Refresh function
create or replace function refresh_best_prices()
returns void language sql as $$
  refresh materialized view concurrently mv_best_prices_nearby;
$$;

-- Schedule refresh every 5 minutes (requires pg_cron extension)
-- select cron.schedule('refresh-best-prices', '*/5 * * * *', 'select refresh_best_prices();');

-- ============================================
-- AUTO-EXPIRE OLD PRICES
-- ============================================
create or replace function expire_old_prices()
returns void language plpgsql as $$
begin
  update community_prices
  set status = 'expired', updated_at = now()
  where status = 'active' and expires_at <= now();
end;
$$;

-- Schedule daily cleanup
-- select cron.schedule('expire-old-prices', '0 3 * * *', 'select expire_old_prices();');

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Auto-update timestamps
create or replace function update_updated_at_column()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on profiles
for each row execute function update_updated_at_column();

create trigger trg_stores_updated_at before update on stores
for each row execute function update_updated_at_column();

create trigger trg_products_updated_at before update on products
for each row execute function update_updated_at_column();

create trigger trg_community_prices_updated_at before update on community_prices
for each row execute function update_updated_at_column();