-- ============================================================================
-- SomaAí — Preparação de `mercados` para busca híbrida (PostGIS + TomTom)
-- ============================================================================
-- Execute no SQL Editor do Supabase (ou `supabase db push`).
--
-- O que este script faz:
--   1. Garante o índice espacial GiST na coluna geográfica (`geog`).
--   2. Adiciona `external_id` (place_id da TomTom) com UNIQUE.
--   3. Cria a função de upsert usada pela sincronização invisível do app.
--
-- Observação importante sobre o nome da coluna: a tabela `mercados` usa
-- `geog` (geography) como fonte de verdade espacial — não existe a coluna
-- `localizacao`. O índice GiST já existente (`idx_mercados_geog`) é o mesmo
-- que `CREATE INDEX ... USING GIST (localizacao)` faria em outro schema.
-- ============================================================================

begin;

-- ============================================================================
-- 1. ÍNDICE ESPACIAL GiST (busca por raio em milissegundos)
-- ============================================================================
-- Mantém o nome histórico para não duplicar índices. `IF NOT EXISTS` torna o
-- script idempotente.

create index if not exists idx_mercados_geog
  on public.mercados using gist (geog);

-- ============================================================================
-- 2. DEDUPLICAÇÃO POR external_id
-- ============================================================================
-- `external_id` guarda o `id` (place_id) único devolvido pela TomTom Places
-- Search API. UNIQUE impede registros duplicados quando o mesmo POI for
-- selecionado por vários usuários.
--
-- No Postgres, um índice UNIQUE aceita vários NULLs — mercados cadastrados
-- manualmente (sem TomTom) continuam funcionando normalmente.

alter table public.mercados
  add column if not exists external_id text;

create unique index if not exists idx_mercados_external_id
  on public.mercados (external_id);

comment on column public.mercados.external_id is
  'ID externo do POI (TomTom Places). NULL para mercados cadastrados manualmente.';

-- ============================================================================
-- 3. UPSERT SILENCIOSO POR external_id (chamado pelo app ao selecionar)
-- ============================================================================
-- SECURITY DEFINER é intencional: a tabela `mercados` é pública para leitura e
-- o upsert só grava dados públicos de POI (nome, coordenadas, endereço). Isso
-- evita que a policy de UPDATE (restrita ao criador) bloqueie a sincronização
-- quando outro usuário seleciona o mesmo mercado.
--
-- Os dados do usuário (compras, preços) continuam isolados pelas suas próprias
-- policies de RLS.

create or replace function public.upsert_mercado_by_external_id(
  p_external_id text,
  p_nome text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_cidade text default null,
  p_bairro text default null,
  p_endereco text default null
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
  criado_em timestamptz,
  external_id text
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_external_id text := nullif(btrim(coalesce(p_external_id, '')), '');
  v_nome text := btrim(coalesce(p_nome, ''));
  v_cidade text := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text := nullif(btrim(coalesce(p_bairro, '')), '');
  v_endereco text := nullif(btrim(coalesce(p_endereco, '')), '');
  v_geog geography;
  v_id uuid;
begin
  if v_external_id is null then
    raise exception 'external_id é obrigatório';
  end if;

  if length(v_nome) < 2 then
    raise exception 'Informe um nome de mercado válido (mínimo 2 caracteres)';
  end if;

  if (p_lat is null) <> (p_lng is null) then
    raise exception 'Latitude e longitude devem ser informadas juntas';
  end if;

  if p_lat is not null and (p_lat < -90 or p_lat > 90) then
    raise exception 'Latitude inválida (deve ser entre -90 e 90)';
  end if;

  if p_lng is not null and (p_lng < -180 or p_lng > 180) then
    raise exception 'Longitude inválida (deve ser entre -180 e 180)';
  end if;

  if p_lat is not null and p_lng is not null then
    v_geog := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  end if;

  insert into public.mercados as m (
    nome,
    geog,
    latitude,
    longitude,
    cidade,
    bairro,
    endereco,
    external_id,
    created_by,
    verified
  ) values (
    v_nome,
    v_geog,
    p_lat,
    p_lng,
    v_cidade,
    v_bairro,
    v_endereco,
    v_external_id,
    auth.uid(),
    false
  )
  on conflict (external_id) do update set
    nome = excluded.nome,
    geog = coalesce(excluded.geog, m.geog),
    latitude = coalesce(excluded.latitude, m.latitude),
    longitude = coalesce(excluded.longitude, m.longitude),
    cidade = coalesce(excluded.cidade, m.cidade),
    bairro = coalesce(excluded.bairro, m.bairro),
    endereco = coalesce(excluded.endereco, m.endereco),
    updated_at = now()
  returning m.id into v_id;

  return query
    select
      m.id,
      m.nome,
      m.latitude,
      m.longitude,
      case
        when v_geog is not null and m.geog is not null
          then round(st_distance(m.geog, v_geog)::numeric, 1)
        else null::numeric
      end as distancia_metros,
      m.endereco,
      m.cidade,
      m.bairro,
      coalesce(m.verified, false) as verificado,
      m.criado_em,
      m.external_id
    from public.mercados m
    where m.id = v_id;
end;
$$;

revoke all on function public.upsert_mercado_by_external_id(
  text, text, double precision, double precision, text, text, text
) from public;

grant execute on function public.upsert_mercado_by_external_id(
  text, text, double precision, double precision, text, text, text
) to anon, authenticated;

commit;

-- ============================================================================
-- VERIFICAÇÃO (opcional)
-- ============================================================================
-- select indexname, indexdef from pg_indexes
--  where schemaname = 'public' and tablename = 'mercados';
--
-- select column_name, data_type from information_schema.columns
--  where table_schema = 'public' and table_name = 'mercados'
--    and column_name = 'external_id';
