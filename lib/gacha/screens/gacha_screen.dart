import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_helper.dart';
import '../../services/supabase_ranking_service.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';
import '../models/gacha_rarity.dart';
import '../services/gacha_data_loader.dart';
import 'gacha_animation_screen.dart';
import 'multi_gacha_animation_screen.dart';
import '../models/gacha_item_with_new_status.dart'; // Import GachaItemWithNewStatus

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> {
  final _supabaseService = SupabaseRankingService();
  late Future<GachaInitData> _initFuture;

  String? _userId;
  int _userCoins = 0;
  int _gachaPoints = 0;
  int _userUltraRareTickets = 0; // New state variable
  bool _isPulling = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<GachaInitData> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId == null) {
      throw Exception('ユーザーIDが見つかりません。ランキングへの参加が必要です。');
    }

    final userProfile = await _supabaseService.getUser(_userId!);
    final config = await GachaDataLoader.loadConfig('assets/gacha/gacha_config.json');
    final items = await GachaDataLoader.loadItems('assets/gacha/gacha_items.json');

    // Attach rarity info to all items
    for (var item in items) {
      final rarity = config.rarities.firstWhere((r) => r.id == item.rarityId, orElse: () => config.rarities.first);
      item.setRarity(rarity);
    }

    if (mounted) {
      setState(() {
        _userCoins = userProfile?['sleep_coins'] ?? 0;
        _gachaPoints = userProfile?['gacha_points'] ?? 0;
        _userUltraRareTickets = userProfile?['ultra_rare_tickets'] ?? 0; // Fetch ultra rare tickets
      });
    }

    return GachaInitData(config: config, items: items);
  }

  Future<void> _pullGacha(GachaConfig config, List<GachaItem> allItems) async {
    if (_isPulling || _userId == null) return;

    setState(() => _isPulling = true);

    try {
      if (_userCoins < config.singlePullCost) {
        _showErrorDialog('スリープコインが足りません。');
        setState(() => _isPulling = false);
        return;
      }

      final randomItem = _performWeightedSelection(config, allItems);

      await _supabaseService.deductCoinsForGacha(_userId!, config.singlePullCost, 1);
      final bool isNew = await DatabaseHelper.instance.addUnlockedQuote(randomItem.id); // Capture isNew
      await DatabaseHelper.instance.addGachaPull(randomItem.id, randomItem.rarity.id);

      setState(() {
        _userCoins -= config.singlePullCost;
        _gachaPoints += 1;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GachaAnimationScreen(item: randomItem, isNew: isNew), // Pass isNew
        ),
      );

    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isPulling = false);
      }
    }
  }

  Future<void> _pullMultiGacha(GachaConfig config, List<GachaItem> allItems) async {
    if (_isPulling || _userId == null) return;

    setState(() => _isPulling = true);

    try {
      if (_userCoins < config.multiPullCost) {
        _showErrorDialog('スリープコインが足りません。');
        setState(() => _isPulling = false);
        return;
      }

      final List<GachaItemWithNewStatus> pulledItemsWithStatus = []; // New list
      for (int i = 0; i < config.multiPullCount; i++) {
        final GachaItem item = _performWeightedSelection(config, allItems);
        final bool isNew = await DatabaseHelper.instance.addUnlockedQuote(item.id); // Capture isNew
        await DatabaseHelper.instance.addGachaPull(item.id, item.rarity.id);
        pulledItemsWithStatus.add(GachaItemWithNewStatus(item: item, isNew: isNew)); // Add to new list
      }

      await _supabaseService.deductCoinsForGacha(_userId!, config.multiPullCost, config.multiPullCount);

      setState(() {
        _userCoins -= config.multiPullCost;
        _gachaPoints += config.multiPullCount;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MultiGachaAnimationScreen(
            itemsWithStatus: pulledItemsWithStatus, // Pass new list
            config: config,
          ),
        ),
      );

    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isPulling = false);
      }
    }
  }

  GachaItem _performWeightedSelection(GachaConfig config, List<GachaItem> allItems) {
    final randomValue = Random().nextDouble();
    double cumulativeProbability = 0.0;
    GachaRarity? selectedRarity;
    final sortedRarities = List<GachaRarity>.from(config.rarities)
      ..sort((a, b) => a.probability.compareTo(b.probability));

    for (final rarity in sortedRarities) {
      cumulativeProbability += rarity.probability;
      if (randomValue <= cumulativeProbability) {
        selectedRarity = rarity;
        break;
      }
    }
    selectedRarity ??= sortedRarities.last;

    final itemsInRarity = allItems.where((item) => item.rarityId == selectedRarity!.id).toList();
    if (itemsInRarity.isEmpty) {
      throw Exception('No items found for rarity: ${selectedRarity.id}');
    }
    final randomItem = itemsInRarity[Random().nextInt(itemsInRarity.length)];
    randomItem.setRarity(selectedRarity);
    return randomItem;
  }

  GachaItem _performUltraRareSelection(GachaConfig config, List<GachaItem> allItems) {
    final ultraRareRarities = config.rarities.where((r) => r.id == 'ultra_rare').toList(); // Changed line
    if (ultraRareRarities.isEmpty) {
      throw Exception('No ultra_rare rarities defined in config.'); // Updated error message
    }

    final List<GachaItem> eligibleItems = [];
    for (final rarity in ultraRareRarities) {
      eligibleItems.addAll(allItems.where((item) => item.rarityId == rarity.id));
    }

    if (eligibleItems.isEmpty) {
      throw Exception('No ultra_rare items found.'); // Updated error message
    }

    final randomItem = eligibleItems[Random().nextInt(eligibleItems.length)];
    // Attach the correct rarity for the selected item
    final selectedRarity = config.rarities.firstWhere((r) => r.id == randomItem.rarityId);
    randomItem.setRarity(selectedRarity);
    return randomItem;
  }

  Future<void> _pullUltraRareGacha(GachaConfig config, List<GachaItem> allItems) async {
    if (_isPulling || _userId == null) return;

    setState(() => _isPulling = true);

    try {
      if (_userUltraRareTickets < 1) {
        _showErrorDialog('超激レア確定ガチャチケットが足りません。');
        setState(() => _isPulling = false);
        return;
      }

      final guaranteedItem = _performUltraRareSelection(config, allItems);

      await _supabaseService.consumeUltraRareTicket(_userId!);
      final bool isNew = await DatabaseHelper.instance.addUnlockedQuote(guaranteedItem.id);
      await DatabaseHelper.instance.addGachaPull(guaranteedItem.id, guaranteedItem.rarity.id);

      setState(() {
        _userUltraRareTickets -= 1;
        _gachaPoints += 1; // Still award gacha points for a pull
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GachaAnimationScreen(item: guaranteedItem, isNew: isNew),
        ),
      );

    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isPulling = false);
      }
    }
  }

  void _showResultDialog(GachaItem item) {
    final rarity = item.rarity;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          rarity.name,
          style: TextStyle(color: rarity.color, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${item.text}"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('- ${item.author}', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message.replaceAll('Exception: ', '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GachaInitData>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'エラー: ${snapshot.error.toString().replaceAll('Exception: ', '')}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final gachaData = snapshot.data!;
        final config = gachaData.config;
        final items = gachaData.items;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          Text('$_userCoins C', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.pinkAccent, size: 24),
                          const SizedBox(width: 8),
                          Text('$_gachaPoints P', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Gacha Banner Image
              Image.asset('assets/images/gacha_banner.png', height: 200),
              const Spacer(),
              ElevatedButton(
                onPressed: _isPulling ? null : () => _pullGacha(config, items),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                child: _isPulling
                    ? const CircularProgressIndicator()
                    : Text('1回引く (${config.singlePullCost} C)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isPulling ? null : () => _pullMultiGacha(config, items),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isPulling
                    ? const CircularProgressIndicator()
                    : Text('${config.multiPullCount}回引く (${config.multiPullCost} C)'),
              ),
              if (_userUltraRareTickets > 0) ...[ // Conditionally display the button
                const SizedBox(height: 16), // Add spacing
                ElevatedButton(
                  onPressed: _isPulling ? null : () => _pullUltraRareGacha(config, items), // onPressed is already null if tickets < 1
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.yellow, // Distinct color for ticket pull
                    foregroundColor: Colors.black,
                  ),
                  child: _isPulling
                      ? const CircularProgressIndicator()
                      : Text('超激レア確定ガチャ (${_userUltraRareTickets}枚所持)'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class GachaInitData {
  final GachaConfig config;
  final List<GachaItem> items;

  GachaInitData({required this.config, required this.items});
}