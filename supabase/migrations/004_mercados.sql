-- SomaAí — Módulo de Comunidade: identificação de mercado
--
-- `stores` já era a tabela de supermercados usada pela comunidade. Para manter
-- os preços existentes e evitar duplicação, ela passa a ser a tabela canônica
-- `mercados`, agora com nomes em português e colunas de latitude/longitude
-- prontas para a UI. A coluna geográfica continua sendo a fonte de verdade
-- para as consultas PostGIS.

begin;

-- ============================================
-- 1. STORES -> MERCADOS
-- ============================================
alter table public.stores rename to mercados;

alter table public.mercados rename column name to nome;
alter table public.mercados rename column location to geog;
alter table public.mercados rename column address to endereco;
alter table public.mercados rename column created_at to criado_em;

alter index if exists public.idx_stores_location rename to idx_mercados_geog;
alter index if exists public.idx_stores_chain rename to idx_mercados_chain;
alter index if exists public.idx_stores_verified rename to idx_mercados_verified;

alter trigger trg_stores_updated_at on public.mercados
  rename to trg_mercados_updated_at;

-- Um mercado pode ser cadastrado sem GPS (nome + cidade/bairro). Nesse caso a
-- coluna geográfica fica nula e a busca por nome continua funcionando.
alter table public.mercados alter column geog drop not null;

alter table public.mercados
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists cidade text,
  add column if not exists bairro text;

update public.mercados
set latitude = st_y(geog::geometry),
    longitude = st_x(geog::geometry)
where geog is not null
  and (latitude is null or longitude is null);

create index if not exists idx_mercados_nome_trgm
  on public.mercados using gin (nome gin_trgm_ops);

-- Consultas antigas de "chain"/"verified" continuam válidas após o rename.
-- Novos mercados criados pelo app entram como não verificados.

-- ============================================
-- 2. POLÍTICAS RLS
-- ============================================
drop policy if exists "Anyone can read stores" on public.mercados;
drop policy if exists "Verified users can create stores" on public.mercados;
drop policy if exists "Store creator or admin can update" on public.mercados;

create policy "Mercados são públicos"
  on public.mercados
  for select
  to anon, authenticated
  using (true);

-- O app ainda não exige login. O cadastro anônimo é permitido para o fluxo
-- "meu mercado não está na lista", mas o registro nasce como não verificado e
-- sem possibilidade de se autopromover.
create policy "Cadastro de mercado pelo app"
  on public.mercados
  for insert
  to anon, authenticated
  with check (
    coalesce(verified, false) = false
    and (created_by is null or created_by = auth.uid())
  );

create policy "Criador ou moderador atualiza mercado"
  on public.mercados
  for update
  to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1 from public.profiles
      where profiles.id = auth.uid() and profiles.trust_score >= 500
    )
  )
  with check (
    created_by = auth.uid()
    or exists (
      select 1 from public.profiles
      where profiles.id = auth.uid() and profiles.trust_score >= 500
    )
  );

grant select on table public.mercados to anon, authenticated;
grant insert on table public.mercados to anon, authenticated;

-- ============================================
-- 3. COMPRAS ATRELADAS AO MERCADO
-- ============================================
alter table public.purchases
  add column if not exists mercado_id uuid
  references public.mercados(id) on delete set null;

create index if not exists idx_purchases_mercado
  on public.purchases (mercado_id);

-- ============================================
-- 4. BUSCA E CADASTRO DE MERCADOS
-- ============================================

