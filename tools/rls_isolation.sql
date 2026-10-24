-- ============================================================================
-- SomaAí — Row Level Security (RLS) para Isolamento Total de Dados
-- ============================================================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Objetivo: Garantir que cada usuário veja APENAS seus próprios dados
-- ============================================================================

-- ============================================================================
-- 1. HABILITAR RLS NAS TABELAS PRINCIPAIS
-- ============================================================================

-- Tabela de compras (purchases)
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;

-- Itens de compra (purchase_items)
ALTER TABLE public.purchase_items ENABLE ROW LEVEL SECURITY;

-- Perfis de usuários (profiles)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Preços da comunidade (community_prices)
ALTER TABLE public.community_prices ENABLE ROW LEVEL SECURITY;

-- Mercados/lojas (mercados)
ALTER TABLE public.mercados ENABLE ROW LEVEL SECURITY;

-- Confirmações de preço (price_confirmations)
ALTER TABLE public.price_confirmations ENABLE ROW LEVEL SECURITY;

-- Produtos (products) - leitura pública, escrita autenticada
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Lojas (stores)
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. POLÍTICAS PARA TABELA PURCHASES (COMPRAS)
-- ============================================================================

-- SELECT: Usuário vê apenas suas compras
CREATE POLICY "purchases_select_own" ON public.purchases
  FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT: Usuário insere apenas como próprio usuário
CREATE POLICY "purchases_insert_own" ON public.purchases
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: Usuário atualiza apenas suas compras
CREATE POLICY "purchases_update_own" ON public.purchases
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: Usuário deleta apenas suas compras
CREATE POLICY "purchases_delete_own" ON public.purchases
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 3. POLÍTICAS PARA TABELA PURCHASE_ITEMS (ITENS DE COMPRA)
-- ============================================================================

-- SELECT: Acesso via compra do usuário
CREATE POLICY "purchase_items_select_own" ON public.purchase_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

-- INSERT: Inserir itens apenas em compras próprias
CREATE POLICY "purchase_items_insert_own" ON public.purchase_items
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

-- UPDATE: Atualizar itens apenas de compras próprias
CREATE POLICY "purchase_items_update_own" ON public.purchase_items
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

-- DELETE: Deletar itens apenas de compras próprias
CREATE POLICY "purchase_items_delete_own" ON public.purchase_items
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.purchases p
      WHERE p.id = purchase_items.purchase_id
        AND p.user_id = auth.uid()
    )
  );

-- ============================================================================
-- 4. POLÍTICAS PARA TABELA PROFILES (PERFIS)
-- ============================================================================

-- SELECT: Todos podem ler perfis (para exibir nomes na comunidade)
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT
  USING (true);

-- INSERT: Usuário cria próprio perfil
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- UPDATE: Usuário atualiza próprio perfil
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- DELETE: Usuário pode excluir próprio perfil
CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE
  USING (auth.uid() = id);

-- ============================================================================
-- 5. POLÍTICAS PARA COMMUNITY_PRICES (PREÇOS COMUNITÁRIOS)
-- ============================================================================

-- SELECT: Qualquer autenticado lê preços ativos
CREATE POLICY "community_prices_select_active" ON public.community_prices
  FOR SELECT
  TO authenticated
  USING (status = 'active' AND expires_at > now());

-- INSERT: Apenas usuários autenticados, user_id deve ser o próprio
CREATE POLICY "community_prices_insert_auth" ON public.community_prices
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

-- UPDATE: Apenas o dono do preço
CREATE POLICY "community_prices_update_own" ON public.community_prices
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: Apenas o dono do preço
CREATE POLICY "community_prices_delete_own" ON public.community_prices
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ============================================================================
-- 6. POLÍTICAS PARA MERCADOS (MERCADOS/STORES)
-- ============================================================================

-- SELECT: Todos podem ler mercados
CREATE POLICY "mercados_select_all" ON public.mercados
  FOR SELECT
  USING (true);

-- INSERT: Usuários autenticados podem criar (com validação)
CREATE POLICY "mercados_insert_auth" ON public.mercados
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND trust_score >= 50
    )
  );

-- UPDATE: Criador ou admin
CREATE POLICY "mercados_update_creator_or_admin" ON public.mercados
  FOR UPDATE
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

-- ============================================================================
-- 7. POLÍTICAS PARA PRODUCTS (PRODUTOS)
-- ============================================================================

-- SELECT: Todos podem ler produtos
CREATE POLICY "products_select_all" ON public.products
  FOR SELECT
  USING (true);

-- INSERT: Usuários autenticados podem criar
CREATE POLICY "products_insert_auth" ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by IS NULL OR created_by = auth.uid());

-- ============================================================================
-- 8. POLÍTICAS PARA STORES (LOJAS)
-- ============================================================================

-- SELECT: Todos podem ler lojas
CREATE POLICY "stores_select_all" ON public.stores
  FOR SELECT
  USING (true);

-- INSERT: Usuários verificados podem criar
CREATE POLICY "stores_insert_verified" ON public.stores
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND trust_score >= 50
    )
  );

-- ============================================================================
-- 9. POLÍTICAS PARA PRICE_CONFIRMATIONS
-- ============================================================================

-- SELECT: Todos podem ler confirmações
CREATE POLICY "price_confirmations_select_all" ON public.price_confirmations
  FOR SELECT
  USING (true);

-- INSERT: Apenas próprio usuário
CREATE POLICY "price_confirmations_insert_own" ON public.price_confirmations
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 10. FUNÇÕES AUXILIARES PARA RLS
-- ============================================================================

-- Função para verificar se o usuário é o dono do recurso
CREATE OR REPLACE FUNCTION public.is_owner(resource_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT auth.uid() = resource_user_id;
$$;

-- ============================================================================
-- 11. VERIFICAÇÃO FINAL
-- ============================================================================

-- Verificar se RLS está ativo nas tabelas críticas
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('purchases', 'purchase_items', 'profiles', 'community_prices', 'mercados', 'products', 'stores', 'price_confirmations')
ORDER BY tablename;

-- Listar todas as políticas criadas
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('purchases', 'purchase_items', 'profiles', 'community_prices', 'mercados', 'products', 'stores', 'price_confirmations')
ORDER BY tablename, policyname;