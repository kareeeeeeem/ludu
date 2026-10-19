import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/custom_dice.dart';
import '../game/premium_board.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.api});
  final Api api;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> catalog = [];
  bool loading = true;
  String? error;
  final Map<String, String> pendingPurchases = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final res = await widget.api.call('/shop/catalog');
      if (mounted) {
        setState(() {
          catalog = res['catalog'] as List;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _buyItem(String itemId, int price) async {
    final pending = pendingPurchases[itemId];
    if (pending != null) {
      try {
        final status = await widget.api.call('/shop/purchases/$pending/status');
        if (status['status'] == 'COMMITTED') {
          pendingPurchases.remove(itemId);
          await widget.api.refresh();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            status['status'] == 'COMMITTED' ? 'Cosmetic unlocked!' : 'Purchase is pending platform confirmation.')));
          setState(() {});
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Unlock cosmetic?'),
      content: Text(price == 0 ? 'Unlock this free cosmetic?' : 'Spend $price platform points on this cosmetic?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlock'))],
    ));
    if (approved != true) return;
    final requestId = const Uuid().v4();
    try {
      final result = await widget.api.call('/shop/buy', method: 'POST', body: {'itemId': itemId, 'requestId': requestId});
      if (result is Map && result['status'] == 'PENDING') {
        pendingPurchases[itemId] = requestId;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase pending platform confirmation. Tap again to check.')));
          setState(() {});
        }
        return;
      }
      await widget.api.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cosmetic item unlocked successfully!')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _equipItem(String category, String itemId) async {
    try {
      await widget.api.call(
        '/inventory/equip',
        method: 'POST',
        body: {'category': category, 'itemId': itemId},
      );
      await widget.api.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cosmetic equipped!')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.api.user ?? {};
    final points = user['points'];
    final inventory = (user['inventory'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final equipped = (user['equipped'] as Map?)?.cast<String, String>() ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('SHOP'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.emerald),
            ),
            child: Row(
              children: [
                const Text('🪙 ', style: TextStyle(fontSize: 14)),
                Text(
                  points is int ? '$points Points' : 'Points unavailable',
                  style: const TextStyle(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.mutedInk,
          tabs: const [
            Tab(text: 'DICE'),
            Tab(text: 'TOKENS'),
            Tab(text: 'BOARDS'),
            Tab(text: 'FRAMES'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCategoryGrid('dice', catalog, inventory, equipped),
                    _buildCategoryGrid('token', catalog, inventory, equipped),
                    _buildCategoryGrid('board', catalog, inventory, equipped),
                    _buildCategoryGrid('frame', catalog, inventory, equipped),
                  ],
                ),
    );
  }

  Widget _buildCategoryGrid(
    String category,
    List<dynamic> items,
    List<String> inventory,
    Map<String, String> equipped,
  ) {
    final categoryItems = items.where((i) => i['category'] == category).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 250,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: categoryItems.length,
      itemBuilder: (context, index) {
        final item = categoryItems[index];
        final itemId = item['id'] as String;
        final name = item['name'] as String;
        final rarity = item['rarity'] as String;
        final price = item['pricePoints'] as int?;
        final available = item['available'] != false;
        final isOwned = inventory.contains(itemId);
        final isEquipped = equipped[category] == itemId;

        Color rarityColor;
        switch (rarity) {
          case 'Legendary':
            rarityColor = AppColors.gold;
            break;
          case 'Epic':
            rarityColor = AppColors.violet;
            break;
          case 'Rare':
            rarityColor = AppColors.emerald;
            break;
          default:
            rarityColor = AppColors.mutedInk;
        }

        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rarity,
                      style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isEquipped)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'EQUIPPED',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(width: 65, height: 65, child: switch (category) {
                'dice' => Center(child: AnimatedDice(value: 5, size: 50, diceTheme: itemId)),
                'token' => TokenWidget(colorKey: 'red', tokenNumber: 1, styleTheme: itemId),
                'board' => PremiumBoard(state: const {'turn': 0, 'players': []}, boardTheme: itemId),
                _ => Icon(Icons.filter_vintage_rounded, size: 48, color: rarityColor),
              }),
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (isOwned)
                ElevatedButton(
                  onPressed: isEquipped ? null : () => _equipItem(category, itemId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped ? Colors.white12 : AppColors.emerald,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isEquipped ? 'EQUIPPED' : 'EQUIP'),
                )
              else if (price != null && available)
                ElevatedButton.icon(
                  onPressed: () => _buyItem(itemId, price),
                  icon: const Icon(Icons.stars_rounded, size: 15),
                  label: Text(pendingPurchases.containsKey(itemId) ? 'CHECK STATUS' : price == 0 ? 'FREE' : '$price POINTS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else Text(available ? 'COMING SOON' : 'UNAVAILABLE', style: const TextStyle(color: AppColors.mutedInk, fontWeight: FontWeight.w900, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}
