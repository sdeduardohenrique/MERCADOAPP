import 'package:flutter/material.dart';

import '../../../../core/models/cart_item.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

/// Bottom sheet shown after a price was read twice in a row.
///
/// The scanner stays paused until the user either confirms the item or asks to
/// scan again. Keeping this widget separate makes the confirmation UI easy to
/// test without a camera.
class ScanConfirmationSheet extends StatelessWidget {
  final CartItem item;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  const ScanConfirmationSheet({
    super.key,
    required this.item,
    required this.onConfirm,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.floatingShadow,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppTheme.emeraldTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.emeraldDark,
                  size: 34,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Leitura confirmada',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                Formatters.currency(item.unitPrice),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emeraldDark,
                  letterSpacing: -1,
                ),
              ),
              Text(
                '${item.quantity} ${item.quantity == 1 ? 'item' : 'itens'}'
                ' • ${item.unit}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
              if (item.photoPath != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldTint,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_back_outlined,
                        size: 15,
                        color: AppTheme.emeraldDark,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Foto da etiqueta guardada',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: const Text('Adicionar ao carrinho'),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Escanear de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
