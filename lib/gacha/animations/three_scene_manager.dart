import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

class ThreeSceneManager {
  html.CanvasElement? _canvas;
  js.JsObject? _sceneController;

  /// Canvasを初期化し、Three.jsシーンを作成
  Future<void> initialize(html.CanvasElement canvas) async {
    _canvas = canvas;
    
    // JavaScriptのThree.jsシーンを初期化
    _sceneController = js.JsObject(
      js.context['ThreeGachaScene'],
      [canvas]
    );
  }

  /// 光の玉を配置（レアリティ情報を渡す）
  void createOrbs(List<Map<String, dynamic>> orbData) {
    if (_sceneController == null) return;
    
    final jsOrbData = js.JsArray.from(
      orbData.map((data) => js.JsObject.jsify(data)).toList()
    );
    
    _sceneController!.callMethod('createOrbs', [jsOrbData]);
  }

  /// カメラを次の玉に移動
  Future<void> moveToNextOrb(int index) async {
    if (_sceneController == null) return Future.value();
    
    final completer = Completer<void>();
    
    _sceneController!.callMethod('moveToOrb', [
      index,
      js.allowInterop(() {
        completer.complete();
      })
    ]);
    
    return completer.future;
  }

  /// アニメーションループを開始
  void startAnimation() {
    _sceneController?.callMethod('startAnimation', []);
  }

  /// デバッグ: 昇格演出をテスト
  void debugTriggerUpgrade(int orbIndex, String newColor) {
    _sceneController?.callMethod('debugTriggerUpgrade', [orbIndex, newColor]);
  }

  /// クリーンアップ
  void dispose() {
    _sceneController?.callMethod('dispose', []);
    _sceneController = null;
  }
}
