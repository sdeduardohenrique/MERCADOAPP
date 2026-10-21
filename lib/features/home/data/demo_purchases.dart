import '../../../../core/models/purchase.dart';

/// Dados de demonstração do histórico.
///
/// Usados apenas no primeiro arranque para que o Dashboard tenha conteúdo.
/// Podem ser removidos apagando o histórico na aba Perfil (ou excluindo este
/// arquivo e a chamada em `PurchaseHistoryNotifier`).
class DemoPurchases {
  DemoPurchases._();

  static List<Purchase> build() {
    final now = DateTime.now();
    return [
      Purchase(
        id: 'demo-1',
        storeName: 'Supermercado Extra',
        date: now.subtract(const Duration(days: 1, hours: 3)),
        savings: 18.40,
        items: const [
          PurchaseItem(name: 'Arroz branco 5kg', unitPrice: 27.90, quantity: 1),
          PurchaseItem(
              name: 'Feijão carioca 1kg', unitPrice: 8.99, quantity: 2),
          PurchaseItem(name: 'Leite integral 1L', unitPrice: 4.49, quantity: 6),
          PurchaseItem(
              name: 'Café torrado 500g', unitPrice: 18.90, quantity: 1),
          PurchaseItem(name: 'Detergente 500ml', unitPrice: 2.79, quantity: 2),
        ],
      ),
      Purchase(
        id: 'demo-2',
        storeName: 'Assaí Atacadista',
        date: now.subtract(const Duration(days: 4, hours: 6)),
        savings: 12.15,
        items: const [
          PurchaseItem(
              name: 'Frango inteiro (kg)', unitPrice: 14.90, quantity: 2),
          PurchaseItem(
              name: 'Óleo de soja 900ml', unitPrice: 7.49, quantity: 2),
          PurchaseItem(
              name: 'Açúcar refinado 1kg', unitPrice: 4.29, quantity: 2),
          PurchaseItem(name: 'Macarrão 500g', unitPrice: 3.99, quantity: 4),
          PurchaseItem(
              name: 'Molho de tomate 340g', unitPrice: 2.49, quantity: 4),
        ],
      ),
      Purchase(
        id: 'demo-3',
        storeName: 'Carrefour',
        date: now.subtract(const Duration(days: 9, hours: 2)),
        savings: 22.30,
        items: const [
          PurchaseItem(
              name: 'Carne bovina (kg)', unitPrice: 39.90, quantity: 1),
          PurchaseItem(
              name: 'Queijo mussarela (kg)', unitPrice: 24.90, quantity: 1),
          PurchaseItem(
              name: 'Presunto fatiado (kg)', unitPrice: 24.90, quantity: 1),
          PurchaseItem(name: 'Pão de forma', unitPrice: 8.99, quantity: 1),
          PurchaseItem(name: 'Ovos 12 unidades', unitPrice: 12.90, quantity: 1),
        ],
      ),
      Purchase(
        id: 'demo-4',
        storeName: 'Pão de Açúcar',
        date: now.subtract(const Duration(days: 16, hours: 5)),
        savings: 6.75,
        items: const [
          PurchaseItem(name: 'Banana prata (kg)', unitPrice: 5.99, quantity: 2),
          PurchaseItem(name: 'Maçã (kg)', unitPrice: 8.99, quantity: 1),
          PurchaseItem(name: 'Tomate (kg)', unitPrice: 6.99, quantity: 1),
          PurchaseItem(name: 'Alface crespa', unitPrice: 3.49, quantity: 1),
          PurchaseItem(
              name: 'Iogurte 6 unidades', unitPrice: 12.90, quantity: 1),
        ],
      ),
    ];
  }
}
