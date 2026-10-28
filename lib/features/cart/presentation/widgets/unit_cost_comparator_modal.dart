import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/cart_item.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/purchase_tools.dart';
import '../providers/cart_provider.dart';

/// Abre o comparador de custo por kg/L e devolve o item adicionado.
Future<CartItem?> showUnitCostComparatorModal(BuildContext context) {
  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const UnitCostComparatorModal(),
  );
}

class UnitCostComparatorModal extends ConsumerStatefulWidget {
  const UnitCostComparatorModal({super.key});

  @override
  ConsumerState<UnitCostComparatorModal> createState() =>
      _UnitCostComparatorModalState();
}

class _UnitCostComparatorModalState
    extends ConsumerState<UnitCostComparatorModal> {
  final _priceAController = TextEditingController();
  final _amountAController = TextEditingController();
  final _priceBController = TextEditingController();
  final _amountBController = TextEditingController();

  MeasureUnit _unitA = MeasureUnit.gram;
  MeasureUnit _unitB = MeasureUnit.kilogram;

  @override
  void dispose() {
    _priceAController.dispose();
    _amountAController.dispose();
    _priceBController.dispose();
    _amountBController.dispose();
    super.dispose();
  }

  UnitCostOption get _optionA => UnitCostOption(
        price: parseDecimalInput(_priceAController.text) ?? 0,
        amount: parseDecimalInput(_amountAController.text) ?? 0,
        unit: _unitA,
      );

  UnitCostOption get _optionB => UnitCostOption(
        price: parseDecimalInput(_priceBController.text) ?? 0,
        amount: parseDecimalInput(_amountBController.text) ?? 0,
        unit: _unitB,
      );

  UnitCostComparison get _comparison => compareUnitCosts(_optionA, _optionB);

  void _addChosen() {
    final comparison = _comparison;
    final chosen =
        comparison.winner ?? (comparison.isTie ? comparison.optionA : null);
    if (chosen == null) return;

    final baseAmount = chosen.baseAmount;
    final pricePerBase = chosen.pricePerBase;
    if (baseAmount == null || pricePerBase == null) return;

    final winnerLabel = identical(comparison.winner, comparison.optionA)
        ? 'A'
        : identical(comparison.winner, comparison.optionB)
            ? 'B'
            : 'A';

    final CartItem item;
    if (chosen.unit.isMass) {
      item = CartItem(
        id: const Uuid().v4(),
        name: 'Produto Comparado',
        unitPrice: pricePerBase,
        quantity: 1,
        unit: 'kg',
        kind: CartItemKind.weight,
        weightKg: baseAmount,
        totalPrice: 0,
        addedAt: DateTime.now(),
        source: ScanSource.manual,
        rawOcrData: {
          'tool': 'unit_cost_comparator',
          'winner': winnerLabel,
          'size': chosen.sizeLabel,
          'package_price': chosen.price,
          'price_per_base': pricePerBase,
          'base_unit': comparison.baseLabel,
        },
      ).withCalculatedTotal();
    } else {
      item = CartItem(
        id: const Uuid().v4(),
        name: 'Produto Comparado (${chosen.sizeLabel})',
        unitPrice: chosen.price,
        quantity: 1,
        unit: 'un',
        totalPrice: chosen.price,
        addedAt: DateTime.now(),
        source: ScanSource.manual,
        rawOcrData: {
          'tool': 'unit_cost_comparator',
          'winner': winnerLabel,
          'size': chosen.sizeLabel,
          'package_price': chosen.price,
          'price_per_base': pricePerBase,
          'base_unit': comparison.baseLabel,
        },
      ).withCalculatedTotal();
    }

    ref.read(cartProvider.notifier).addItem(item);
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final optionA = _optionA;
    final optionB = _optionB;
    final comparison = compareUnitCosts(optionA, optionB);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.floatingShadow,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.balance_rounded,
                      color: Color(0xFF3B82F6),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comparador de Custo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Converta g/kg e ml/L e veja qual embalagem rende mais.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close_rounded, color: AppTheme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _OptionCard(
                      label: 'A',
                      accent: AppTheme.emerald,
                      priceController: _priceAController,
                      amountController: _amountAController,
                      unit: _unitA,
                      onUnitChanged: (unit) => setState(() => _unitA = unit),
                      onChanged: () => setState(() {}),
                      option: optionA,
                      isWinner: identical(comparison.winner, optionA),
                      isTie: comparison.isTie,
                      baseLabel: optionA.unit.baseLabel,
                      priceFieldKey: const Key('unit_cost_price_a'),
                      amountFieldKey: const Key('unit_cost_amount_a'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OptionCard(
                      label: 'B',
                      accent: const Color(0xFF3B82F6),
                      priceController: _priceBController,
                      amountController: _amountBController,
                      unit: _unitB,
                      onUnitChanged: (unit) => setState(() => _unitB = unit),
                      onChanged: () => setState(() {}),
                      option: optionB,
                      isWinner: identical(comparison.winner, optionB),
                      isTie: comparison.isTie,
                      baseLabel: optionB.unit.baseLabel,
                      priceFieldKey: const Key('unit_cost_price_b'),
                      amountFieldKey: const Key('unit_cost_amount_b'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ComparisonBanner(comparison: comparison),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('unit_cost_add_button'),
                  onPressed: comparison.isValid ? _addChosen : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: Text(
                    comparison.isTie
                        ? 'Adicionar Opção A ao Carrinho'
                        : 'Adicionar Vencedor ao Carrinho',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final Color accent;
  final TextEditingController priceController;
  final TextEditingController amountController;
  final MeasureUnit unit;
  final ValueChanged<MeasureUnit> onUnitChanged;
  final VoidCallback onChanged;
  final UnitCostOption option;
  final bool isWinner;
  final bool isTie;
  final String baseLabel;
  final Key priceFieldKey;
  final Key amountFieldKey;

  const _OptionCard({
    required this.label,
    required this.accent,
    required this.priceController,
    required this.amountController,
    required this.unit,
    required this.onUnitChanged,
    required this.onChanged,
    required this.option,
    required this.isWinner,
    required this.isTie,
    required this.baseLabel,
    required this.priceFieldKey,
    required this.amountFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = isWinner && !isTie;
    final pricePerBase = option.pricePerBase;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.emeraldTint : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? AppTheme.emerald : AppTheme.line,
          width: highlighted ? 1.8 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppTheme.emerald.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppTheme.emerald
                      : accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: highlighted ? Colors.white : accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Opção $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              if (highlighted)
                const Icon(
                  Icons.verified_rounded,
                  size: 17,
                  color: AppTheme.emerald,
                ),
            ],
          ),
          if (highlighted) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.emerald,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'Mais Econômico!',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          TextField(
            key: priceFieldKey,
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Preço',
              hintText: '0,00',
              prefixText: r'R$ ',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            key: amountFieldKey,
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Qtd./peso',
              hintText: '0',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Unidade',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<MeasureUnit>(
                value: unit,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
                items: MeasureUnit.values
                    .map(
                      (unit) => DropdownMenuItem<MeasureUnit>(
                        value: unit,
                        child: Text(unit.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onUnitChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pricePerBase == null
                      ? 'R\$ -- / $baseLabel'
                      : '${Formatters.currency(pricePerBase)} / $baseLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: highlighted ? AppTheme.emeraldDark : AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  option.isValid ? option.sizeLabel : 'Aguardando dados',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBanner extends StatelessWidget {
  final UnitCostComparison comparison;

  const _ComparisonBanner({required this.comparison});

  @override
  Widget build(BuildContext context) {
    if (!comparison.isValid) {
      return _BannerShell(
        background: AppTheme.amberTint,
        border: AppTheme.amber.withValues(alpha: 0.35),
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFFB26B00),
        child: Text(
          comparison.invalidReason ??
              'Informe o preço e a quantidade das duas opções.',
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A5A00),
          ),
        ),
      );
    }

    if (comparison.isTie) {
      final price = comparison.optionA.pricePerBase;
      return _BannerShell(
        background: const Color(0xFFEFF6FF),
        border: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        icon: Icons.handshake_rounded,
        iconColor: const Color(0xFF3B82F6),
        child: Text(
          price == null
              ? 'As duas opções custam o mesmo por ${comparison.baseLabel}.'
              : 'As duas opções custam o mesmo por ${comparison.baseLabel}: '
                  '${Formatters.currency(price)}.',
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A8A),
          ),
        ),
      );
    }

    final winner = comparison.winner!;
    final loser = comparison.loser!;
    final winnerLabel = identical(winner, comparison.optionA) ? 'A' : 'B';
    final loserLabel = winnerLabel == 'A' ? 'B' : 'A';
    final winnerPrice = winner.pricePerBase!;
    final loserPrice = loser.pricePerBase!;
    final difference = comparison.differencePerBase;
    final differencePercent = comparison.differencePercent;

    return _BannerShell(
      key: const Key('unit_cost_comparison'),
      background: AppTheme.emeraldTint,
      border: AppTheme.emerald.withValues(alpha: 0.3),
      icon: Icons.emoji_events_rounded,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O R\$${comparison.baseLabel} da Opção $winnerLabel '
            '(${Formatters.currency(winnerPrice)}) é mais barato que o da '
            'Opção $loserLabel (${Formatters.currency(loserPrice)}).',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppTheme.emeraldDark,
            ),
          ),
          if (difference != null && differencePercent != null) ...[
            const SizedBox(height: 4),
            Text(
              'Diferença de ${Formatters.currency(difference)} por '
              '${comparison.baseLabel} '
              '(${Formatters.percent(differencePercent)} mais barato).',
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: AppTheme.emeraldDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerShell extends StatelessWidget {
  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _BannerShell({
    super.key,
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(width: 9),
          Expanded(child: child),
        ],
      ),
    );
  }
}
