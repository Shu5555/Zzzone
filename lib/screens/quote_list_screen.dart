import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gacha/models/gacha_config.dart';
import '../gacha/models/gacha_item.dart';
import '../gacha/models/gacha_rarity.dart';
import '../gacha/services/gacha_data_loader.dart';
import '../services/database_helper.dart';
import '../services/supabase_ranking_service.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  final _supabaseService = SupabaseRankingService();
  late Future<void> _initFuture;

  String? _userId;
  String? _favoriteQuoteId;
  
  // State for grouped quotes
  List<GachaRarity> _sortedRarities = [];
  Map<String, List<GachaItem>> _groupedQuotes = {};

  @override
  void initState() {
    super.initState();
    _initFuture = _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId == null) {
      throw Exception('ユーザーIDが見つかりません。ランキングへの参加が必要です。');
    }

    // Load all necessary data in parallel
    final results = await Future.wait([
      GachaDataLoader.loadItems('assets/gacha/gacha_items.json'),
      GachaDataLoader.loadConfig('assets/gacha/gacha_config.json'),
      _supabaseService.getUser(_userId!),
      DatabaseHelper.instance.getUnlockedQuoteIds(),
    ]);

    final allItems = results[0] as List<GachaItem>;
    final config = results[1] as GachaConfig;
    final userProfile = results[2] as Map<String, dynamic>?;
    final unlockedQuoteIds = results[3] as List<String>;

    // Attach rarity info to each item
    for (var item in allItems) {
      final rarity = config.rarities.firstWhere((r) => r.id == item.rarityId, orElse: () => config.rarities.first);
      item.setRarity(rarity);
    }

    final unlockedQuotes = allItems.where((item) => unlockedQuoteIds.contains(item.id)).toList();

    // Group quotes by rarity
    final grouped = <String, List<GachaItem>>{};
    for (var quote in unlockedQuotes) {
      (grouped[quote.rarityId] ??= []).add(quote);
    }

    // Sort rarities by order (descending)
    final sortedRarities = List<GachaRarity>.from(config.rarities)..sort((a, b) => b.order.compareTo(a.order));

    if (mounted) {
      setState(() {
        _favoriteQuoteId = userProfile?['favorite_quote_id'];
        _groupedQuotes = grouped;
        _sortedRarities = sortedRarities;
      });
    }
  }

  Future<void> _setFavoriteQuote(String? quoteId) async {
    if (_userId == null) return;

    try {
      await _supabaseService.setFavoriteQuote(_userId!, quoteId);
      setState(() {
        _favoriteQuoteId = quoteId;
      });
      if (quoteId != 'random' && quoteId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お気に入り名言を設定しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('設定に失敗しました: $e')),
      );
    }
  }

  void _toggleRandomMode() {
    if (_favoriteQuoteId == 'random') {
      _setFavoriteQuote(null);
    } else {
      _setFavoriteQuote('random');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRandomMode = _favoriteQuoteId == 'random';

    return Scaffold(
      appBar: AppBar(
        title: const Text('名言一覧'),
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (_groupedQuotes.isEmpty) {
            return const Center(child: Text('ガチャで名言を獲得できます'));
          }

          return ListView.builder(
            itemCount: _sortedRarities.length,
            itemBuilder: (context, index) {
              final rarity = _sortedRarities[index];
              final quotesInRarity = _groupedQuotes[rarity.id] ?? [];

              if (quotesInRarity.isEmpty) {
                return const SizedBox.shrink(); // Hide rarity section if no quotes are owned
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ExpansionTile(
                  leading: Icon(Icons.label, color: rarity.color),
                  title: Text(rarity.name, style: TextStyle(color: rarity.color, fontWeight: FontWeight.bold)),
                  initiallyExpanded: true,
                  children: quotesInRarity.map((quote) {
                    final isFavorite = quote.id == _favoriteQuoteId;
                    return Column(
                      children: [
                        ListTile(
                          title: Text('"${quote.text}"'),
                          subtitle: Text('- ${quote.author}'),
                          trailing: _favoriteQuoteId == 'random'
                              ? null
                              : Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber : null),
                          onTap: _favoriteQuoteId == 'random' ? null : () => _setFavoriteQuote(quote.id),
                        ),
                        if (index < quotesInRarity.length - 1)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _groupedQuotes.isEmpty ? null : _toggleRandomMode,
        tooltip: 'ランダムモード切替',
        backgroundColor: isRandomMode ? Theme.of(context).colorScheme.primary : null,
        child: const Icon(Icons.shuffle),
      ),
    );
  }
}