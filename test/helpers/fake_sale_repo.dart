import 'package:sukiscan/data/sale_repository.dart';
import 'package:sukiscan/domain/cart.dart';
import 'package:sukiscan/domain/sale.dart';

/// In-memory SaleRepository for widget tests: records calls, can be made to fail.
class FakeSaleRepo implements SaleRepository {
  final calls = <({Cart cart, int? cashCents})>[];
  bool fail = false;

  /// History: the sales listed (newest first) and each one's lines.
  final sales = <SaleSummary>[];
  final lineItems = <String, List<SaleLine>>{};
  final deleted = <String>[];
  bool failDelete = false;

  @override
  Future<String> checkout(Cart cart, {int? cashCents}) async {
    if (fail) throw StateError('db down');
    calls.add((cart: cart, cashCents: cashCents));
    return 'sale-${calls.length}';
  }

  @override
  Future<List<SaleSummary>> history() async => List.of(sales);

  @override
  Future<List<SaleLine>> lines(String saleId) async =>
      lineItems[saleId] ?? const [];

  @override
  Future<int> deleteSales(Iterable<String> ids) async {
    if (failDelete) throw StateError('db down');
    final gone = ids.toSet();
    deleted.addAll(gone);
    sales.removeWhere((s) => gone.contains(s.id));
    return gone.length;
  }
}
