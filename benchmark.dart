import 'dart:math';

// Mocking the data models for the benchmark
class MenuItemData {
  final String title;
  final String description;
  final String price;
  final String imageUrl;

  MenuItemData(this.title, this.description, this.price, this.imageUrl);
}

class ComboData {
  final String title;
  final String subtitle;
  final String price;
  final String originalPrice;
  final String imageUrl;
  final String badgeText;

  ComboData(this.title, this.subtitle, this.price, this.originalPrice, this.imageUrl, this.badgeText);
}

void main() {
  final random = Random(42);

  MenuItemData todaySpecial = MenuItemData(
      'Special Thali', 'Desc', '₹150', 'url'
  );

  List<ComboData> combos = List.generate(3, (index) => ComboData(
      'Combo $index', 'Desc', '₹${200 + index * 10}', '₹${450}', 'url', 'Badge'
  ));

  List<MenuItemData> menuItems = List.generate(5, (index) => MenuItemData(
      'Item $index', 'Desc', '₹${80 + index * 10}', 'url'
  ));

  Map<String, int> cartQuantities = {
    'Special Thali': 2,
    'Combo 1': 1,
    'Item 3': 4,
    'NonExistent': 1,
  };

  int baselineCartTotal() {
    int total = 0;
    cartQuantities.forEach((name, qty) {
      if (qty > 0) {
        // Find price for item name (Simplified lookup)
        int price = 0;
        if (todaySpecial.title == name) {
           price = int.tryParse(todaySpecial.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        } else {
           // check combos
           final combo = combos.firstWhere((c) => c.title == name, orElse: () => ComboData('', '', '0', '', '', ''));
           if (combo.title.isNotEmpty) {
             price = int.tryParse(combo.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
           } else {
             // check menu
             final item = menuItems.firstWhere((i) => i.title == name, orElse: () => MenuItemData('', '', '0', ''));
             if (item.title.isNotEmpty) {
                price = int.tryParse(item.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
             }
           }
        }
        total += price * qty;
      }
    });
    return total;
  }

  // Measure baseline
  final stopwatchBaseline = Stopwatch()..start();
  int bTotal = 0;
  for (int i = 0; i < 100000; i++) {
    bTotal += baselineCartTotal();
  }
  stopwatchBaseline.stop();
  print('Baseline 100k iterations: ${stopwatchBaseline.elapsedMilliseconds} ms. Total: $bTotal');

  // Optimized approach
  final RegExp priceRegex = RegExp(r'[^0-9]');
  Map<String, int> itemPricesCache = {};
  void updateItemPricesCache() {
    itemPricesCache.clear();
    itemPricesCache[todaySpecial.title] = int.tryParse(todaySpecial.price.replaceAll(priceRegex, '')) ?? 0;
    for (var c in combos) {
      itemPricesCache[c.title] = int.tryParse(c.price.replaceAll(priceRegex, '')) ?? 0;
    }
    for (var m in menuItems) {
      itemPricesCache[m.title] = int.tryParse(m.price.replaceAll(priceRegex, '')) ?? 0;
    }
  }

  int optimizedCartTotal() {
    int total = 0;
    cartQuantities.forEach((name, qty) {
      if (qty > 0) {
        total += (itemPricesCache[name] ?? 0) * qty;
      }
    });
    return total;
  }

  // Ensure cache is updated
  updateItemPricesCache();

  final stopwatchOptimized = Stopwatch()..start();
  int oTotal = 0;
  for (int i = 0; i < 100000; i++) {
    oTotal += optimizedCartTotal();
  }
  stopwatchOptimized.stop();
  print('Optimized 100k iterations: ${stopwatchOptimized.elapsedMilliseconds} ms. Total: $oTotal');
}
