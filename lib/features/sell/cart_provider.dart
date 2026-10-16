import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cart.dart';
import '../../domain/item.dart';

final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  void add(Item item) => state = state.add(item);
  void increment(String barcode) => state = state.increment(barcode);
  void decrement(String barcode) => state = state.decrement(barcode);
  void remove(String barcode) => state = state.remove(barcode);
  void clear() => state = state.clear();
}
