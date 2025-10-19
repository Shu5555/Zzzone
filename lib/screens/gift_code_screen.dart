
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

      // 結果をSnackBarで表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message), // サーバーからのメッセージを直接表示
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );

      if (result.success) {
         _codeController.clear();
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
