import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/domain/sync_codec.dart';

String pack(Object? json) =>
    base64Encode(gzip.encode(utf8.encode(jsonEncode(json))));

Map<String, Object?> valid([Map<String, Object?> override = const {}]) => {
  'b': '123',
  'n': 'Gum',
  'p': 250,
  's': 4,
  'u': 1000,
  'd': 0,
  ...override,
};

void main() {
  const noodles = Item(
    barcode: '4800016644290',
    name: 'Lucky Me Pancit Canton',
    priceCents: 1500,
    stockQty: 24,
    updatedAt: 1760600000000,
  );

  test(
    'round trip keeps every field, including deleted and negative stock',
    () {
      final items = [
        noodles,
        const Item(
          barcode: 'X',
          name: 'Piña colada ₱ 日本',
          priceCents: 1,
          stockQty: -3,
          updatedAt: 5,
          deleted: true,
        ),
      ];
      final back = decodeCatalog(encodeCatalog(items));
      expect(back.map((i) => i.toMap()), items.map((i) => i.toMap()));
    },
  );

  test('empty catalog round-trips', () {
    expect(decodeCatalog(encodeCatalog([])), isEmpty);
  });

  test('payload is gzipped JSON with the compact keys b n p s u d', () {
    final json = jsonDecode(
      utf8.decode(gzip.decode(base64Decode(encodeCatalog([noodles])))),
    );
    expect(json, [
      {
        'b': '4800016644290',
        'n': 'Lucky Me Pancit Canton',
        'p': 1500,
        's': 24,
        'u': 1760600000000,
        'd': 0,
      },
    ]);
  });

  test('gzip makes a big catalog smaller than its raw JSON', () {
    final items = [
      for (var i = 0; i < 500; i++)
        Item(
          barcode: '480001664${i.toString().padLeft(4, '0')}',
          name: 'Product number $i',
          priceCents: 1000 + i,
          stockQty: i % 30,
          updatedAt: 1760600000000 + i,
        ),
    ];
    final raw = utf8
        .encode(jsonEncode([for (final i in items) i.toMap()]))
        .length;
    expect(encodeCatalog(items).length, lessThan(raw));
    expect(decodeCatalog(encodeCatalog(items)), hasLength(500));
  });

  group('rejects bad data with FormatException', () {
    void rejects(String name, String payload) => test(
      name,
      () => expect(() => decodeCatalog(payload), throwsFormatException),
    );

    rejects('not base64', '!!! not base64 !!!');
    rejects('base64 but not gzip', base64Encode(utf8.encode('hello')));
    rejects(
      'gzip but not JSON',
      base64Encode(gzip.encode(utf8.encode('nope'))),
    );
    rejects('JSON object instead of a list', pack({'b': '1'}));
    rejects('item that is not an object', pack([1]));
    rejects('missing key', pack([valid()..remove('n')]));
    rejects(
      'blank barcode',
      pack([
        valid({'b': '  '}),
      ]),
    );
    rejects(
      'blank name',
      pack([
        valid({'n': ''}),
      ]),
    );
    rejects(
      'zero price',
      pack([
        valid({'p': 0}),
      ]),
    );
    rejects(
      'price as a string',
      pack([
        valid({'p': '250'}),
      ]),
    );
    rejects(
      'fractional price',
      pack([
        valid({'p': 2.5}),
      ]),
    );
    rejects(
      'negative updated_at',
      pack([
        valid({'u': -1}),
      ]),
    );
    rejects(
      'deleted flag out of range',
      pack([
        valid({'d': 2}),
      ]),
    );
    rejects(
      'one bad item among good ones',
      pack([
        valid(),
        valid({'p': 0}),
      ]),
    );
  });

  test('truncated payload is rejected, not partially decoded', () {
    final full = encodeCatalog([noodles, noodles]);
    expect(
      () => decodeCatalog(full.substring(0, full.length ~/ 2)),
      throwsFormatException,
    );
  });
}
