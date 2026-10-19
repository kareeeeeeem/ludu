import 'package:flutter/material.dart';
import '../api.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) {
    final user = api.user ?? {};
    final inventory = (user['inventory'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final equipped = (user['equipped'] as Map?)?.cast<String, String>() ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('INVENTORY'),
      ),
      body: inventory.isEmpty
          ? const Center(child: Text('No cosmetic items owned yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'EQUIPPED COSMETICS',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    children: [
                      _equippedRow('Dice', equipped['dice'] ?? 'dice_classic'),
                      const Divider(color: AppColors.glassBorder),
                      _equippedRow('Tokens', equipped['token'] ?? 'token_classic'),
                      const Divider(color: AppColors.glassBorder),
                      _equippedRow('Board Theme', equipped['board'] ?? 'board_classic'),
                      const Divider(color: AppColors.glassBorder),
                      _equippedRow('Avatar Frame', equipped['frame'] ?? 'frame_bronze'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ALL OWNED ITEMS',
                  style: TextStyle(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: inventory.map((item) {
                    return Chip(
                      avatar: const Icon(Icons.check_circle, color: AppColors.emerald, size: 16),
                      label: Text(item.replaceAll('_', ' ').toUpperCase()),
                      backgroundColor: AppColors.surfaceDark,
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _equippedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedInk)),
          Text(
            value.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
