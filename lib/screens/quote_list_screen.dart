import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gacha/models/gacha_config.dart';
import '../gacha/models/gacha_item.dart';
import '../gacha/models/gacha_rarity.dart';
import '../gacha/services/gacha_data_loader.dart';
import '../services/database_helper.dart';
import '../services/supabase_ranking_service.dart';
import '../utils/string_converter.dart';

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

  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initFuture = _loadData();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId == null) {
      throw Exception('ユーザーIDが見つかりません。ランキングへの参加が必要です。');
    }

    // ▼▼▼ データ取得処理を新しい高効率なメソッドに置き換え ▼▼▼
    final results = await Future.wait([
      _supabaseService.getUser(_userId!),
      DatabaseHelper.instance.getUnlockedQuotesWithDetails(),
    ]);

    final userProfile = results[0] as Map<String, dynamic>?;
    final unlockedQuotesData = results[1] as List<Map<String, dynamic>>;

    final allRarities = <String, GachaRarity>{};
    final unlockedQuotes = <GachaItem>[];

    for (var row in unlockedQuotesData) {
      final rarityId = row['rarityId'] as String;
      if (!allRarities.containsKey(rarityId)) {
        final hexColor = (row['rarityColor'] as String).replaceAll('#', '');
        allRarities[rarityId] = GachaRarity(
          id: rarityId,
          name: row['rarityName'] as String,
          color: Color(int.parse('FF$hexColor', radix: 16)),
          order: row['rarityOrder'] as int,
          probability: 0, // This value is not used in this screen
        );
      }

      final item = GachaItem(
        id: row['id'] as String,
        rarityId: rarityId,
        customData: {
          'text': row['quote'] as String? ?? '',
          'author': row['author'] as String? ?? '',
        },
      );
      item.setRarity(allRarities[rarityId]!);
      unlockedQuotes.add(item);
    }
    // ▲▲▲

    // Group quotes by rarity
    final grouped = <String, List<GachaItem>>{};
    for (var quote in unlockedQuotes) {
      (grouped[quote.rarityId] ??= []).add(quote);
    }

    // Sort rarities by order (descending)
    final sortedRarities = allRarities.values.toList()..sort((a, b) => b.order.compareTo(a.order));

    if (mounted) {
      final dynamic favId = userProfile?['favorite_quote_id'];
      setState(() {
        _favoriteQuoteId = favId is String ? favId : null;
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

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('名言一覧'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '名言や著者名で検索...',
          border: InputBorder.none,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRandomMode = _favoriteQuoteId == 'random';

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildAppBar(),
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

          // Create a temporary map to hold filtered results
          final filteredGroupedQuotes = <String, List<GachaItem>>{};
          int totalFilteredQuotes = 0;

          for (var rarity in _sortedRarities) {
            final quotesInRarity = (_groupedQuotes[rarity.id] ?? []).where((quote) {
              if (_searchQuery.isEmpty) return true;

              final hiraganaQuery = StringConverter.katakanaToHiragana(_searchQuery.toLowerCase());

              final hiraganaText = StringConverter.katakanaToHiragana(quote.text?.toLowerCase() ?? '');
              final hiraganaAuthor = StringConverter.katakanaToHiragana(quote.author?.toLowerCase() ?? '');

              return hiraganaText.contains(hiraganaQuery) || hiraganaAuthor.contains(hiraganaQuery);
            }).toList();

            if (quotesInRarity.isNotEmpty) {
              filteredGroupedQuotes[rarity.id] = quotesInRarity;
              totalFilteredQuotes += quotesInRarity.length;
            }
          }

          if (totalFilteredQuotes == 0 && _searchQuery.isNotEmpty) {
            return const Center(child: Text('検索結果が見つかりません'));
          }

          return ListView.builder(
            itemCount: _sortedRarities.length,
            itemBuilder: (context, index) {
              final rarity = _sortedRarities[index];
              final quotesInRarity = filteredGroupedQuotes[rarity.id] ?? [];

              if (quotesInRarity.isEmpty) {
                return const SizedBox.shrink(); // Hide rarity section if no quotes match
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ExpansionTile(
                  leading: Icon(Icons.label, color: rarity.color),
                  title: Text(rarity.name, style: TextStyle(color: rarity.color, fontWeight: FontWeight.bold)),
                  initiallyExpanded: true,
                  children: ListTile.divideTiles(
                    context: context,
                    tiles: quotesInRarity.map((quote) {
                      final isFavorite = quote.id == _favoriteQuoteId;
                      return ListTile(
                        title: Text('"${quote.text}"'),
                        subtitle: Text('- ${quote.author}'),
                        trailing: _favoriteQuoteId == 'random'
                            ? null
                            : Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber : null),
                        onTap: _favoriteQuoteId == 'random' ? null : () => _setFavoriteQuote(quote.id),
                        onLongPress: () {
                          final textToCopy = '"${quote.text}" - ${quote.author}';
                          Clipboard.setData(ClipboardData(text: textToCopy));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('名言をコピーしました')),
                          );
                        },
                      );
                    }),
                  ).toList(),
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