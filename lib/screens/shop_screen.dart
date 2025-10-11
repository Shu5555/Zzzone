import 'package:flutter/foundation.dart';
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
  int _userGachaPoints = 0; // New state variable
  int _userUltraRareTickets = 0; // New state variable

  @override
  void initState() {
    super.initState();
    // Change length to 3 for three tabs
    _tabController = TabController(length: 3, vsync: this); // Changed from 2 to 3
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

    // WebではuserIdがなくてもエラーにしない
    if (_userId == null && !kIsWeb) {
      throw Exception('ランキングに参加してユーザーIDを有効にしてください。');
    }

    List<String> unlockedItems = [];
    if (kIsWeb) {
      // Web: SharedPreferencesからデータを読み込む
      if (mounted) {
        setState(() {
          _userCoins = prefs.getInt('sleep_coins') ?? 0;
          _userGachaPoints = prefs.getInt('gacha_points') ?? 0;
          _userUltraRareTickets = prefs.getInt('ultra_rare_tickets') ?? 0;
        });
      }
      unlockedItems = prefs.getStringList('unlocked_backgrounds') ?? [];
    } else {
      // Mobile: Supabaseからデータを読み込む
      if (_userId == null) {
        throw Exception('ランキングに参加してユーザーIDを有効にしてください。');
      }
      final userProfile = await _supabaseService.getUser(_userId!);
      unlockedItems = await _supabaseService.getUnlockedBackgrounds(_userId!);
      
      if (mounted) {
        setState(() {
          _userCoins = userProfile?['sleep_coins'] ?? 0;
          _userGachaPoints = userProfile?['gacha_points'] ?? 0;
          _userUltraRareTickets = userProfile?['ultra_rare_tickets'] ?? 0;
        });
      }
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

  Future<void> _executeTicketPurchase({required String ticketId, required int cost}) async {
    if (_userId == null && !kIsWeb) return;

    if (_userGachaPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ガチャポイントが足りません。'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (kIsWeb) {
        // Web: SharedPreferencesを更新
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('gacha_points', _userGachaPoints - cost);
        await prefs.setInt('ultra_rare_tickets', _userUltraRareTickets + 1);
      } else {
        // Mobile: Supabaseを更新
        await _supabaseService.purchaseGachaTicket(userId: _userId!, cost: cost, ticketType: ticketId);
      }
      
      setState(() {
        _userGachaPoints -= cost;
        _userUltraRareTickets += 1; // Assuming only one type of ticket for now
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('超激レア確定ガチャチケットを購入しました！')),
      );

    } on Exception catch (e) {
      final message = e.toString();
      String displayMessage = '購入に失敗しました。';
      if (message.contains('insufficient_gacha_points')) {
        displayMessage = 'ガチャポイントが足りません。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showTicketConfirmationDialog({required String ticketId, required String ticketName, required int cost}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticketName),
        content: Text('$cost P でこのチケットを購入しますか？'),
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
      await _executeTicketPurchase(ticketId: ticketId, cost: cost);
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
          // Display Gacha Points
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: const Icon(Icons.star, color: Colors.pinkAccent),
              label: Text('$_userGachaPoints P'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '背景色'),
            Tab(text: 'ガチャ'),
            Tab(text: 'ガチャポイント'), // New tab
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
          // Tab 3: Gacha Points Shop
          _buildGachaPointShop(), // New method
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

  Widget _buildGachaPointShop() {
    const ticketCost = 100; // Changed from 500 to 100
    const ticketId = 'ultra_rare_guaranteed_ticket';
    const ticketName = '超激レア確定ガチャチケット';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2.0,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.confirmation_number, size: 40, color: Colors.yellow), // Changed color
                  title: const Text(ticketName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('$ticketCost P で購入'), // Cost display
                  trailing: Text('所持数: $_userUltraRareTickets'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _userGachaPoints >= ticketCost
                        ? () => _showTicketConfirmationDialog(ticketId: ticketId, ticketName: ticketName, cost: ticketCost)
                        : null,
                    child: const Text('購入'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40), // Make button full width
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ガチャポイントはガチャを引くことで獲得できます。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
