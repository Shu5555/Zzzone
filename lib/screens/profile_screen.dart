import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/shop_item.dart';
import '../services/supabase_ranking_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _supabaseService = SupabaseRankingService();

  // State variables
  bool _isRankingEnabled = false;
  String? _userId;
  int _sleepCoins = 0;
  String _selectedBackground = 'default';

  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _usernameController.text = prefs.getString('userName') ?? '';
    _isRankingEnabled = prefs.getBool('isRankingEnabled') ?? false;
    _userId = prefs.getString('userId');

    if (_isRankingEnabled && _userId != null) {
      final userProfile = await _supabaseService.getUser(_userId!);
      if (userProfile != null && mounted) {
        setState(() {
          _selectedBackground = userProfile['background_preference'] ?? 'default';
          _sleepCoins = userProfile['sleep_coins'] ?? 0;
        });
      }
    } else {
      setState(() => _sleepCoins = 0);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? currentUserId = _userId;
      bool isNewUser = false;

      if (_isRankingEnabled && currentUserId == null) {
        isNewUser = true;
        currentUserId = const Uuid().v4();
        await prefs.setString('userId', currentUserId);
        setState(() => _userId = currentUserId);
      }

      await prefs.setString('userName', _usernameController.text);
      await prefs.setBool('isRankingEnabled', _isRankingEnabled);

      if (_isRankingEnabled && currentUserId != null) {
        if (isNewUser) {
          int initialCoins = 0;
          if (kDebugMode) {
            initialCoins = 10000;
          }
          await _supabaseService.updateUser(
            id: currentUserId,
            username: _usernameController.text,
            sleepCoins: initialCoins,
          );
          setState(() => _sleepCoins = initialCoins);
        } else {
          // For existing users, save background preference
          await _supabaseService.updateUser(
            id: currentUserId,
            username: _usernameController.text,
            backgroundPreference: _selectedBackground,
          );
        }
      }

      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: (_hasChanges && !_isSaving) ? _saveProfile : null,
              child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'ユーザー名',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'ユーザー名を入力してください';
                        }
                        if (value.length > 20) {
                          return 'ユーザー名は20文字以内にしてください';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('ランキングに参加する'),
                      subtitle: const Text('あなたの睡眠時間が全国ランキングに登録されます'),
                      value: _isRankingEnabled,
                      onChanged: (value) {
                        setState(() {
                          _isRankingEnabled = value;
                          _hasChanges = true;
                        });
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.monetization_on_outlined),
                      title: const Text('所持スリープコイン'),
                      trailing: Text('$_sleepCoins C', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const Divider(),
                    _buildBackgroundSelector(), // Existing Background Selector
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBackgroundSelector() {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('ランキングの背景'),
      subtitle: Text('現在の背景: $_selectedBackground'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        if (_userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ランキングを有効にしてください')));
          return;
        }

        final unlockedIds = await _supabaseService.getUnlockedBackgrounds(_userId!);
        
        final Map<String, dynamic> availableOptions = {
          'default': {'type': 'color', 'color': Theme.of(context).cardColor, 'name': 'Default (Transparent)'},
          'color_#ffffff': {'type': 'color', 'color': const Color(0xffffffff), 'name': 'White'},
        };

        for (var item in backgroundShopCatalog) {
          if (unlockedIds.contains(item.id)) {
            availableOptions[item.id] = {'type': 'color', 'color': item.previewColor, 'name': item.name};
          }
        }

        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: availableOptions.length,
            itemBuilder: (context, index) {
              final key = availableOptions.keys.elementAt(index);
              final option = availableOptions[key]!;
              final bool isSelected = key == _selectedBackground;

              return GestureDetector(
                onTap: () => Navigator.of(context).pop(key),
                child: Tooltip(
                  message: option['name'],
                  child: Container(
                    decoration: BoxDecoration(
                      color: option['color'],
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 3) : Border.all(color: Colors.grey.withOpacity(0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                  ),
                ),
              );
            },
          ),
        );

        if (result != null) {
          setState(() {
            _selectedBackground = result;
            _hasChanges = true;
          });
        }
      },
    );
  }
}
