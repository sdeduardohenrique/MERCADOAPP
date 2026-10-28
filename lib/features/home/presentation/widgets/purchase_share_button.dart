import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/purchase_share_provider.dart';

/// Botão "Compartilhar Resumo".
///
/// [expanded] = true para o botão principal nas telas de sucesso/detalhes;
/// false para o ícone compacto na AppBar.
class PurchaseShareButton extends ConsumerStatefulWidget {
  final Purchase purchase;
  final bool expanded;

  const PurchaseShareButton({
    super.key,
    required this.purchase,
    this.expanded = true,
  });

  @override
  ConsumerState<PurchaseShareButton> createState() =>
      _PurchaseShareButtonState();
}

class _PurchaseShareButtonState extends ConsumerState<PurchaseShareButton> {
  final GlobalKey _buttonKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final box =
          _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;

      await ref
          .read(purchaseShareServiceProvider)
          .share(widget.purchase, sharePositionOrigin: origin);
    } catch (error) {
      debugPrint('[SomaAí] Falha ao compartilhar resumo: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível compartilhar o resumo. Tente novamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _spinner(Color color) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded) {
      return IconButton(
        key: _buttonKey,
        onPressed: _sharing ? null : _share,
        tooltip: 'Compartilhar Resumo',
        icon: _sharing
            ? _spinner(AppTheme.emerald)
            : const Icon(Icons.share_rounded, size: 20),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: _buttonKey,
        onPressed: _sharing ? null : _share,
        icon: _sharing
            ? _spinner(Colors.white)
            : const Icon(Icons.share_rounded, size: 19),
        label: const Text('Compartilhar Resumo'),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
