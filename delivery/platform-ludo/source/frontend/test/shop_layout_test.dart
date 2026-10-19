import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/shop/shop_screen.dart';

class _CatalogApi extends Api {
  @override
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (path == '/shop/catalog') {
      return {
        'catalog': [
          {
            'id': 'dice_classic',
            'name': 'Classic Dice',
            'category': 'dice',
            'rarity': 'Common',
            'pricePoints': 0,
            'available': true,
          },
          {
            'id': 'dice_gold',
            'name': 'Gold Dice',
            'category': 'dice',
            'rarity': 'Rare',
            'pricePoints': 75,
            'available': true,
          },
        ],
      };
    }
    throw StateError('Unexpected $path');
  }
}

void main() {
  testWidgets('shop cards fit a narrow phone and retain purchase control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api =
        _CatalogApi()
          ..user = {
            'id': 'qa',
            'points': 175,
            'inventory': ['dice_classic'],
            'equipped': <String, String>{'dice': 'dice_classic'},
          };
    await tester.pumpWidget(MaterialApp(home: ShopScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('75 POINTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });
}
