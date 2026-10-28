import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/cart_item.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/purchase_tools.dart';
import '../providers/cart_provider.dart';

/// Abre a calculadora de promoções e devolve o item adicionado ao carrinho.
Future<CartItem?> showPromotionCalculatorModal(BuildContext context) {
  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PromotionCalculatorModal(),
  );
}

class PromotionCalculatorModal extends ConsumerStatefulWidget {
  const PromotionCalculatorModal({super.key});

  @override
  ConsumerState<PromotionCalculatorModal> createState() =>
      _PromotionCalculatorModalState();
}

class _PromotionCalculatorModalState
    extends ConsumerState<PromotionCalculatorModal> {
  final _nameController = TextEditingController();
  final _normalPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '3');
  final _promoPriceController = TextEditingController();

  final _takeController = TextEditingController(text: '3');
  final _payController = TextEditingController(text: '2');
  final _unitPriceController = TextEditingController();

  PromotionKind _kind = PromotionKind.wholesale;

  @override
  void dispose() {
    _nameController.dispose();
    _normalPriceController.dispose();
    _quantityController.dispose();
    _promoPriceController.dispose();
    _takeController.dispose();
    _payController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  WholesalePromotion? get _wholesale {
    final normal = parseDecimalInput(_normalPriceController.text);
    final quantity = int.tryParse(_quantityController.text.trim());
    final promo = parseDecimalInput(_promoPriceController.text);
    if (normal == null || quantity == null || promo == null) return null;

    final promotion = WholesalePromotion(
      normalUnitPrice: normal,
      quantity: quantity,
      promoUnitPrice: promo,
    );
    return promotion.isValid ? promotion : null;
  }

  BuyXPayYPromotion? get _buyXPayY {
    final take = int.tryParse(_takeController.text.trim());
    final pay = int.tryParse(_payController.text.trim());
    final price = parseDecimalInput(_unitPriceController.text);
    if (take == null || pay == null || price == null) return null;

    final promotion = BuyXPayYPromotion(
      take: take,
      pay: pay,
      unitPrice: price,
    );
    return promotion.isValid ? promotion : null;
  }

  bool get _canAdd =>
      _kind == PromotionKind.wholesale ? _wholesale != null : _buyXPayY != null;

  String _productName(String fallback) {
    final typed = _nameController.text.trim();
    return typed.isEmpty ? fallback : typed;
  }

  void _addPromotion() {
    final CartItem? item;
    if (_kind == PromotionKind.wholesale) {
      final promotion = _wholesale;
      if (promotion == null) return;
      item = CartItem(
        id: const Uuid().v4(),
        name: _productName('Promoção atacado (${promotion.quantity} un.)'),
        unitPrice: promotion.promoUnitPrice,
        quantity: promotion.quantity,
        unit: 'un',
        totalPrice: 0,
        addedAt: DateTime.now(),
        source: ScanSource.manual,
        rawOcrData: {
          'tool': 'promotion_calculator',
          'scenario': 'wholesale',
          'normal_unit_price': promotion.normalUnitPrice,
          'promo_unit_price': promotion.promoUnitPrice,
          'quantity': promotion.quantity,
          'normal_total': promotion.normalTotal,
          'savings': promotion.savings,
        },
      ).withCalculatedTotal();
    } else {
      final promotion = _buyXPayY;
      if (promotion == null) return;
      item = CartItem(
        id: const Uuid().v4(),
        name: _productName(
          'Promoção leve ${promotion.take} pague ${promotion.pay}',
        ),
        unitPrice: promotion.effectiveUnitPrice,
        quantity: promotion.take,
        unit: 'un',
        totalPrice: 0,
        addedAt: DateTime.now(),
        source: ScanSource.manual,
        rawOcrData: {
          'tool': 'promotion_calculator',
          'scenario': 'buy_x_pay_y',
          'take': promotion.take,
          'pay': promotion.pay,
          'unit_price': promotion.unitPrice,
          'paid_total': promotion.total,
          'effective_unit_price': promotion.effectiveUnitPrice,
          'savings': promotion.savings,
        },
      ).withCalculatedTotal();
    }

    ref.read(cartProvider.notifier).addItem(item);
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
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
                      color: AppTheme.amberTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: Color(0xFFB26B00),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculadora de Promoções',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Descubra o preço real da oferta e quanto você '
                          'economiza.',
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
              TextField(
                key: const Key('promo_name'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Produto (opcional)',
                  hintText: 'Ex.: Arroz 5 kg',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<PromotionKind>(
                key: const Key('promo_kind'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppTheme.emeraldTint,
                  selectedForegroundColor: AppTheme.emeraldDark,
                  foregroundColor: AppTheme.muted,
                  side: const BorderSide(color: AppTheme.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: PromotionKind.wholesale,
                    icon: Icon(Icons.inventory_2_outlined, size: 17),
                    label: Text('Atacado'),
                  ),
                  ButtonSegment(
                    value: PromotionKind.buyXPayY,
                    icon: Icon(Icons.redeem_rounded, size: 17),
                    label: Text('Leve X, Pague Y'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) {
                  setState(() => _kind = selection.first);
                },
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _kind == PromotionKind.wholesale
                    ? _WholesaleForm(
                        key: const ValueKey('wholesale_form'),
                        normalPriceController: _normalPriceController,
                        quantityController: _quantityController,
                        promoPriceController: _promoPriceController,
                        onChanged: () => setState(() {}),
                      )
                    : _BuyXPayYForm(
                        key: const ValueKey('buy_x_pay_y_form'),
                        takeController: _takeController,
                        payController: _payController,
                        unitPriceController: _unitPriceController,
                        onChanged: () => setState(() {}),
                      ),
              ),
              const SizedBox(height: 16),
              _PromotionResult(
                kind: _kind,
                wholesale: _wholesale,
                buyXPayY: _buyXPayY,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('promo_add_button'),
                  onPressed: _canAdd ? _addPromotion : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: const Text('Adicionar Promoção ao Carrinho'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WholesaleForm extends StatelessWidget {
  final TextEditingController normalPriceController;
  final TextEditingController quantityController;
  final TextEditingController promoPriceController;
  final VoidCallback onChanged;

  const _WholesaleForm({
    super.key,
    required this.normalPriceController,
    required this.quantityController,
    required this.promoPriceController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A partir de N unidades, cada uma sai por um preço menor.',
          style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MoneyField(
                fieldKey: const Key('promo_normal_price'),
                controller: normalPriceController,
                label: 'Preço normal',
                hint: '5,00',
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoneyField(
                fieldKey: const Key('promo_price'),
                controller: promoPriceController,
                label: 'Preço promo',
                hint: '4,50',
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('promo_quantity'),
          controller: quantityController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Quantidade mínima',
            hintText: '3',
            suffixText: 'un',
            prefixIcon: Icon(Icons.numbers_rounded),
            helperText: 'A promoção vale a partir de 2 unidades.',
          ),
        ),
      ],
    );
  }
}

class _BuyXPayYForm extends StatelessWidget {
  final TextEditingController takeController;
  final TextEditingController payController;
  final TextEditingController unitPriceController;
  final VoidCallback onChanged;

  const _BuyXPayYForm({
    super.key,
    required this.takeController,
    required this.payController,
    required this.unitPriceController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leve mais unidades pagando apenas as que foram cobradas.',
          style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('promo_take'),
                controller: takeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Leve (X)',
                  hintText: '3',
                  suffixText: 'un',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('promo_pay'),
                controller: payController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Pague (Y)',
                  hintText: '2',
                  suffixText: 'un',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MoneyField(
          fieldKey: const Key('promo_buy_unit_price'),
          controller: unitPriceController,
          label: 'Preço unitário',
          hint: '6,00',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MoneyField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  const _MoneyField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: r'R$ ',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 15,
        ),
      ),
    );
  }
}

class _PromotionResult extends StatelessWidget {
  final PromotionKind kind;
  final WholesalePromotion? wholesale;
  final BuyXPayYPromotion? buyXPayY;

  const _PromotionResult({
    required this.kind,
    required this.wholesale,
    required this.buyXPayY,
  });

  @override
  Widget build(BuildContext context) {
    if (kind == PromotionKind.wholesale) {
      final promotion = wholesale;
      if (promotion == null) {
        return const _ResultHint(
          text: 'Informe o preço normal, a quantidade mínima (2+) e o preço '
              'promocional para ver o total e a economia.',
        );
      }
      return _WholesaleResult(promotion: promotion);
    }

    final promotion = buyXPayY;
    if (promotion == null) {
      return const _ResultHint(
        text: 'Informe o "Leve" (2+), o "Pague" (menor que o leve) e o preço '
            'unitário para ver o preço rateado.',
      );
    }
    return _BuyXPayYResult(promotion: promotion);
  }
}

class _ResultHint extends StatelessWidget {
  final String text;

  const _ResultHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.calculate_outlined,
            size: 19,
            color: AppTheme.muted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WholesaleResult extends StatelessWidget {
  final WholesalePromotion promotion;

  const _WholesaleResult({required this.promotion});

  @override
  Widget build(BuildContext context) {
    final hasSavings = promotion.hasSavings;

    return Container(
      key: const Key('promo_result_wholesale'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: hasSavings ? AppTheme.emeraldTint : AppTheme.amberTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasSavings
              ? AppTheme.emerald.withValues(alpha: 0.25)
              : AppTheme.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total na promoção',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.emeraldDark,
                  ),
                ),
              ),
              Text(
                '${promotion.quantity} × '
                '${Formatters.currency(promotion.promoUnitPrice)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.currency(promotion.total),
            style: const TextStyle(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppTheme.emeraldDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Sem promoção: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                      TextSpan(
                        text: Formatters.currency(promotion.normalTotal),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasSavings)
                _SavingsChip(
                  savings: promotion.savings,
                  percent: promotion.savingsPercent,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasSavings
                ? 'Cada unidade sai por '
                    '${Formatters.currency(promotion.effectiveUnitPrice)}. '
                    'Você economiza ${Formatters.currency(promotion.savings)} '
                    'no total.'
                : 'Essa oferta não gera economia em relação ao preço normal.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color:
                  hasSavings ? AppTheme.emeraldDark : const Color(0xFF8A5A00),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyXPayYResult extends StatelessWidget {
  final BuyXPayYPromotion promotion;

  const _BuyXPayYResult({required this.promotion});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('promo_result_buy_x_pay_y'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: AppTheme.emeraldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.celebration_rounded,
                  size: 17, color: AppTheme.emerald),
              SizedBox(width: 6),
              Text(
                'PREÇO RATEADO',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppTheme.emeraldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nessa promoção, cada unidade sai por apenas '
            '${Formatters.currency(promotion.effectiveUnitPrice)}!',
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppTheme.emeraldDark,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Você paga por ${promotion.pay}: '
                    '${Formatters.currency(promotion.total)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Text(
                  'Leva ${promotion.take}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  promotion.freeUnits == 1
                      ? '1 unidade grátis'
                      : '${promotion.freeUnits} unidades grátis',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.emeraldDark,
                  ),
                ),
              ),
              if (promotion.hasSavings)
                _SavingsChip(
                  savings: promotion.savings,
                  percent: promotion.savingsPercent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavingsChip extends StatelessWidget {
  final double savings;
  final double percent;

  const _SavingsChip({required this.savings, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.emerald,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Economia ${Formatters.currency(savings)} '
        '(${Formatters.percent(percent)})',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
