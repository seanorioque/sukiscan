import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cart.dart';
import '../../domain/item.dart';

final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  void add(Item item) => state = state.add(item);
}
