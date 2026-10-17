import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/domain/item.dart';
import 'package:tindascan/domain/items_csv.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

const header = 'barcode,item name,price,stock quantity';

CsvImport read(String body, {String head = header}) =>
    parseItemsCsv(bytes('$head\n$body'));

void main() {
  group('parseCsv', () {
    test('splits rows and cells', () {
      expect(parseCsv('a,b,c\n1,2,3\n'), [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('the last row needs no final line break', () {
      expect(parseCsv('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('handles CRLF, CR and BOM', () {
      expect(parseCsv('﻿a,b\r\n1,2\r\n3,4\r5,6'), [
        ['a', 'b'],
        ['1', '2'],
        ['3', '4'],
        ['5', '6'],
      ]);
    });

    test('quoted cells keep commas, line breaks and doubled quotes', () {
      expect(parseCsv('"a,b","say ""hi""","line1\nline2"\n'), [
        ['a,b', 'say "hi"', 'line1\nline2'],
      ]);
    });

    test('empty cells stay as empty strings', () {
      expect(parseCsv(',,\n1,,3'), [
        ['', '', ''],
        ['1', '', '3'],
      ]);
    });

    test('a quote in the middle of a cell is just a character', () {
      expect(parseCsv('5" pipe,x'), [
        ['5" pipe', 'x'],
      ]);
    });

    test('empty text has no rows', () {
      expect(parseCsv(''), isEmpty);
    });

    test('an unclosed quote is an error', () {
      expect(() => parseCsv('a,"b\nc'), throwsFormatException);
    });
  });

  group('importing a valid file', () {
    test('reads every column', () {
      final r = read('4800016644290,Pancit Canton,15.00,24\n111,Gum,2.5,0\n');
      expect(r.ok, isTrue);
      expect(r.items, hasLength(2));
      expect(r.items[0].barcode, '4800016644290');
      expect(r.items[0].name, 'Pancit Canton');
      expect(r.items[0].priceCents, 1500);
      expect(r.items[0].stockQty, 24);
      expect(r.items[1].priceCents, 250);
      expect(r.items[1].stockQty, 0);
    });

    test('stock quantity may be blank (it is the only column that may)', () {
      final r = read('111,Gum,2.5,\n222,Soda,10,   \n');
      expect(r.ok, isTrue);
      expect(r.items.map((i) => i.stockQty), [null, null]);
    });

    test('the stock quantity column may be missing altogether', () {
      final r = read('111,Gum,2.5\n', head: 'barcode,item name,price');
      expect(r.ok, isTrue);
      expect(r.items.single.stockQty, isNull);
    });

    test('columns can be in any order and extra columns are ignored', () {
      final r = read(
        'x,2.5,Gum,111,7\n',
        head: 'notes,price,item name,barcode,stock quantity',
      );
      expect(r.ok, isTrue);
      expect(r.items.single.barcode, '111');
      expect(r.items.single.name, 'Gum');
      expect(r.items.single.priceCents, 250);
      expect(r.items.single.stockQty, 7);
    });

    test('column names ignore case and extra spaces', () {
      final r = read(
        '111,Gum,2.5,3\n',
        head: ' Barcode , ITEM   NAME ,Price,Stock Quantity ',
      );
      expect(r.ok, isTrue);
    });

    test('values are trimmed', () {
      final r = read('  111 ,  Gum  , 2.5 , 3 \n');
      expect(r.items.single.barcode, '111');
      expect(r.items.single.name, 'Gum');
    });

    test('prices: plain, with ₱, and with thousands separators', () {
      final r = read('1,A,12.5,\n2,B,₱15,\n3,C,"1,234.50",\n4,D,0.05,\n');
      expect(r.items.map((i) => i.priceCents), [1250, 1500, 123450, 5]);
    });

    test('negative stock is refused', () {
      final r = read('1,A,1,-3\n');
      expect(r.ok, isFalse);
      expect(r.problems, ['Row 2: stock quantity "-3" cannot be below 0.']);
    });

    test('names with commas, quotes and line breaks', () {
      final r = read(
        '1,"Soap, 3-pack",1.5,\n'
        '2,"The ""big"" one\nline 2",2,\n',
      );
      expect(r.ok, isTrue);
      expect(r.items.map((i) => i.name), [
        'Soap, 3-pack',
        'The "big" one\nline 2',
      ]);
    });

    test('blank lines are skipped, including at the end', () {
      final r = read('\n111,Gum,2.5,\n\n\n');
      expect(r.ok, isTrue);
      expect(r.items, hasLength(1));
    });

    test('works with a BOM and Windows line endings', () {
      final r = parseItemsCsv(bytes('﻿$header\r\n111,Gum,2.5,3\r\n'));
      expect(r.ok, isTrue);
      expect(r.items.single.stockQty, 3);
    });
  });

  group('importing fails, and says why', () {
    void fails(
      String name,
      String body,
      List<String> problems, {
      String head = header,
    }) {
      test(name, () {
        final r = read(body, head: head);
        expect(r.ok, isFalse);
        expect(r.problems, problems);
        expect(r.items, isEmpty); // nothing usable comes out of a failed file
      });
    }

    fails('barcode is empty', ',Gum,2.5,3\n', ['Row 2: barcode is empty.']);
    fails('item name is empty', '111,,2.5,3\n', ['Row 2: item name is empty.']);
    fails('price is empty', '111,Gum,,3\n', ['Row 2: price is empty.']);

    fails('several empty cells in one row are reported together', ',,,5\n', [
      'Row 2: barcode is empty; item name is empty; price is empty.',
    ]);

    fails('a price that is not a number', '111,Gum,abc,\n', [
      'Row 2: price "abc" is not a valid amount (use a number like 12.50).',
    ]);
    fails(
      'a comma used as the decimal mark is not guessed',
      '111,Gum,"12,50",\n',
      ['Row 2: price "12,50" is not a valid amount (use a number like 12.50).'],
    );
    fails('a negative price', '111,Gum,-5,\n', [
      'Row 2: price "-5" is not a valid amount (use a number like 12.50).',
    ]);
    fails('a price of zero', '111,Gum,0,\n', [
      'Row 2: price must be greater than 0.',
    ]);
    fails('a price with more than two decimals', '111,Gum,1.234,\n', [
      'Row 2: price "1.234" is not a valid amount (use a number like 12.50).',
    ]);

    fails(
      'stock that is not a whole number',
      '111,Gum,2.5,lots\n222,Soda,3,12.5\n',
      [
        'Row 2: stock quantity "lots" is not a whole number.',
        'Row 3: stock quantity "12.5" is not a whole number.',
      ],
    );

    fails(
      'a barcode mangled into scientific notation',
      '4.80002E+12,Gum,2.5,\n',
      [
        'Row 2: barcode "4.80002E+12" looks like Excel scientific notation; '
            'format the barcode column as Text and export again.',
      ],
    );

    fails(
      'the same barcode twice',
      '111,Gum,2.5,\n222,Soda,3,\n111,Gum again,4,\n',
      ['Row 4: barcode "111" is already used on row 2.'],
    );

    fails(
      'every bad row is reported, not just the first',
      '111,Gum,2.5,\n,Soda,3,\n333,,4,\n444,Tea,,\n',
      [
        'Row 3: barcode is empty.',
        'Row 4: item name is empty.',
        'Row 5: price is empty.',
      ],
    );

    fails(
      'row numbers count blank lines, like a spreadsheet does',
      '\n\n111,,2.5,\n',
      ['Row 4: item name is empty.'],
    );

    fails(
      'one bad row fails the whole file even if the rest are fine',
      '111,Gum,2.5,\n222,Soda,3,\n333,Tea,,\n',
      ['Row 4: price is empty.'],
    );

    fails('the column names are missing', '111,2.5\n', [
      'The first row must be the column names. Missing: barcode, item name. '
          'Expected: barcode, item name, price, stock quantity.',
    ], head: 'name,price');

    fails(
      'a file saved with semicolons',
      '111;Gum;2.5;3\n',
      [
        'This file separates columns with semicolons. Save it as '
            'comma-separated CSV.',
      ],
      head: 'barcode;item name;price;stock quantity',
    );

    fails('only the column names', '', [
      'The file has no items, only the column names.',
    ]);

    test('an empty file', () {
      final r = parseItemsCsv(bytes(''));
      expect(r.problems, ['The file is empty.']);
    });

    test('a file that is not UTF-8 text', () {
      // "Piña" saved as Windows-1252: the ñ is the single byte 0xF1.
      final r = parseItemsCsv(
        Uint8List.fromList([
          ...utf8.encode('$header\n1,Pi'),
          0xF1,
          0x61,
          0x2C,
          0x31,
        ]),
      );
      expect(r.ok, isFalse);
      expect(r.problems.single, contains('not UTF-8'));
      expect(r.problems.single, contains('CSV UTF-8'));
    });

    test('a quote that is never closed', () {
      final r = parseItemsCsv(bytes('$header\n111,"Gum,2.5,3\n'));
      expect(r.ok, isFalse);
      expect(r.problems.single, contains('never closed'));
    });
  });

  group('exporting', () {
    const items = [
      Item(
        barcode: '4800016644290',
        name: 'Pancit Canton',
        priceCents: 1500,
        stockQty: 24,
      ),
      Item(barcode: '111', name: 'Gum', priceCents: 5, stockQty: 2),
    ];

    test('has the column names, one row per item, prices as 15.00', () {
      expect(
        itemsToCsv(items),
        '﻿$header\r\n'
        '4800016644290,Pancit Canton,15.00,24\r\n'
        '111,Gum,0.05,2\r\n',
      );
    });

    test('quotes names containing commas, quotes or line breaks', () {
      final csv = itemsToCsv(const [
        Item(barcode: '1', name: 'Soap, 3-pack', priceCents: 100),
        Item(barcode: '2', name: 'The "big" one', priceCents: 100),
        Item(barcode: '3', name: 'two\nlines', priceCents: 100),
      ]);
      expect(csv, contains('1,"Soap, 3-pack",1.00,0'));
      expect(csv, contains('2,"The ""big"" one",1.00,0'));
      expect(csv, contains('3,"two\nlines",1.00,0'));
    });

    test('no items is just the header', () {
      expect(itemsToCsv(const []), '﻿$header\r\n');
    });

    test('an exported file imports back to the same items', () {
      const original = [
        Item(
          barcode: '4800016644290',
          name: 'Piña colada, "special" ₱',
          priceCents: 123450,
          stockQty: 24,
        ),
        Item(
          barcode: 'ABC-123',
          name: 'two\nlines',
          priceCents: 1,
          stockQty: 3,
        ),
        Item(barcode: '007', name: 'Leading zeros', priceCents: 250),
      ];
      final back = parseItemsCsv(bytes(itemsToCsv(original)));

      expect(back.ok, isTrue);
      expect(back.items.map((i) => i.barcode), original.map((i) => i.barcode));
      expect(back.items.map((i) => i.name), original.map((i) => i.name));
      expect(
        back.items.map((i) => i.priceCents),
        original.map((i) => i.priceCents),
      );
      expect(
        back.items.map((i) => i.stockQty),
        original.map((i) => i.stockQty),
      );
    });
  });
}