-- Raio em metros, retorno pronto para a UI. ST_DWithin usa o índice GiST.
create or replace function public.buscar_mercados_proximos(
  p_lat double precision,
  p_lng double precision,
  p_raio_metros double precision default 5000,
  p_limit int default 20
)
returns table (
  id uuid,
  nome text,
  latitude double precision,
  longitude double precision,
  distancia_metros numeric,
  endereco text,
  cidade text,
  bairro text,
  verificado boolean,
  criado_em timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    m.id,
    m.nome,
    m.latitude,
    m.longitude,
    round(
      st_distance(
        m.geog,
        st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
      )::numeric,
      1
    ) as distancia_metros,
    m.endereco,
    m.cidade,
    m.bairro,
    coalesce(m.verified, false) as verificado,
    m.criado_em
  from public.mercados m
  where m.geog is not null
    and st_dwithin(
      m.geog,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      greatest(coalesce(p_raio_metros, 5000), 1)
    )
  order by distancia_metros asc, m.nome asc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

-- Fallback quando o GPS foi negado ou está desligado.
create or replace function public.buscar_mercados_por_nome(
  p_query text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_limit int default 20
)
returns table (
  id uuid,
  nome text,
  latitude double precision,
  longitude double precision,
  distancia_metros numeric,
  endereco text,
  cidade text,
  bairro text,
  verificado boolean,
  criado_em timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    m.id,
    m.nome,
    m.latitude,
    m.longitude,
    case
      when p_lat is not null and p_lng is not null and m.geog is not null then
        round(
          st_distance(
            m.geog,
            st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
          )::numeric,
          1
        )
      else null
    end as distancia_metros,
    m.endereco,
    m.cidade,
    m.bairro,
    coalesce(m.verified, false) as verificado,
    m.criado_em
  from public.mercados m
  where btrim(coalesce(p_query, '')) <> ''
    and m.nome ilike '%' || btrim(p_query) || '%'
  order by
    case
      when p_lat is not null and p_lng is not null and m.geog is not null then
        st_distance(
          m.geog,
          st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
        )
      else null
    end asc nulls last,
    m.nome asc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

-- Cria (ou reaproveita) um mercado. Funciona com ou sem coordenadas.
create or replace function public.criar_mercado(
  p_nome text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_cidade text default null,
  p_bairro text default null
)
returns table (
  id uuid,
  nome text,
  latitude double precision,
  longitude double precision,
  distancia_metros numeric,
  endereco text,
  cidade text,
  bairro text,
  verificado boolean,
  criado_em timestamptz
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_nome text := btrim(coalesce(p_nome, ''));
  v_cidade text := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text := nullif(btrim(coalesce(p_bairro, '')), '');
  v_geog geography;
  v_id uuid;
  v_existing_id uuid;
begin
  if length(v_nome) < 2 then
    raise exception 'Informe um nome de mercado válido';
  end if;

  if (p_lat is null) <> (p_lng is null) then
    raise exception 'Latitude e longitude devem ser informadas juntas';
  end if;

  if p_lat is not null and (p_lat < -90 or p_lat > 90) then
    raise exception 'Latitude inválida';
  end if;

  if p_lng is not null and (p_lng < -180 or p_lng > 180) then
    raise exception 'Longitude inválida';
  end if;

  if p_lat is not null and p_lng is not null then
    v_geog := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  end if;

  -- Deduplicação simples: mesmo nome e, quando há GPS, a até 100 m.
  select m.id into v_existing_id
  from public.mercados m
  where lower(m.nome) = lower(v_nome)
    and (
      v_geog is null
      or m.geog is null
      or st_dwithin(m.geog, v_geog, 100)
    )
    and (
      v_geog is not null
      or m.cidade is not distinct from v_cidade
    )
  order by
    case
      when v_geog is not null and m.geog is not null then
        st_distance(m.geog, v_geog)
      else 0
    end asc
  limit 1;

  if v_existing_id is not null then
    return query
      select
        m.id,
        m.nome,
        m.latitude,
        m.longitude,
        case
          when v_geog is not null and m.geog is not null then
            round(st_distance(m.geog, v_geog)::numeric, 1)
          else null
        end,
        m.endereco,
        m.cidade,
        m.bairro,
        coalesce(m.verified, false),
        m.criado_em
      from public.mercados m
      where m.id = v_existing_id;
    return;
  end if;

  insert into public.mercados (
    nome,
    geog,
    latitude,
    longitude,
    cidade,
    bairro,
    created_by,
    verified
  ) values (
    v_nome,
    v_geog,
    p_lat,
    p_lng,
    v_cidade,
    v_bairro,
    auth.uid(),
    false
  )
  returning mercados.id into v_id;

  return query
    select
      m.id,
      m.nome,
      m.latitude,
      m.longitude,
      null::numeric,
      m.endereco,
      m.cidade,
      m.bairro,
      coalesce(m.verified, false),
      m.criado_em
    from public.mercados m
    where m.id = v_id;
end;
$$;

-- ============================================
-- 5. COMPATIBILIDADE COM O CÓDIGO DE COMUNIDADE
-- ============================================
drop function if exists public.find_stores_nearby(
  double precision, double precision, double precision, int
);

create or replace function public.find_stores_nearby(
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
  verified boolean,
  latitude double precision,
  longitude double precision,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    m.id,
    m.nome as name,
    s.chain,
    round((m.distancia_metros / 1000)::numeric, 2) as distance_km,
    m.endereco as address,
    m.verificado,
    m.latitude,
    m.longitude,
    m.criado_em as created_at
  from public.buscar_mercados_proximos(
    p_lat,
    p_lon,
    p_radius_km * 1000,
    p_limit
  ) m
  join public.mercados s on s.id = m.id;
$$;

create or replace function public.find_better_prices_nearby(
  p_ean text,
  p_user_lat double precision,
  p_user_lon double precision,
  p_current_price numeric,
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
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_product_id uuid;
begin
  select id into v_product_id from public.products where ean = p_ean;
  if v_product_id is null then
    return;
  end if;

  return query
  select
    cp.product_id,
    pr.name as product_name,
    pr.brand as product_brand,
    cp.store_id,
    s.nome as store_name,
    s.chain as store_chain,
    cp.price,
    cp.unit_price,
    cp.quantity,
    cp.unit,
    round(
      (st_distance(
        s.geog,
        st_setsrid(st_makepoint(p_user_lon, p_user_lat), 4326)::geography
      ) / 1000)::numeric,
      2
    ) as distance_km,
    cp.captured_at,
    cp.confirmation_count,
    cp.dispute_count,
    greatest(coalesce(p_current_price, 0) - cp.price, 0) as savings,
    case
      when coalesce(p_current_price, 0) > 0 then
        round(
          ((coalesce(p_current_price, 0) - cp.price)
            / p_current_price * 100)::numeric,
          1
        )
      else 0
    end as savings_pct,
    cp.is_promo
  from public.community_prices cp
  join public.mercados s on s.id = cp.store_id
  join public.products pr on pr.id = cp.product_id
  where cp.product_id = v_product_id
    and cp.status = 'active'
    and cp.expires_at > now()
    and cp.unit_price is not null
    and s.geog is not null
    and cp.price < coalesce(p_current_price, 0)
    and st_dwithin(
      s.geog,
      st_setsrid(st_makepoint(p_user_lon, p_user_lat), 4326)::geography,
      p_radius_km * 1000
    )
  order by cp.unit_price asc, cp.captured_at desc
  limit p_limit;
end;
$$;

-- ============================================
-- 6. COMPRA COM MERCADO
-- ============================================
drop function if exists public.save_purchase_with_items(
  uuid, text, numeric, timestamptz, jsonb
);

create or replace function public.save_purchase_with_items(
  p_id uuid,
  p_store_name text,
  p_savings numeric default 0,
  p_purchased_at timestamptz default now(),
  p_items jsonb default '[]'::jsonb,
  p_mercado_id uuid default null
)
returns boolean
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_owner_id uuid;
  v_total numeric(12, 2);
  v_item_count int;
  v_store_name text := btrim(coalesce(p_store_name, ''));
  v_savings numeric(12, 2) := greatest(coalesce(p_savings, 0), 0);
  v_purchased_at timestamptz := coalesce(p_purchased_at, now());
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_store_name = '' then
    raise exception 'Store name is required';
  end if;

  if p_mercado_id is not null and not exists (
    select 1 from public.mercados where id = p_mercado_id
  ) then
    raise exception 'Mercado inválido';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'A purchase must have at least one item';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_items) as item
    where btrim(coalesce(item ->> 'name', '')) = ''
       or coalesce((item ->> 'unit_price')::numeric, -1) < 0
       or coalesce((item ->> 'quantity')::int, 0) <= 0
  ) then
    raise exception 'Invalid purchase item';
  end if;

  select
    coalesce(sum((item ->> 'unit_price')::numeric * (item ->> 'quantity')::int), 0),
    coalesce(sum((item ->> 'quantity')::int), 0)
  into v_total, v_item_count
  from jsonb_array_elements(p_items) as item;

  if v_item_count <= 0 then
    raise exception 'A purchase must have at least one item';
  end if;

  select user_id into v_owner_id
  from public.purchases
  where id = p_id;

  if found then
    if v_owner_id <> v_user_id then
      raise exception 'Purchase belongs to another user';
    end if;

    update public.purchases
    set store_name = v_store_name,
        total = v_total,
        savings = v_savings,
        item_count = v_item_count,
        purchased_at = v_purchased_at,
        mercado_id = coalesce(p_mercado_id, mercado_id)
    where id = p_id;
  else
    insert into public.purchases (
      id,
      user_id,
      store_name,
      total,
      savings,
      item_count,
      purchased_at,
      mercado_id
    ) values (
      p_id,
      v_user_id,
      v_store_name,
      v_total,
      v_savings,
      v_item_count,
      v_purchased_at,
      p_mercado_id
    );
  end if;

  delete from public.purchase_items where purchase_id = p_id;

  insert into public.purchase_items (
    purchase_id,
    name,
    unit,
    unit_price,
    quantity
  )
  select
    p_id,
    btrim(item ->> 'name'),
    coalesce(nullif(btrim(item ->> 'unit'), ''), 'un'),
    (item ->> 'unit_price')::numeric,
    (item ->> 'quantity')::int
  from jsonb_array_elements(p_items) as item;

  return true;
end;
$$;

revoke all on function public.save_purchase_with_items(
  uuid, text, numeric, timestamptz, jsonb, uuid
) from public;

grant execute on function public.save_purchase_with_items(
  uuid, text, numeric, timestamptz, jsonb, uuid
) to authenticated;

revoke all on function public.buscar_mercados_proximos(
  double precision, double precision, double precision, int
) from public;

revoke all on function public.buscar_mercados_por_nome(
  text, double precision, double precision, int
) from public;

revoke all on function public.criar_mercado(
  text, double precision, double precision, text, text
) from public;

grant execute on function public.buscar_mercados_proximos(
  double precision, double precision, double precision, int
) to anon, authenticated;

grant execute on function public.buscar_mercados_por_nome(
  text, double precision, double precision, int
) to anon, authenticated;

grant execute on function public.criar_mercado(
  text, double precision, double precision, text, text
) to anon, authenticated;

commit;
