import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Ferramentas disponíveis no hub "+" da Nova Compra.
enum PurchaseTool { manual, voice, promotion, unitCost }

/// Abre o hub "Ferramentas de Compra" e devolve a ferramenta escolhida.
///
/// A tela só abre a ferramenta depois que este sheet fecha, evitando duas
/// rotas empilhadas ao mesmo tempo.
Future<PurchaseTool?> showPurchaseToolsSheet(BuildContext context) {
  return showModalBottomSheet<PurchaseTool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PurchaseToolsSheet(),
  );
}

class PurchaseToolsSheet extends StatelessWidget {
  const PurchaseToolsSheet({super.key});

  static const _blue = Color(0xFF3B82F6);
  static const _blueTint = Color(0xFFEFF6FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.emeraldTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.emeraldDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ferramentas de Compra',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Atalhos para registrar, comparar e economizar '
                          'sem sair da compra.',
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
              _ToolTile(
                icon: Icons.keyboard_rounded,
                title: 'Entrada Manual',
                subtitle: 'Digite o produto e o preço da etiqueta',
                background: AppTheme.emeraldTint,
                foreground: AppTheme.emeraldDark,
                onTap: () => Navigator.pop(context, PurchaseTool.manual),
              ),
              const SizedBox(height: 10),
              _ToolTile(
                icon: Icons.mic_rounded,
                title: 'Entrada por Voz',
                subtitle: 'Fale o item e o valor para adicionar',
                background: AppTheme.emeraldTint,
                foreground: AppTheme.emeraldDark,
                onTap: () => Navigator.pop(context, PurchaseTool.voice),
              ),
              const SizedBox(height: 10),
              _ToolTile(
                icon: Icons.local_offer_rounded,
                title: 'Calculadora de Promoções',
                subtitle: 'Atacado e "Leve X, Pague Y"',
                background: AppTheme.amberTint,
                foreground: const Color(0xFFB26B00),
                onTap: () => Navigator.pop(context, PurchaseTool.promotion),
              ),
              const SizedBox(height: 10),
              _ToolTile(
                icon: Icons.balance_rounded,
                title: 'Comparador de Custo',
                subtitle: 'Qual embalagem vale mais a pena?',
                background: _blueTint,
                foreground: _blue,
                onTap: () => Navigator.pop(context, PurchaseTool.unitCost),
              ),
              const SizedBox(height: 14),
              const Text(
                'As ferramentas calculam o preço real por unidade e '
                'adicionam o resultado direto ao carrinho.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
