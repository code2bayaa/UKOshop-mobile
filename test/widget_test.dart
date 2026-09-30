/// What the shop app is checked on without a server.
///
/// Same principle as the three partner suites. For the shop the load-bearing logic is narrower than it
/// looks, and it is all about **trust and money**: whether an item can be bought through UKO at all,
/// which code a buyer must read out and to whom, and never showing a total that later grows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uko_core/uko_core.dart';

import 'package:uko_shop/src/models.dart';

void main() {
  group('what may be bought through UKO', () {
    ItemDetail detail(Map<String, dynamic> j) => ItemDetail.fromJson({'id': 1, ...j});

    // The API refuses an unverified item with "order from the seller directly instead". If the app
    // disagreed it would offer a button that always fails, on the one screen where trust is the
    // entire proposition.
    test('an item on a shelf can go in a basket', () {
      final d = detail({'is_verified': true, 'stock': 3, 'status': 'live'});
      expect(d.canAddToCart, isTrue);
      expect(d.card.trust, startsWith('Verified'));
    });

    test('an item not on a shelf cannot, and says so rather than badging nothing', () {
      final d = detail({'is_verified': false, 'stock': 3, 'status': 'live'});
      expect(d.canAddToCart, isFalse);
      expect(d.card.trust, 'Direct from the seller');
    });

    test('a sold-out item cannot, however verified', () {
      expect(detail({'is_verified': true, 'stock': 0, 'status': 'sold_out'}).canAddToCart, isFalse);
    });

    test('variants make choosing compulsory, as the API does', () {
      final plain = detail({'is_verified': true, 'stock': 1});
      final withVariants = detail({
        'is_verified': true,
        'stock': 1,
        'variants': [
          {'id': 1, 'label': 'Black', 'stock': 1, 'amount': 100}
        ],
      });
      expect(plain.mustChoose, isFalse);
      expect(withVariants.mustChoose, isTrue);
    });
  });

  group('shapes the API really sends', () {
    // `items.features` is rich-text HTML, not a list — the web app edits it in a rich-text field. A
    // bare `as List` cast threw, and the item screen span forever behind a perfectly good 200.
    test('HTML feature bullets become a list', () {
      final d = ItemDetail.fromJson({
        'id': 1,
        'features': '<ul><li>Checked by the shelf attendant</li><li>Escrow protected</li></ul>',
      });
      expect(d.features, ['Checked by the shelf attendant', 'Escrow protected']);
    });

    test('a plain paragraph is kept rather than dropped', () {
      final d = ItemDetail.fromJson({'id': 1, 'features': '<p>Comes with the original box.</p>'});
      expect(d.features, ['Comes with the original box.']);
    });

    test('an actual list still works', () {
      expect(ItemDetail.fromJson({'id': 1, 'features': ['A', 'B']}).features, ['A', 'B']);
    });

    test('no features is no bullets, not a crash', () {
      expect(ItemDetail.fromJson({'id': 1}).features, isEmpty);
      expect(ItemDetail.fromJson({'id': 1, 'features': ''}).features, isEmpty);
    });

    // Variants carry type/colour/size and no composed label.
    test('a variant labels itself from its parts', () {
      final v = Variant.fromJson(
          {'id': 1, 'type': 'Dual SIM', 'color': 'Blue', 'size': '128GB', 'amount': 18900});
      expect(v.label, 'Dual SIM · Blue · 128GB');
    });

    test('a variant with only a colour says just that', () {
      expect(Variant.fromJson({'id': 1, 'color': 'Black'}).label, 'Black');
    });
  });

  group('the price a buyer sees', () {
    ItemCard card(Map<String, dynamic> j) => ItemCard.fromJson({'id': 1, ...j});

    test('a range when variants differ, one figure when they do not', () {
      // The currency once, as the wireframe's card does it — repeating it truncates in the grid.
      expect(card({'min_amount': 1850, 'max_amount': 2400}).price, 'KSh 1,850 – 2,400');
      expect(card({'min_amount': 1850, 'max_amount': 1850}).price, 'KSh 1,850');
    });

    test('a discount is only claimed when the was-price is really higher', () {
      expect(card({'min_amount': 800, 'old_amount': 1000}).discountPct, 20);
      expect(card({'min_amount': 1000, 'old_amount': 1000}).discountPct, isNull);
      expect(card({'min_amount': 1200, 'old_amount': 1000}).discountPct, isNull);
      expect(card({'min_amount': 800}).discountPct, isNull);
    });
  });

  group('the basket', () {
    Cart cartOf(List<Map<String, dynamic>> lines, {Map<String, dynamic> summary = const {}}) =>
        Cart.fromJson({'items': lines, 'summary': summary, 'notices': const []});

    test('saved-for-later lines are not in the basket', () {
      final c = cartOf([
        {'id': 1, 'item': {'id': 1}, 'quantity': 1, 'saved_for_later': false},
        {'id': 2, 'item': {'id': 2}, 'quantity': 1, 'saved_for_later': true},
      ]);
      expect(c.lines.length, 2);
      expect(c.active.length, 1);
      expect(c.saved.length, 1);
      expect(c.isEmpty, isFalse);
    });

    test('a basket of only saved items is empty for checkout', () {
      final c = cartOf([
        {'id': 1, 'item': {'id': 1}, 'quantity': 1, 'saved_for_later': true},
      ]);
      expect(c.isEmpty, isTrue);
    });

    // The number that decides what receiving the basket costs, and the reason the delivery options
    // exist at all.
    test('several shelves is the interesting case', () {
      expect(cartOf(const [], summary: {'shelves': 1}).multiShelf, isFalse);
      expect(cartOf(const [], summary: {'shelves': 3}).multiShelf, isTrue);
    });

    test('the server\'s own sentences about changes are kept verbatim', () {
      final c = Cart.fromJson({
        'items': const [],
        'summary': const {},
        'notices': ['Ankara maxi dress dropped to 2 units at Kilimani Shelf 01.'],
      });
      expect(c.notices.single, contains('dropped to 2 units'));
    });
  });

  group('which code the buyer reads out', () {
    Order order(String option, {String shelve = '3757', String rider = '8436'}) =>
        Order.fromJson({
          'id': 1,
          'delivery_option': option,
          'shelve_code': shelve,
          'rider_code': rider,
        });

    // He is the one taking the goods, so for once the code is his to give — but which one depends on
    // who is handing them over. Showing the wrong one sends him to a counter reading a rider's code.
    test('collecting at a shelf needs the shelf code', () {
      expect(order('pickup').codeToGive, '3757');
      expect(order('shelf_run').codeToGive, '3757');
      expect(order('pickup').codeLabel, contains('shelf'));
    });

    test('a run to the door needs the rider code', () {
      expect(order('rider').codeToGive, '8436');
      expect(order('taxi').codeToGive, '8436');
      expect(order('rider').codeLabel, contains('rider'));
    });
  });

  group('order state', () {
    Order of(Map<String, dynamic> j) => Order.fromJson({'id': 1, ...j});

    test('unpaid is a state the buyer must be able to see', () {
      expect(of({'payment_status': 'unpaid'}).unpaid, isTrue);
      expect(of({'payment_status': 'unpaid'}).paid, isFalse);
    });

    test('released still counts as paid — the money simply moved on', () {
      expect(of({'payment_status': 'released'}).paid, isTrue);
    });

    test('ready and shipped are the two states with something to do', () {
      expect(of({'status': 'ready'}).readyToCollect, isTrue);
      expect(of({'status': 'shipped'}).onTheWay, isTrue);
      expect(of({'status': 'processing'}).readyToCollect, isFalse);
    });

    test('where it is going reads as a sentence, not a key', () {
      expect(of({'delivery_option': 'pickup'}).where, 'Collect at each shelf');
      expect(of({'delivery_option': 'rider'}).where, 'To your door');
    });
  });

  group('delivery options', () {
    test('only the door options need an address, which is what checkout gates on', () {
      DeliveryOption of(String key) => DeliveryOption.fromJson({'key': key});
      expect(of('rider').toDoor, isTrue);
      expect(of('taxi').toDoor, isTrue);
      expect(of('pickup').toDoor, isFalse);
      expect(of('shelf_run').toDoor, isFalse);
    });

    // A count rather than a list is an older server shape; a bare cast on it throws.
    test('a leg count sent as a number is read, not thrown on', () {
      final o = CheckoutOptions.fromJson({
        'shelves': const [],
        'delivery_options': const [],
        'courier': {'fee': 1560, 'legs': 1},
      });
      expect(o.hasCourier, isTrue);
      expect(o.courierFee, 1560);
    });

    // `legs` is a list of journeys, not a count, and `required` is the server's own answer. Reading
    // it as an int gave 0 and left `hasCourier` driven only by a fee that can legitimately be zero.
    test('legs is a list, and required is what really decides', () {
      final o = CheckoutOptions.fromJson({
        'shelves': const [],
        'delivery_options': const [],
        'courier': {
          'fee': 0,
          'required': true,
          'legs': [
            {'from': 'Mombasa', 'to': 'Nairobi'}
          ],
        },
      });
      expect(o.courierLegs, 1);
      expect(o.courierRequired, isTrue);
      expect(o.hasCourier, isTrue);
    });

    test('no courier is the ordinary case', () {
      expect(
        CheckoutOptions.fromJson({
          'shelves': const [],
          'delivery_options': const [],
          'courier': {'fee': 0.0, 'required': false, 'legs': const []},
        }).hasCourier,
        isFalse,
      );
    });
  });

  group('money, as a buyer is shown it', () {
    test('matches the web app\'s thousand separators', () {
      expect(ksh(9420), 'KSh 9,420');
    });

    test('a bare server timestamp is read as UTC, not local time', () {
      final now = DateTime.now().toUtc();
      final parsed = asDate(now.toIso8601String().replaceAll('Z', ''))!;
      expect(now.difference(parsed.toUtc()).inMinutes.abs(), lessThan(1));
    });
  });
}
