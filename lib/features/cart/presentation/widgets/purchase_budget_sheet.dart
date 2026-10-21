import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

/// Result of the optional budget sheet.
///
/// A `null` returned by [showPurchaseBudgetSheet] means the sheet was dismissed
/// without a decision. A [BudgetSetupResult] with a null [budget] means the user
/// explicitly chose to continue without a ceiling (or removed the old one).
class BudgetSetupResult {
  final double? budget;

  const BudgetSetupResult(this.budget);
}

Future<BudgetSetupResult?> showPurchaseBudgetSheet(
  BuildContext context, {
  double? initialBudget,
}) {
  return showModalBottomSheet<BudgetSetupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PurchaseBudgetSheet(initialBudget: initialBudget),
  );
}

class PurchaseBudgetSheet extends StatefulWidget {
  final double? initialBudget;

  const PurchaseBudgetSheet({super.key, this.initialBudget});

  @override
  State<PurchaseBudgetSheet> createState() => _PurchaseBudgetSheetState();
}

class _PurchaseBudgetSheetState extends State<PurchaseBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  String? _error;

  bool get _editing => widget.initialBudget != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialBudget == null
          ? ''
          : Formatters.currencyCompact(widget.initialBudget!),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parseBudget(String raw) {
    var value = raw
        .replaceAll('R\$', '')
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(RegExp(r'[^0-9,.]'), '');
    if (value.isEmpty) return null;

    final lastComma = value.lastIndexOf(',');
    final lastDot = value.lastIndexOf('.');
    if (lastComma >= 0 && lastComma > lastDot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot >= 0) {
      value = value.replaceAll(',', '');
    }

    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0 || parsed > 100000) return null;
    return parsed;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final value = _parseBudget(_controller.text);
    if (value == null) {
      setState(
          () => _error = 'Informe um valor entre R\$ 1,00 e R\$ 100.000,00.');
      return;
    }

    Navigator.pop(context, BudgetSetupResult(value));
  }

  void _skip() {
    Navigator.pop(context, const BudgetSetupResult(null));
  }

  void _remove() {
    Navigator.pop(context, const BudgetSetupResult(null));
  }

  void _usePreset(double value) {
    setState(() {
      _controller.text = Formatters.currencyCompact(value);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

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
          child: Form(
            key: _formKey,
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
                        color: AppTheme.emeraldTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.savings_rounded,
                        color: AppTheme.emeraldDark,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editing
                                ? 'Editar orçamento'
                                : 'Orçamento da compra',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Opcional. Defina um teto para não passar do planejado.',
                            style: TextStyle(
                              fontSize: 12,
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
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('purchase_budget_input'),
                  controller: _controller,
                  autofocus: !_editing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Orçamento máximo',
                    prefixText: r'R$ ',
                    hintText: '0,00',
                    helperText: 'Deixe em branco para comprar sem teto.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe um valor ou continue sem orçamento';
                    }
                    return _parseBudget(value) == null
                        ? 'Valor inválido'
                        : null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100.0, 200.0, 300.0, 500.0]
                      .map(
                        (value) => ActionChip(
                          label: Text('R\$ ${value.toInt()}'),
                          onPressed: () => _usePreset(value),
                          backgroundColor: AppTheme.background,
                          side: const BorderSide(color: AppTheme.line),
                          labelStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      _editing ? 'Salvar orçamento' : 'Definir orçamento',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text('Continuar sem orçamento'),
                  ),
                ),
                if (_editing)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _remove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.red,
                      ),
                      child: const Text('Remover orçamento'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
