-- ============================================
-- 006 — Ofertas da comunidade: leitura, foto e endereço
-- ============================================
--
-- A tela Comunidade deixa de usar dados mockados. Este migration:
-- * enriquece `community_prices` com foto, preço anterior e autor exibível;
-- * permite publicar ofertas anônimas (o app ainda não exige login);
-- * cria a RPC que devolve produto + mercado + endereço + distância;
-- * cria a RPC atômica que resolve/cria o produto e publica o preço;
-- * cria o bucket público `ofertas_storage` com RLS de upload.

begin;

-- ============================================
-- 1. Colunas de apresentação da oferta
-- ============================================
alter table public.community_prices
  add column if not exists imagem_url text,
  add column if not exists old_price numeric(10, 2),
  add column if not exists contributor_name text;

-- O cadastro anônimo é permitido enquanto o app não tiver login. A política
-- abaixo continua impedindo que um anônimo publique em nome de outra pessoa.
alter table public.community_prices
  alter column user_id drop not null;

-- ============================================
-- 2. RLS para publicação pelo app
-- ============================================
drop policy if exists "Insert own price" on public.community_prices;
drop policy if exists "Publicar preço pelo app" on public.community_prices;

create policy "Publicar preço pelo app"
  on public.community_prices
  for insert
  to anon, authenticated
  with check (
    user_id is null
    or user_id = auth.uid()
  );

drop policy if exists "Authenticated users can create products"
  on public.products;
drop policy if exists "Produtos podem ser cadastrados pelo app"
  on public.products;

create policy "Produtos podem ser cadastrados pelo app"
  on public.products
  for insert
  to anon, authenticated
  with check (
    created_by is null
    or created_by = auth.uid()
  );

grant select, insert on table public.products to anon, authenticated;
grant select, insert on table public.community_prices to anon, authenticated;

-- ============================================
-- 3. Leitura das ofertas com endereço e distância
-- ============================================
create or replace function public.listar_ofertas_comunidade(
  p_lat double precision default null,
  p_lng double precision default null,
  p_raio_km double precision default 10,
  p_cidade text default null,
  p_query text default null,
  p_limit int default 30
)
returns table (
  id uuid,
  product_name text,
  brand text,
  store_id uuid,
  store_name text,
  store_chain text,
  price numeric,
  old_price numeric,
  unit text,
  image_url text,
  distance_km numeric,
  captured_at timestamptz,
  confirmation_count int,
  endereco text,
  bairro text,
  cidade text,
  latitude double precision,
  longitude double precision,
  contributor_name text,
  is_promo boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    cp.id,
    pr.name as product_name,
    pr.brand,
    cp.store_id,
    m.nome as store_name,
    m.chain as store_chain,
    cp.price,
    cp.old_price,
    coalesce(nullif(cp.unit, ''), nullif(pr.unit, ''), 'un') as unit,
    cp.imagem_url,
    case
      when p_lat is not null and p_lng is not null and m.geog is not null then
        round(
          (st_distance(
            m.geog,
            st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
          ) / 1000)::numeric,
          2
        )
      else null
    end as distance_km,
    cp.captured_at,
    coalesce(cp.confirmation_count, 0) as confirmation_count,
    m.endereco,
    m.bairro,
    m.cidade,
    m.latitude,
    m.longitude,
    cp.contributor_name,
    coalesce(cp.is_promo, false) as is_promo
  from public.community_prices cp
  join public.products pr on pr.id = cp.product_id
  join public.mercados m on m.id = cp.store_id
  where cp.status = 'active'
    and cp.expires_at > now()
    and (
      btrim(coalesce(p_query, '')) = ''
      or pr.name ilike '%' || btrim(p_query) || '%'
      or coalesce(pr.brand, '') ilike '%' || btrim(p_query) || '%'
    )
    and case
      when btrim(coalesce(p_cidade, '')) <> '' then
        coalesce(m.cidade, '') ilike '%' || btrim(p_cidade) || '%'
        or coalesce(m.bairro, '') ilike '%' || btrim(p_cidade) || '%'
      when p_lat is not null and p_lng is not null then
        m.geog is not null
        and st_dwithin(
          m.geog,
          st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
          greatest(coalesce(p_raio_km, 10), 0.1) * 1000
        )
      else true
    end
  order by cp.captured_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 50);
$$;

-- ============================================
-- 4. Publicação atômica (resolve ou cria o produto)
-- ============================================
create or replace function public.publicar_oferta_comunidade(
  p_produto_nome text,
  p_preco numeric,
  p_mercado_id uuid,
  p_preco_antigo numeric default null,
  p_unidade text default 'un',
  p_imagem_url text default null,
  p_contribuidor text default null,
  p_ean text default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_nome text := btrim(coalesce(p_produto_nome, ''));
  v_unidade text := coalesce(nullif(btrim(p_unidade), ''), 'un');
  v_ean text := nullif(btrim(coalesce(p_ean, '')), '');
  v_user_id uuid := auth.uid();
  v_product_id uuid;
  v_price_id uuid;
begin
  if length(v_nome) < 2 then
    raise exception 'Informe um nome de produto válido';
  end if;

  if p_preco is null or p_preco <= 0 then
    raise exception 'Informe um preço maior que zero';
  end if;

  if p_mercado_id is null or not exists (
    select 1 from public.mercados where id = p_mercado_id
  ) then
    raise exception 'Mercado inválido';
  end if;

  if p_preco_antigo is not null and p_preco_antigo <= p_preco then
    raise exception 'O preço anterior deve ser maior que o preço atual';
  end if;

  if v_ean is not null then
    select id into v_product_id
    from public.products
    where ean = v_ean
    limit 1;
  end if;

  if v_product_id is null then
    select id into v_product_id
    from public.products
    where lower(name) = lower(v_nome)
    order by created_at asc nulls last
    limit 1;
  end if;

  if v_product_id is null then
    insert into public.products (
      ean,
      name,
      unit,
      created_by
    ) values (
      v_ean,
      v_nome,
      v_unidade,
      v_user_id
    )
    returning id into v_product_id;
  end if;

  insert into public.community_prices (
    product_id,
    store_id,
    user_id,
    price,
    quantity,
    unit,
    is_promo,
    imagem_url,
    old_price,
    contributor_name
  ) values (
    v_product_id,
    p_mercado_id,
    v_user_id,
    p_preco,
    1,
    v_unidade,
    false,
    nullif(btrim(coalesce(p_imagem_url, '')), ''),
    p_preco_antigo,
    nullif(btrim(coalesce(p_contribuidor, '')), '')
  )
  returning id into v_price_id;

  return v_price_id;
end;
$$;

revoke all on function public.listar_ofertas_comunidade(
  double precision, double precision, double precision, text, text, int
) from public;
revoke all on function public.publicar_oferta_comunidade(
  text, numeric, uuid, numeric, text, text, text, text
) from public;

grant execute on function public.listar_ofertas_comunidade(
  double precision, double precision, double precision, text, text, int
) to anon, authenticated;
grant execute on function public.publicar_oferta_comunidade(
  text, numeric, uuid, numeric, text, text, text, text
) to anon, authenticated;

-- ============================================
-- 5. Bucket das fotos das ofertas
-- ============================================
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'ofertas_storage',
  'ofertas_storage',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Fotos de ofertas são públicas" on storage.objects;
drop policy if exists "Upload de foto de oferta" on storage.objects;

create policy "Fotos de ofertas são públicas"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'ofertas_storage');

create policy "Upload de foto de oferta"
  on storage.objects
  for insert
  to anon, authenticated
  with check (bucket_id = 'ofertas_storage');

commit;
