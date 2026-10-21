-- ============================================
-- 005 — Deduplicação segura de mercados
-- ============================================
-- Corrige a regra de reaproveitamento de `criar_mercado`:
--
-- * com GPS, só considera mercados que também têm geografia e estão a até
--   100 m (evita reutilizar um mercado homônimo de outra cidade que ainda
--   não tem coordenadas);
-- * sem GPS, só considera mercados sem geografia na mesma cidade.
--
-- A função é recriada com a mesma assinatura/retorno usada pelo app.

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

  -- Deduplicação conservadora: com GPS exige distância; sem GPS exige que o
  -- mercado existente também não tenha coordenadas e que a cidade coincida.
  select m.id into v_existing_id
  from public.mercados m
  where lower(m.nome) = lower(v_nome)
    and (
      (
        v_geog is not null
        and m.geog is not null
        and st_dwithin(m.geog, v_geog, 100)
      )
      or (
        v_geog is null
        and m.geog is null
        and m.cidade is not distinct from v_cidade
      )
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

revoke all on function public.criar_mercado(
  text, double precision, double precision, text, text
) from public;
grant execute on function public.criar_mercado(
  text, double precision, double precision, text, text
) to anon, authenticated;
