-- ============================================================================
-- SomaAí — Hardening RLS (Row Level Security) para Produção
-- ============================================================================
-- Execute este script no **SQL Editor do Supabase** (painel > SQL Editor > New Query).
-- Este script reforça as políticas RLS existentes para garantir isolamento total
-- de dados por usuário autenticado.
--
-- IMPORTANTE: Rode APÓS as migrations 001 a 006.
-- ============================================================================

-- ============================================
-- 1. COMPRAS (purchases) — Isolamento total por user_id
-- ============================================
-- Remove políticas existentes para recriar com nomes padronizados
DROP POLICY IF EXISTS "Users can read own purchases" ON public.purchases;
DROP POLICY IF EXISTS "Users can insert own purchases" ON public.purchases;
DROP POLICY IF EXISTS "Users can update own purchases" ON public.purchases;
DROP POLICY IF EXISTS "Users can delete own purchases" ON public.purchases;

CREATE POLICY "purchases_select_own"
  ON public.purchases FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "purchases_insert_own"
  ON public.purchases FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "purchases_update_own"
  ON public.purchases FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "purchases_delete_own"
  ON public.purchases FOR DELETE
  USING (auth.uid() = user_id);

-- purchase_items — via FK para purchases (garante isolamento transitivo)
DROP POLICY IF EXISTS "Users can read own purchase items" ON public.purchase_items;
DROP POLICY IF EXISTS "Users can insert own purchase items" ON public.purchase_items;
DROP POLICY IF EXISTS "Users can delete own purchase items" ON public.purchase_items;

CREATE POLICY "purchase_items_select_own"
  ON public.purchase_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

CREATE POLICY "purchase_items_insert_own"
  ON public.purchase_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

CREATE POLICY "purchase_items_delete_own"
  ON public.purchase_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

-- ============================================
-- 2. PREÇOS COMUNITÁRIOS (community_prices) — Comunidade + Ownership
-- ============================================
-- Política: Qualquer autenticado lê preços ativos; só dono edita/apaga.
-- Remove políticas antigas (incluindo a que permite anon)
DROP POLICY IF EXISTS "Read active prices" ON public.community_prices;
DROP POLICY IF EXISTS "Insert own price" ON public.community_prices;
DROP POLICY IF EXISTS "Update own price" ON public.community_prices;
DROP POLICY IF EXISTS "Users can confirm prices" ON public.community_prices;
DROP POLICY IF EXISTS "Publicar preço pelo app" ON public.community_prices;

-- SELECT: Qualquer usuário autenticado lê preços ativos (não expirados)
CREATE POLICY "community_prices_select_active"
  ON public.community_prices FOR SELECT
  TO authenticated
  USING (status = 'active' AND expires_at > now());

-- INSERT: Apenas usuários autenticados; user_id deve ser o próprio (ou null para anônimo legado)
CREATE POLICY "community_prices_insert_auth"
  ON public.community_prices FOR INSERT
  TO authenticated
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

-- UPDATE: Apenas o dono do preço pode atualizar
CREATE POLICY "community_prices_update_own"
  ON public.community_prices FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: Apenas o dono do preço pode deletar
CREATE POLICY "community_prices_delete_own"
  ON public.community_prices FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ============================================
-- 3. PRODUTOS (products) — Leitura pública, escrita autenticada
-- ============================================
DROP POLICY IF EXISTS "Anyone can read products" ON public.products;
DROP POLICY IF EXISTS "Authenticated users can create products" ON public.products;
DROP POLICY IF EXISTS "Produtos podem ser cadastrados pelo app" ON public.products;

CREATE POLICY "products_select_all"
  ON public.products FOR SELECT
  USING (true);

CREATE POLICY "products_insert_auth"
  ON public.products FOR INSERT
  TO authenticated
  WITH CHECK (created_by IS NULL OR created_by = auth.uid());

-- ============================================
-- 4. PERFIS (profiles) — Leitura pública, escrita própria
-- ============================================
DROP POLICY IF EXISTS "Users can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY "profiles_select_all"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 5. LOJAS (stores) — Leitura pública, criação verificada
-- ============================================
DROP POLICY IF EXISTS "Anyone can read stores" ON public.stores;
DROP POLICY IF EXISTS "Verified users can create stores" ON public.stores;
DROP POLICY IF EXISTS "Store creator or admin can update" ON public.stores;

CREATE POLICY "stores_select_all"
  ON public.stores FOR SELECT
  USING (true);

CREATE POLICY "stores_insert_verified"
  ON public.stores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND trust_score >= 50
    )
  );

CREATE POLICY "stores_update_creator_or_admin"
  ON public.stores FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND trust_score >= 500
    )
  )
  WITH CHECK (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND trust_score >= 500
    )
  );

-- ============================================
-- 6. CONFIRMAÇÕES DE PREÇO (price_confirmations)
-- ============================================
DROP POLICY IF EXISTS "Read confirmations" ON public.price_confirmations;
DROP POLICY IF EXISTS "Insert own confirmation" ON public.price_confirmations;

CREATE POLICY "price_confirmations_select_all"
  ON public.price_confirmations FOR SELECT
  USING (true);

CREATE POLICY "price_confirmations_insert_own"
  ON public.price_confirmations FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 7. MERCADOS (mercados) — Tabela legada/community
-- ============================================
-- Se existir, aplica RLS similar a stores
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'mercados') THEN
    -- Habilita RLS se não estiver
    EXECUTE 'ALTER TABLE public.mercados ENABLE ROW LEVEL SECURITY';
    
    -- Remove políticas antigas se existirem
    DROP POLICY IF EXISTS "Anyone can read mercados" ON public.mercados;
    DROP POLICY IF EXISTS "Authenticated can insert mercados" ON public.mercados;
    
    CREATE POLICY "mercados_select_all"
      ON public.mercados FOR SELECT
      USING (true);
      
    CREATE POLICY "mercados_insert_auth"
      ON public.mercados FOR INSERT
      TO authenticated
      WITH CHECK (true); -- Ajuste conforme necessidade
  END IF;
END $$;

-- ============================================
-- 8. VERIFICAÇÃO FINAL
-- ============================================================================
-- Lista todas as políticas ativas para conferência
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================