import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/cart_item.dart';
import '../../../../core/models/partial_scan_data.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/price_parser.dart';

/// Abre a folha de leitura parcial e devolve o item confirmado.
Future<CartItem?> showPartialScanSheet(
  BuildContext context,
  PartialScanData data, {
  String? photoPath,
}) {
  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return PartialScanSheet(
        data: data,
        photoPath: photoPath,
        onSubmit: (item) => Navigator.pop(ctx, item),
        onRetry: () => Navigator.pop(ctx),
      );
    },
  );
}

/// Folha mostrada quando a câmera leu apenas parte da etiqueta.
///
/// O campo já lido vem preenchido; o utilizador completa o que falta e o item
/// só entra no carrinho depois de validado.
class PartialScanSheet extends StatefulWidget {
  final PartialScanData data;
  final String? photoPath;
  final ValueChanged<CartItem> onSubmit;
  final VoidCallback onRetry;

  const PartialScanSheet({
    super.key,
    required this.data,
    this.photoPath,
    required this.onSubmit,
    required this.onRetry,
  });

  @override
  State<PartialScanSheet> createState() => _PartialScanSheetState();
}

class _PartialScanSheetState extends State<PartialScanSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.data.suggestedName ?? '',
    );
    _priceController = TextEditingController(
      text: widget.data.hasPrice
          ? widget.data.unitPrice!.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = PriceParser.parsePrice(_priceController.text);
    if (!PriceParser.isSanePrice(price)) return;

    final name = _nameController.text.trim();
    final item = CartItem(
      id: const Uuid().v4(),
      name: name,
      ean: widget.data.ean,
      unitPrice: price!,
      quantity: 1,
      unit: 'un',
      totalPrice: price,
      addedAt: DateTime.now(),
      source: ScanSource.camera,
      photoPath: widget.photoPath,
      rawOcrData: {
        'partial_read': true,
        'detected_ean': widget.data.ean,
        'detected_price': widget.data.unitPrice,
        'raw_text': widget.data.rawText,
      },
    );

    widget.onSubmit(item);
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
                        color: AppTheme.amberTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.playlist_add_check_circle_rounded,
                        color: Color(0xFFB26B00),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completar informações',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'A leitura foi parcial, mas nada foi perdido.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.data.guidance,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.data.hasEan)
                      _DetectedChip(
                        icon: Icons.qr_code_2_rounded,
                        label: 'EAN ${widget.data.ean}',
                      ),
                    if (widget.data.hasPrice)
                      _DetectedChip(
                        icon: Icons.payments_rounded,
                        label:
                            'Preço ${Formatters.currency(widget.data.unitPrice!)}',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofocus: (widget.data.suggestedName ?? '').trim().isEmpty,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                    hintText: 'Ex.: Leite integral 1L',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do produto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  autofocus:
                      (widget.data.suggestedName ?? '').trim().isNotEmpty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Preço unitário',
                    prefixText: r'R$ ',
                    hintText: '0,00',
                  ),
                  validator: (value) {
                    final price = PriceParser.parsePrice(value ?? '');
                    if (!PriceParser.isSanePrice(price)) {
                      return 'Preço inválido';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: const Text('Adicionar ao carrinho'),
                  ),
                ),
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('Escanear de novo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectedChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetectedChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.emeraldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.emeraldDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.emeraldDark,
            ),
          ),
        ],
      ),
    );
  }
}
