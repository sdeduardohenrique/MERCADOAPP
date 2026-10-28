import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../domain/shopping_list.dart';
import 'providers/shopping_lists_provider.dart';
import 'shopping_list_detail_screen.dart';
import 'widgets/shopping_list_card.dart';
import 'widgets/shopping_list_editor_sheet.dart';

/// Aba principal "Minhas Listas".
///
/// Mostra todas as listas do usuário/visitante, com progresso, contagem de
/// itens e estimativa de valor. A criação abre um editor Bento com ícone.
class ShoppingListsScreen extends ConsumerWidget {
  const ShoppingListsScreen({super.key});

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showShoppingListEditorSheet(context);
    if (!context.mounted || created == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShoppingListDetailScreen(listId: created.id),
      ),
    );
  }

  Future<void> _createExample(
    BuildContext context,
    WidgetRef ref,
    String name,
    String icon,
  ) async {
    final created = await ref
        .read(shoppingListsProvider.notifier)
        .createList(name, icon: icon);
    if (!context.mounted || created == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShoppingListDetailScreen(listId: created.id),
      ),
    );
  }

  void _openList(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShoppingListDetailScreen(listId: id),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(shoppingListsProvider);
    await ref.read(shoppingListsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLists = ref.watch(shoppingListsProvider);
    final lists = asyncLists.valueOrNull ?? const <ShoppingList>[];
    final summary = ref.watch(shoppingListsSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        backgroundColor: AppTheme.emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Criar Nova Lista',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.emerald,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
            children: [
              const Text(
                'PLANEJAMENTO E ECONOMIA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppTheme.emeraldDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Minhas Listas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Organize por ocasião e siga os setores do mercado.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 18),
              if (asyncLists.isLoading && !asyncLists.hasValue)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.emerald),
                  ),
                )
              else if (asyncLists.hasError && !asyncLists.hasValue)
                _ErrorCard(
                  onRetry: () => ref.invalidate(shoppingListsProvider),
                )
              else if (lists.isEmpty)
                _EmptyState(
                  onCreate: () => _openCreate(context, ref),
                  onExample: (name, icon) =>
                      _createExample(context, ref, name, icon),
                )
              else ...[
                _SummaryCard(summary: summary),
                const SizedBox(height: 16),
                ...lists.map(
                  (list) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: ShoppingListCard(
                      list: list,
                      onTap: () => _openList(context, list.id),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ShoppingListsSummary summary;

  @override
  Widget build(BuildContext context) {
    final estimate = summary.hasEstimates
        ? Formatters.currency(summary.estimatedTotal)
        : 'Sem estimativa';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.emeraldDark,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text('🧺', style: TextStyle(fontSize: 23)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.listCount} '
                  '${summary.listCount == 1 ? 'lista' : 'listas'} • '
                  '${summary.pendingItems} '
                  '${summary.pendingItems == 1 ? 'item pendente' : 'itens pendentes'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.hasEstimates
                      ? 'Estimativa total das listas'
                      : 'Adicione preços para estimar o orçamento',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            estimate,
            style: TextStyle(
              fontSize: summary.hasEstimates ? 15 : 11,
              fontWeight: FontWeight.w800,
              color: summary.hasEstimates ? AppTheme.lime : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onCreate,
    required this.onExample,
  });

  final VoidCallback onCreate;
  final void Function(String name, String icon) onExample;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.limeTint,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Text('🧺', style: TextStyle(fontSize: 38)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sua primeira lista começa aqui',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Crie uma lista para a feira, o churrasco ou o atacado do mês. '
            'Os itens ficam agrupados por setor para você economizar tempo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar Nova Lista'),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Comece com uma ideia',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ExampleChip(
                emoji: '🥬',
                label: 'Feira da Semana',
                icon: '🥬',
                onExample: onExample,
              ),
              _ExampleChip(
                emoji: '🥩',
                label: 'Churrasco de Domingo',
                icon: '🥩',
                onExample: onExample,
              ),
              _ExampleChip(
                emoji: '📦',
                label: 'Atacado do Mês',
                icon: '📦',
                onExample: onExample,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({
    required this.emoji,
    required this.label,
    required this.icon,
    required this.onExample,
  });

  final String emoji;
  final String label;
  final String icon;
  final void Function(String name, String icon) onExample;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => onExample(label, icon),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.line),
          ),
          child: Text(
            '$emoji $label',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.amberSoft),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.amber, size: 30),
          const SizedBox(height: 8),
          const Text(
            'Não foi possível carregar suas listas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
