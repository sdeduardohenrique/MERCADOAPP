import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'cart_item_editor_sheet.dart';

/// Opens the shared cart editor in "new item" mode and adds the result to the
/// current cart.
Future<CartItem?> showManualItemSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final item = await showCartItemEditorSheet(context);
  if (item == null) return null;

  ref.read(cartProvider.notifier).addItem(item);
  return item;
}
