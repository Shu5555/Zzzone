import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ギフトコード引き換え結果を格納するクラス
class GiftCodeResult {
  final bool success;
  final String message;
  final String? rewardType;
  final String? rewardValue;

  GiftCodeResult({
    required this.success,
    required this.message,
    this.rewardType,
    this.rewardValue,
  });
}

class GiftCodeService {
  final _supabase = Supabase.instance.client;

  // ギフトコードを引き換えるためのメソッド
  Future<GiftCodeResult> redeemGiftCode(String code) async {
    // SharedPreferencesからユーザーIDを取得
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    // アプリ内にユーザーIDが保存されていない場合はエラー
    if (userId == null) {
      // このエラーは、ユーザーがプロフィール設定を完了していない場合に発生する可能性がある
      return GiftCodeResult(success: false, message: 'user_id_not_found');
    }

    try {
      // SupabaseのRPC関数 'redeem_gift_code' を呼び出す
      final result = await _supabase.rpc('redeem_gift_code', params: {
        'p_user_id': userId, // SharedPreferencesから取得したIDを使用
        'p_code': code,
      }).single();

      // 結果をGiftCodeResultオブジェクトに変換して返す
      return GiftCodeResult(
        success: result['success'] as bool,
        message: result['message'] as String,
        rewardType: result['reward_type'] as String?,
        rewardValue: result['reward_value'] as String?,
      );
    } on PostgrestException catch (e) {
      // データベース関連のエラー
      return GiftCodeResult(success: false, message: e.message);
    } catch (e) {
      // その他の予期せぬエラー
      return GiftCodeResult(success: false, message: 'unknown_error');
    }
  }
}