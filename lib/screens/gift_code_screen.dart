
import 'package:flutter/material.dart';
import '../services/gift_code_service.dart';

class GiftCodeScreen extends StatefulWidget {
  const GiftCodeScreen({super.key});

  @override
  State<GiftCodeScreen> createState() => _GiftCodeScreenState();
}

class _GiftCodeScreenState extends State<GiftCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _giftCodeService = GiftCodeService();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final code = _codeController.text.trim();
    final result = await _giftCodeService.redeemGiftCode(code);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // 結果に応じたメッセージを表示
      final message = _getDisplayMessage(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );

      if (result.success) {
         _codeController.clear();
      }
    }
  }

  // バックエンドからのメッセージを分かりやすい日本語に変換
  String _getDisplayMessage(GiftCodeResult result) {
    if (result.success) {
      switch (result.rewardType) {
        case 'sleep_coins':
          return '${result.rewardValue}コインを獲得しました！';
        case 'ultra_rare_ticket':
          return '超激レア確定ガチャチケットを${result.rewardValue}枚獲得しました！';
        default:
          return '報酬を受け取りました！';
      }
    } else {
      switch (result.message) {
        case 'code_not_found':
          return '無効なコードです。';
        case 'code_expired':
          return 'このコードの有効期限は切れています。';
        case 'code_max_uses_reached':
          return 'このコードは上限回数まで使用されています。';
        case 'code_already_redeemed':
          return 'このコードは既に使用済みです。';
        case 'user_id_not_found':
          return 'エラーが発生しました。プロフィール設定を完了してください。';
        case 'not_authenticated':
           return 'エラーが発生しました。再ログインしてお試しください。';
        default:
          return 'エラーが発生しました。コードを確認して再度お試しください。';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ギフトコード'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ギフトコードを入力して報酬を獲得しましょう！',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'ギフトコード',
                  border: OutlineInputBorder(),
                  hintText: 'ZZZONE-XXXXX-XXXXX',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'コードを入力してください。';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _redeemCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Text('引き換える'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
