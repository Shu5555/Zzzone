import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

  bool _isRankingEnabled = false;
  String? _userId;
  int _sleepCoins = 0;

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
    _sleepCoins = prefs.getInt('sleep_coins') ?? 0;
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? currentUserId = _userId;

      // First time enabling ranking, generate and save a new user ID
      if (_isRankingEnabled && currentUserId == null) {
        currentUserId = const Uuid().v4();
        await prefs.setString('userId', currentUserId);
        setState(() => _userId = currentUserId);
      }

      // Update local preferences
      await prefs.setString('userName', _usernameController.text);
      await prefs.setBool('isRankingEnabled', _isRankingEnabled);

      // Sync with server if ranking is enabled
      if (_isRankingEnabled && currentUserId != null) {
        await _supabaseService.updateUser(
          id: currentUserId,
          username: _usernameController.text,
        );
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

  Future<void> _deleteRankingData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ランキングデータ削除'),
        content: const Text('サーバー上のあなたのランキング情報をすべて削除します。この操作は元に戻せません。よろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _userId != null) {
      try {
        await _supabaseService.deleteUser(_userId!);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isRankingEnabled', false);
        // Keep userId in case user wants to re-register with the same ID?
        // For now, let's keep it simple and not remove it.

        setState(() {
          _isRankingEnabled = false;
          _hasChanges = true; // Mark as changed to allow saving the disabled state
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ランキングデータを削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
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
                    ListTile(
                      leading: const Icon(Icons.person_pin_outlined),
                      title: const Text('ユーザーID'),
                      subtitle: Text(_userId ?? 'ランキング参加を有効にすると生成されます'),
                    ),
                    const Divider(),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('ランキングデータを削除', style: TextStyle(color: Colors.red)),
                        onPressed: _isRankingEnabled && _userId != null ? _deleteRankingData : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
