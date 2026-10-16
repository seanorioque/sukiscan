import 'package:sukiscan/data/sale_repository.dart';
import 'package:sukiscan/domain/cart.dart';

/// In-memory SaleRepository for widget tests: records calls, can be made to fail.
class FakeSaleRepo implements SaleRepository {
  final calls = <({Cart cart, int? cashCents})>[];
  bool fail = false;

  @override
  Future<String> checkout(Cart cart, {int? cashCents}) async {
    if (fail) throw StateError('db down');
    calls.add((cart: cart, cashCents: cashCents));
    return 'sale-${calls.length}';
  }
}
