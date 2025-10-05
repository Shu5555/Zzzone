import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_management_app/services/supabase_ranking_service.dart';
import '../gacha/screens/gacha_history_screen.dart';
import '../gacha/screens/gacha_screen.dart';
import '../models/shop_item.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseRankingService();
  late Future<Map<String, dynamic>> _shopDataFuture;
  String? _userId;
  late TabController _tabController;

  int _userCoins = 0;

  @override
  void initState() {
    super.initState();
    // Change length to 2 for two tabs
    _tabController = TabController(length: 2, vsync: this);
    _shopDataFuture = _loadShopData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // This method now primarily serves the Background Shop tab.
  // The Gacha tab will manage its own state.
  Future<Map<String, dynamic>> _loadShopData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    if (_userId == null) {
      throw Exception('ランキングに参加してユーザーIDを有効にしてください。');
    }
    
    final userProfile = await _supabaseService.getUser(_userId!);
    final unlockedItems = await _supabaseService.getUnlockedBackgrounds(_userId!);
    
    if (mounted) {
      setState(() {
        _userCoins = userProfile?['sleep_coins'] ?? 0;
      });
    }
    
    return {
      'unlocked': unlockedItems,
    };
  }

  Future<void> _executePurchase(ShopItem item) async {
    if (_userId == null) return;

    if (_userCoins < item.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スリープコインが足りません。'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await _supabaseService.purchaseBackground(userId: _userId!, backgroundId: item.id, cost: item.cost);
      
      // Manually update coin count after purchase
      setState(() {
        _userCoins -= item.cost;
        // Refresh background shop data
        _shopDataFuture = _loadShopData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name}を購入しました！')),
      );

    } on Exception catch (e) {
      final message = e.toString();
      String displayMessage = '購入に失敗しました。';
      if (message.contains('insufficient_funds')) {
        displayMessage = 'スリープコインが足りません。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showConfirmationDialog(ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Text('${item.cost} C でこの背景を購入しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('購入する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executePurchase(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ショップ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ガチャ履歴',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GachaHistoryScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: const Icon(Icons.monetization_on, color: Colors.amber),
              label: Text('$_userCoins C'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '背景色'),
            Tab(text: 'ガチャ'), // Add Gacha tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Background Shop
          _buildBackgroundShop(),
          // Tab 2: Gacha
          const GachaScreen(),
        ],
      ),
    );
  }

  // Extracted the background shop UI into its own method for clarity
  Widget _buildBackgroundShop() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _shopDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('エラー: ${snapshot.error.toString().replaceFirst('Exception: ', '')}', textAlign: TextAlign.center),
            )
          );
        }

        final unlockedIds = snapshot.data?['unlocked'] as List<String>? ?? [];

        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 3 / 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: backgroundShopCatalog.length,
          itemBuilder: (context, index) {
            final item = backgroundShopCatalog[index];
            final isUnlocked = unlockedIds.contains(item.id);

            return Card(
              elevation: 2.0,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(color: item.previewColor),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(item.name, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                          Text('${item.cost} C', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: isUnlocked
                        ? const Chip(label: Text('購入済み'), avatar: Icon(Icons.check, color: Colors.green), visualDensity: VisualDensity.compact)
                        : ElevatedButton(
                            onPressed: () => _showConfirmationDialog(item),
                            child: const Text('購入'),
                            style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
