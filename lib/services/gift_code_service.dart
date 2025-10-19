import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ギフトコード引き換え結果を格納するクラス
class GiftCodeResult {
  final bool success;
  final String message;

  GiftCodeResult({
    required this.success,
    required this.message,
  });
}

class GiftCodeService {
  final _supabase = Supabase.instance.client;

  // ギフトコードを引き換えるためのメソッド
  Future<GiftCodeResult> redeemGiftCode(String code) async {
    // アプリのカスタムユーザーID管理に合わせ、SharedPreferencesからIDを取得する
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    // アプリ内にユーザーIDが保存されていない場合はエラー
    if (userId == null) {
      return GiftCodeResult(success: false, message: 'ユーザー情報がありません。プロフィール画面から設定を完了してください。');
    }

    try {
      // SupabaseのRPC関数 'redeem_gift_code' を呼び出す
      final result = await _supabase.rpc('redeem_gift_code', params: {
        'code_string': code,
        'user_id_param': userId, // 取得したユーザーIDを渡す
      });

      final status = result['status'] as String?;
      final message = result['message'] as String?;

      return GiftCodeResult(
        success: status == 'success',
        message: message ?? '不明なエラーが発生しました。',
      );
    } on PostgrestException catch (e) {
      return GiftCodeResult(success: false, message: 'データベースエラーが発生しました。');
    } catch (e) {
      return GiftCodeResult(success: false, message: '不明なエラーが発生しました。');
    }
  }
}