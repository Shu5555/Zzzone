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
import 'gacha_history_screen.dart';
import 'multi_gacha_animation_screen.dart';
import 'gacha_sequence_controller.dart';
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
  int _userUltraRareTickets = 0;
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
    final config = await GachaDataLoader.loadConfig(
      'assets/gacha/gacha_config.json',
    );
    final items = await GachaDataLoader.loadItems(
      'assets/gacha/gacha_items.json',
    );

    for (var item in items) {
      final rarity = config.rarities.firstWhere(
        (r) => r.id == item.rarityId,
        orElse: () => config.rarities.first,
      );
      item.setRarity(rarity);
    }

    if (mounted) {
      setState(() {
        _userCoins = userProfile?['sleep_coins'] ?? 0;
        _gachaPoints = userProfile?['gacha_points'] ?? 0;
        _userUltraRareTickets = userProfile?['ultra_rare_tickets'] ?? 0;
      });
    }

    return GachaInitData(config: config, items: items);
  }

  GachaItem _performWeightedSelection(
    GachaConfig config,
    List<GachaItem> allItems,
  ) {
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

    final itemsInRarity = allItems
        .where((item) => item.rarityId == selectedRarity!.id)
        .toList();
    if (itemsInRarity.isEmpty) {
      final lowestRarity = sortedRarities.first;
      final fallbackItems = allItems
          .where((item) => item.rarityId == lowestRarity.id)
          .toList();
      if (fallbackItems.isEmpty)
        throw Exception('No items found for any rarity.');
      final randomItem = fallbackItems[Random().nextInt(fallbackItems.length)];
      randomItem.setRarity(lowestRarity);
      return randomItem;
    }
    final randomItem = itemsInRarity[Random().nextInt(itemsInRarity.length)];
    randomItem.setRarity(selectedRarity);
    return randomItem;
  }

  List<GachaItem> _performPromotionDraw(
    GachaItem initialItem,
    GachaConfig config,
    List<GachaItem> allItems,
  ) {
    final List<GachaItem> promotionPath = [initialItem];
    GachaItem currentItem = initialItem;

    while (true) {
      final random = Random().nextDouble();
      String? nextRarityId;
      double promotionChance = 0.0;

      // DEBUG: Temporarily increased promotion rates
      switch (currentItem.rarity.id) {
        case 'common':
          promotionChance = 0.5; // 50%
          nextRarityId = 'rare';
          break;
        case 'rare':
          promotionChance = 0.5; // 50%
          nextRarityId = 'super_rare';
          break;
        case 'super_rare':
          promotionChance = 0.5; // 50%
          nextRarityId = 'ultra_rare';
          break;
        case 'ultra_rare':
          promotionChance = 0.5; // 50%
          nextRarityId = 'own_chin';
          break;
        default:
          return promotionPath;
      }

      if (random < promotionChance) {
        final promotedItems = allItems
            .where((item) => item.rarityId == nextRarityId)
            .toList();
        if (promotedItems.isNotEmpty) {
          currentItem = promotedItems[Random().nextInt(promotedItems.length)];
          currentItem.setRarity(
            config.rarities.firstWhere((r) => r.id == nextRarityId),
          );
          promotionPath.add(currentItem);
        } else {
          return promotionPath;
        }
      } else {
        return promotionPath;
      }
    }
  }

  Future<void> _pullGacha(GachaConfig config, List<GachaItem> allItems) async {
    if (_isPulling || _userId == null) return;
    setState(() => _isPulling = true);

    try {
      if (_userCoins < config.singlePullCost) {
        _showErrorDialog('スリープコインが足りません。');
        return;
      }

      final initialItem = _performWeightedSelection(config, allItems);
      final promotionPath = _performPromotionDraw(
        initialItem,
        config,
        allItems,
      );
      final finalItem = promotionPath.last;

      await _supabaseService.deductCoinsForGacha(
        _userId!,
        config.singlePullCost,
        1,
      );
      final bool isNew = await DatabaseHelper.instance.addUnlockedQuote(
        finalItem.id,
      );
      await DatabaseHelper.instance.addGachaPull(
        finalItem.id,
        finalItem.rarity.id,
      );

      setState(() {
        _userCoins -= config.singlePullCost;
        _gachaPoints += 1;
      });

      final itemWithStatus = GachaItemWithNewStatus(
        promotionPath: promotionPath,
        isNew: isNew,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GachaSequenceController(
            itemsWithStatus: [itemWithStatus],
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

  Future<void> _pullMultiGacha(
    GachaConfig config,
    List<GachaItem> allItems,
  ) async {
    if (_isPulling || _userId == null) return;
    setState(() => _isPulling = true);

    try {
      if (_userCoins < config.multiPullCost) {
        _showErrorDialog('スリープコインが足りません。');
        return;
      }

      int promotionCount = 0;
      const maxPromotions = 3;
      final List<GachaItemWithNewStatus> pulledItemsWithStatus = [];

      for (int i = 0; i < config.multiPullCount; i++) {
        final initialItem = _performWeightedSelection(config, allItems);
        List<GachaItem> promotionPath = [initialItem];

        if (promotionCount < maxPromotions) {
          final path = _performPromotionDraw(initialItem, config, allItems);
          if (path.length > 1) {
            promotionCount++;
          }
          promotionPath = path;
        }

        final finalItem = promotionPath.last;
        final bool isNew = await DatabaseHelper.instance.addUnlockedQuote(
          finalItem.id,
        );
        await DatabaseHelper.instance.addGachaPull(
          finalItem.id,
          finalItem.rarity.id,
        );
        pulledItemsWithStatus.add(
          GachaItemWithNewStatus(promotionPath: promotionPath, isNew: isNew),
        );
      }

      await _supabaseService.deductCoinsForGacha(
        _userId!,
        config.multiPullCost,
        config.multiPullCount,
      );

      setState(() {
        _userCoins -= config.multiPullCost;
        _gachaPoints += config.multiPullCount;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GachaSequenceController(
            itemsWithStatus: pulledItemsWithStatus,
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

  GachaItem _performUltraRareSelection(
    GachaConfig config,
    List<GachaItem> allItems,
  ) {
    final ultraRareRarities = config.rarities
        .where((r) => r.id == 'ultra_rare')
        .toList();
    if (ultraRareRarities.isEmpty) {
      throw Exception('No ultra_rare rarities defined in config.');
    }

    final List<GachaItem> eligibleItems = [];
    for (final rarity in ultraRareRarities) {
      eligibleItems.addAll(
        allItems.where((item) => item.rarityId == rarity.id),
      );
    }

    if (eligibleItems.isEmpty) {
      throw Exception('No ultra_rare items found.');
    }

    final randomItem = eligibleItems[Random().nextInt(eligibleItems.length)];
    final selectedRarity = config.rarities.firstWhere(
      (r) => r.id == randomItem.rarityId,
    );
    randomItem.setRarity(selectedRarity);
    return randomItem;
  }

  Future<void> _pullUltraRareGacha(
    GachaConfig config,
    List<GachaItem> allItems,
  ) async {
    if (_isPulling || _userId == null) return;

    setState(() => _isPulling = true);

    try {
      if (_userUltraRareTickets < 1) {
        _showErrorDialog('超激レア確定ガチャチケットが足りません。');
        return;
      }

      final initialItem = _performUltraRareSelection(config, allItems);
      final promotionPath = [initialItem]; // No promotion for ticket gacha

      await _supabaseService.consumeUltraRareTicket(_userId!);
      final bool isNew = await DatabaseHelper.instance.addUnlockedQuote(
        promotionPath.last.id,
      );
      await DatabaseHelper.instance.addGachaPull(
        promotionPath.last.id,
        promotionPath.last.rarity.id,
      );

      setState(() {
        _userUltraRareTickets -= 1;
        _gachaPoints += 1;
      });

      final itemWithStatus = GachaItemWithNewStatus(
        promotionPath: promotionPath,
        isNew: isNew,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GachaSequenceController(
            itemsWithStatus: [itemWithStatus],
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

  Future<void> _showGachaProbabilities(
    BuildContext context,
    GachaConfig config,
  ) async {
    try {
      // Sort rarities by order for display
      final sortedRarities = List.from(config.rarities)
        ..sort((a, b) => b.order.compareTo(a.order));

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('ガチャ排出確率'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sortedRarities.map((rarity) {
                  final probabilityPercent = (rarity.probability * 100)
                      .toStringAsFixed(2);
                  return ListTile(
                    leading: Icon(Icons.circle, color: rarity.color, size: 16),
                    title: Text(rarity.name),
                    trailing: Text('$probabilityPercent %'),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('確率の読み込みに失敗しました: $e')));
    }
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
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_userCoins C',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.pinkAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_gachaPoints P',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.percent_outlined),
                      label: const Text('排出確率'),
                      onPressed: () => _showGachaProbabilities(context, config),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('ガチャ履歴'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GachaHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
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
                onPressed: _isPulling
                    ? null
                    : () => _pullMultiGacha(config, items),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isPulling
                    ? const CircularProgressIndicator()
                    : Text(
                        '${config.multiPullCount}回引く (${config.multiPullCost} C)',
                      ),
              ),
              if (_userUltraRareTickets > 0) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isPulling
                      ? null
                      : () => _pullUltraRareGacha(config, items),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.yellow,
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
