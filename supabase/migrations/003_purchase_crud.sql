-- SomaAí - atomic create/update of purchases and their items
--
-- The app writes locally first. When an authenticated session exists, this
-- function mirrors the whole purchase in one transaction, so an interrupted
-- update can never leave a purchase without its items.
--
-- `security invoker` keeps the RLS policies from migration 002 active.

create or replace function public.save_purchase_with_items(
  p_id uuid,
  p_store_name text,
  p_savings numeric default 0,
  p_purchased_at timestamptz default now(),
  p_items jsonb default '[]'::jsonb
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
  from purchases
  where id = p_id;

  if found then
    if v_owner_id <> v_user_id then
      raise exception 'Purchase belongs to another user';
    end if;

    update purchases
    set store_name = v_store_name,
        total = v_total,
        savings = v_savings,
        item_count = v_item_count,
        purchased_at = v_purchased_at
    where id = p_id;
  else
    insert into purchases (
      id,
      user_id,
      store_name,
      total,
      savings,
      item_count,
      purchased_at
    ) values (
      p_id,
      v_user_id,
      v_store_name,
      v_total,
      v_savings,
      v_item_count,
      v_purchased_at
    );
  end if;

  delete from purchase_items where purchase_id = p_id;

  insert into purchase_items (
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
  uuid, text, numeric, timestamptz, jsonb
) from public;

grant execute on function public.save_purchase_with_items(
  uuid, text, numeric, timestamptz, jsonb
) to authenticated;
