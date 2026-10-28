import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/purchase_share_service.dart';

final purchaseShareServiceProvider = Provider<PurchaseShareService>((ref) {
  return const PurchaseShareService();
});
