# Three.js ガチャアニメーション実装ロードマップ

## 目次
1. [概要](#概要)
2. [前提条件](#前提条件)
3. [アーキテクチャ設計](#アーキテクチャ設計)
4. [実装フェーズ](#実装フェーズ)
5. [テスト計画](#テスト計画)
6. [トラブルシューティング](#トラブルシューティング)

---

## 概要

### 目的
10連ガチャの結果表示前に、レアリティを3D演出で示すアニメーション画面を実装する。  
このアニメーションは以下の要件を満たす：

- **3D空間での光の玉配置**（円周上に等間隔）
- **カメラの円運動**（各玉を順番にフォーカス）
- **レアリティに応じた発光エフェクト**
- **昇格演出を後から追加できる拡張性**

### 使用技術
- **Three.js (r128)** - 3Dレンダリング
- **Flutter (Web/Mobile)** - アプリケーションフレームワーク
- **Dart ↔ JavaScript連携** - `dart:html`と`dart:js`を使用

---

## 前提条件

### 必要な知識
実装者は以下の知識を持っていることが望ましい：

- ✅ Flutter/Dartの基礎（Widget、State管理）
- ✅ JavaScriptの基礎（関数、オブジェクト、Promise）
- ⚠️ Three.jsの知識は**不要**（このドキュメントで詳細に説明）

### 開発環境
- Flutter SDK 3.4.0以上
- ブラウザ（Chrome推奨）でのテスト環境
- テキストエディタ（VS Code推奨）

### 既存コードの理解
以下のファイルを事前に確認してください：

```
lib/gacha/screens/
├── gacha_screen.dart                    # ガチャ実行画面
├── multi_gacha_animation_screen.dart    # 現在の10連アニメーション（置き換え対象）
└── sequential_gacha_flow_screen.dart    # 結果を1つずつ表示する画面
```

**重要**: `multi_gacha_animation_screen.dart`の機能を新しいThree.js版に置き換えます。

---

## アーキテクチャ設計

### ディレクトリ構造

新しく以下のディレクトリ・ファイルを作成します：

```
lib/gacha/animations/
├── three_gacha_animation_screen.dart    # メイン画面（Flutter Widget）
├── three_scene_manager.dart             # Three.jsシーン管理（Dart側）
└── js/
    ├── three_gacha_scene.js             # Three.jsシーン実装（JS側）
    └── three_utils.js                   # ユーティリティ関数

assets/gacha/
└── three_gacha_scene.html               # Three.jsを埋め込むHTML

pubspec.yaml                             # アセット登録
```

### データフロー

```
[ガチャ実行] 
    ↓
[gacha_screen.dart]
    ↓ (itemsWithStatus を渡す)
[three_gacha_animation_screen.dart] ← ★ 新規作成
    ↓ (JavaScript呼び出し)
[three_gacha_scene.js] ← ★ 新規作成
    ↓ (アニメーション完了)
[sequential_gacha_flow_screen.dart]
    ↓
[multi_gacha_result_screen.dart]
```

---

## 実装フェーズ

### フェーズ0: 準備作業（30分）

#### Task 0.1: アセットの登録

**ファイル**: `pubspec.yaml`

既存の`assets`セクションに以下を追加：

```yaml
flutter:
  assets:
    - .env
    - assets/images/
    - assets/gacha/
    - assets/announcements.json
    - assets/gacha/three_gacha_scene.html  # ← 追加
```

#### Task 0.2: HTMLテンプレートの作成

**新規ファイル**: `assets/gacha/three_gacha_scene.html`

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { margin: 0; overflow: hidden; }
    #canvas-container { width: 100vw; height: 100vh; }
  </style>
</head>
<body>
  <div id="canvas-container"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script src="three_gacha_scene.js"></script>
</body>
</html>
```

**重要**: このHTMLは実際には使用しません（Three.jsをDartから直接制御するため）が、参考用に残します。

---

### フェーズ1: 基本シーンの構築（2時間）

#### Task 1.1: Three.jsシーンマネージャーの作成

**新規ファイル**: `lib/gacha/animations/three_scene_manager.dart`

このクラスはDart側からJavaScriptのThree.jsシーンを制御します。

```dart
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
    if (_sceneController == null) return;
    
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

  /// クリーンアップ
  void dispose() {
    _sceneController?.callMethod('dispose', []);
    _sceneController = null;
  }
}
```

#### Task 1.2: JavaScript側のシーン実装（基礎）

**新規ファイル**: `web/three_gacha_scene.js`

**重要**: このファイルは`web/`ディレクトリに配置します（Flutter Webの公開ディレクトリ）。

```javascript
/**
 * Three.jsガチャアニメーションシーン
 * 
 * このクラスは3D空間を管理し、光の玉を配置・演出します。
 */
class ThreeGachaScene {
  constructor(canvas) {
    this.canvas = canvas;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.orbs = [];
    this.animationFrameId = null;
    
    this.initScene();
  }

  /**
   * シーンの初期化
   */
  initScene() {
    // シーンの作成
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x000000); // 黒背景

    // カメラの作成（透視投影カメラ）
    this.camera = new THREE.PerspectiveCamera(
      75,                                    // 視野角
      window.innerWidth / window.innerHeight, // アスペクト比
      0.1,                                   // ニアクリップ
      1000                                   // ファークリップ
    );
    this.camera.position.z = 10; // カメラを後ろに配置

    // レンダラーの作成
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: true,  // アンチエイリアス有効
      alpha: true       // 背景透過
    });
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.setPixelRatio(window.devicePixelRatio);

    // 環境光を追加（全体を薄く照らす）
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.3);
    this.scene.add(ambientLight);

    // ウィンドウリサイズ対応
    window.addEventListener('resize', () => this.onWindowResize());
  }

  /**
   * ウィンドウリサイズ時の処理
   */
  onWindowResize() {
    this.camera.aspect = window.innerWidth / window.innerHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(window.innerWidth, window.innerHeight);
  }

  /**
   * 光の玉を作成
   * @param {Array} orbDataList - [{color: '#FF0000', rarityName: 'レア'}, ...]
   */
  createOrbs(orbDataList) {
    const radius = 5;        // 円の半径
    const count = orbDataList.length;

    orbDataList.forEach((data, index) => {
      // 円周上の角度を計算
      const angle = (index / count) * Math.PI * 2;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius;

      // 球体ジオメトリ（低ポリゴン）
      const geometry = new THREE.SphereGeometry(0.5, 16, 16);
      
      // マテリアル（発光色）
      const material = new THREE.MeshStandardMaterial({
        color: new THREE.Color(data.color),
        emissive: new THREE.Color(data.color),
        emissiveIntensity: 0.5
      });

      const orb = new THREE.Mesh(geometry, material);
      orb.position.set(x, 0, z);

      // カスタムデータを保存
      orb.userData = {
        index: index,
        rarityName: data.rarityName,
        originalColor: data.color
      };

      this.scene.add(orb);
      this.orbs.push(orb);
    });

    console.log(`${count}個の光の玉を配置しました`);
  }

  /**
   * アニメーションループを開始
   */
  startAnimation() {
    const animate = () => {
      this.animationFrameId = requestAnimationFrame(animate);

      // 光の玉をゆっくり浮遊させる
      this.orbs.forEach((orb, index) => {
        orb.position.y = Math.sin(Date.now() * 0.001 + index) * 0.2;
      });

      this.renderer.render(this.scene, this.camera);
    };

    animate();
  }

  /**
   * クリーンアップ
   */
  dispose() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
    
    this.orbs.forEach(orb => {
      orb.geometry.dispose();
      orb.material.dispose();
    });
    
    this.renderer.dispose();
  }
}

// グローバルに公開（Dartから呼び出せるようにする）
window.ThreeGachaScene = ThreeGachaScene;
```

#### Task 1.3: Flutter Widgetの作成

**新規ファイル**: `lib/gacha/animations/three_gacha_animation_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import '../models/gacha_item_with_new_status.dart';
import 'three_scene_manager.dart';

class ThreeGachaAnimationScreen extends StatefulWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus;

  const ThreeGachaAnimationScreen({
    super.key,
    required this.itemsWithStatus,
  });

  @override
  State<ThreeGachaAnimationScreen> createState() =>
      _ThreeGachaAnimationScreenState();
}

class _ThreeGachaAnimationScreenState
    extends State<ThreeGachaAnimationScreen> {
  late ThreeSceneManager _sceneManager;
  late html.CanvasElement _canvas;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeScene();
  }

  /// Three.jsシーンの初期化
  Future<void> _initializeScene() async {
    // Canvasを作成
    _canvas = html.CanvasElement()
      ..width = html.window.innerWidth!
      ..height = html.window.innerHeight!;

    // Canvasを登録（Flutter WebのViewとして）
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'three-gacha-canvas',
      (int viewId) => _canvas,
    );

    // シーンマネージャーを初期化
    _sceneManager = ThreeSceneManager();
    await _sceneManager.initialize(_canvas);

    // 光の玉のデータを準備
    final orbData = widget.itemsWithStatus.map((itemWithStatus) {
      final item = itemWithStatus.item;
      return {
        'color': '#${item.rarity.color.value.toRadixString(16).substring(2)}',
        'rarityName': item.rarity.name,
      };
    }).toList();

    // 光の玉を配置
    _sceneManager.createOrbs(orbData);

    // アニメーション開始
    _sceneManager.startAnimation();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _sceneManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Three.jsのCanvas
          if (_isInitialized)
            const HtmlElementView(viewType: 'three-gacha-canvas'),

          // ローディング表示
          if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // タップ案内（後で実装）
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'タップして開始',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Task 1.4: 既存コードの修正

**ファイル**: `lib/gacha/screens/gacha_screen.dart`

`_pullMultiGacha`メソッド内の画面遷移部分を変更：

```dart
// 変更前
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => MultiGachaAnimationScreen(
      itemsWithStatus: pulledItemsWithStatus,
      config: config,
    ),
  ),
);

// 変更後
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ThreeGachaAnimationScreen(  // ← 変更
      itemsWithStatus: pulledItemsWithStatus,
    ),
  ),
);
```

**import文も追加**:
```dart
import '../animations/three_gacha_animation_screen.dart';
```

---

### フェーズ2: カメラワークの実装（3時間）

#### Task 2.1: カメラ移動機能の追加（JavaScript側）

**ファイル**: `web/three_gacha_scene.js`

`ThreeGachaScene`クラスに以下のメソッドを追加：

```javascript
/**
 * 指定したインデックスの玉にカメラを移動
 * @param {number} index - 移動先の玉のインデックス
 * @param {Function} onComplete - 移動完了時のコールバック
 */
moveToOrb(index, onComplete) {
  if (index >= this.orbs.length) {
    console.error('存在しないインデックスです:', index);
    return;
  }

  const targetOrb = this.orbs[index];
  const targetPosition = targetOrb.position.clone();

  // カメラの目標位置を計算（玉の手前に配置）
  const cameraDistance = 3;
  const direction = targetPosition.clone().normalize();
  const cameraTarget = direction.multiplyScalar(cameraDistance);

  // カメラを滑らかに移動（TWEEN.jsの代わりに簡易実装）
  this.animateCameraMove(cameraTarget, targetPosition, onComplete);
}

/**
 * カメラアニメーション（滑らかな移動）
 */
animateCameraMove(targetPos, lookAtPos, onComplete) {
  const duration = 1000; // 1秒
  const startPos = this.camera.position.clone();
  const startTime = Date.now();

  const animate = () => {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(elapsed / duration, 1);

    // イージング関数（ease-in-out）
    const eased = progress < 0.5
      ? 2 * progress * progress
      : 1 - Math.pow(-2 * progress + 2, 2) / 2;

    // 位置を補間
    this.camera.position.lerpVectors(startPos, targetPos, eased);
    this.camera.lookAt(lookAtPos);

    if (progress < 1) {
      requestAnimationFrame(animate);
    } else {
      if (onComplete) onComplete();
    }
  };

  animate();
}
```

#### Task 2.2: タップ操作の実装（Dart側）

**ファイル**: `lib/gacha/animations/three_gacha_animation_screen.dart`

`_ThreeGachaAnimationScreenState`クラスに以下を追加：

```dart
int _currentOrbIndex = 0;
bool _isMoving = false;
bool _hasStarted = false;

/// タップ処理
Future<void> _onTap() async {
  // 初回タップ（アニメーション開始）
  if (!_hasStarted) {
    setState(() {
      _hasStarted = true;
    });
    await _moveToNextOrb();
    return;
  }

  // カメラ移動中は無視
  if (_isMoving) return;

  // 次の玉へ移動
  await _moveToNextOrb();
}

/// 次の玉へカメラを移動
Future<void> _moveToNextOrb() async {
  if (_currentOrbIndex >= widget.itemsWithStatus.length) {
    // 全ての玉を見終わったら結果画面へ
    _navigateToResult();
    return;
  }

  setState(() {
    _isMoving = true;
  });

  // カメラ移動
  await _sceneManager.moveToNextOrb(_currentOrbIndex);

  setState(() {
    _currentOrbIndex++;
    _isMoving = false;
  });
}

/// 結果画面へ遷移
void _navigateToResult() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => SequentialGachaFlowScreen(
        itemsWithStatus: widget.itemsWithStatus,
        config: widget.config, // ← 注意: configを渡す必要がある
      ),
    ),
  );
}
```

**build メソッドを修正**:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(  // ← タップ検知を追加
      onTap: _onTap,
      child: Stack(
        children: [
          if (_isInitialized)
            const HtmlElementView(viewType: 'three-gacha-canvas'),

          if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // タップ案内
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              _hasStarted
                  ? 'タップして次へ (${_currentOrbIndex + 1}/${widget.itemsWithStatus.length})'
                  : 'タップして開始',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**重要**: `SequentialGachaFlowScreen`に`config`を渡す必要があるため、`ThreeGachaAnimationScreen`のコンストラクタを修正：

```dart
class ThreeGachaAnimationScreen extends StatefulWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus;
  final GachaConfig config;  // ← 追加

  const ThreeGachaAnimationScreen({
    super.key,
    required this.itemsWithStatus,
    required this.config,  // ← 追加
  });

  // ...
}
```

---

### フェーズ3: エフェクトの実装（4時間）

#### Task 3.1: グローエフェクトの追加

**ファイル**: `web/three_gacha_scene.js`

シーン初期化時に後処理（Post-processing）を追加：

```javascript
// ※注意: r128にはUnrealBloomPassが含まれていないため、
// 簡易的なグローを実装します

initScene() {
  // ... 既存のコード ...

  // ポイントライトを各玉に追加する方式でグロー効果を実現
  // （後でcreateOrbsメソッド内で実装）
}
```

**`createOrbs`メソッドを修正**:

```javascript
createOrbs(orbDataList) {
  const radius = 5;
  const count = orbDataList.length;

  orbDataList.forEach((data, index) => {
    const angle = (index / count) * Math.PI * 2;
    const x = Math.cos(angle) * radius;
    const z = Math.sin(angle) * radius;

    // 球体ジオメトリ
    const geometry = new THREE.SphereGeometry(0.5, 16, 16);
    
    // マテリアル
    const material = new THREE.MeshStandardMaterial({
      color: new THREE.Color(data.color),
      emissive: new THREE.Color(data.color),
      emissiveIntensity: 0.8  // ← 発光強度を上げる
    });

    const orb = new THREE.Mesh(geometry, material);
    orb.position.set(x, 0, z);

    // ★ ポイントライトを追加（グロー効果）
    const light = new THREE.PointLight(
      new THREE.Color(data.color),
      2,    // 強度
      10    // 距離
    );
    light.position.copy(orb.position);
    this.scene.add(light);

    orb.userData = {
      index: index,
      rarityName: data.rarityName,
      originalColor: data.color,
      light: light  // ← ライトへの参照を保存
    };

    this.scene.add(orb);
    this.orbs.push(orb);
  });
}
```

#### Task 3.2: パーティクルシステムの追加

**新規ファイル**: `web/three_particle_system.js`

```javascript
/**
 * パーティクルシステム
 * 玉の周囲に光の粒を表示
 */
class ParticleSystem {
  constructor(scene, position, color, count = 50) {
    this.scene = scene;
    this.particles = null;
    this.createParticles(position, color, count);
  }

  createParticles(position, color, count) {
    const geometry = new THREE.BufferGeometry();
    const positions = [];
    const velocities = [];

    // パーティクルの初期位置と速度をランダム生成
    for (let i = 0; i < count; i++) {
      // 球状に配置
      const radius = Math.random() * 2;
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.random() * Math.PI;

      positions.push(
        position.x + radius * Math.sin(phi) * Math.cos(theta),
        position.y + radius * Math.sin(phi) * Math.sin(theta),
        position.z + radius * Math.cos(phi)
      );

      // 外側に向かう速度
      velocities.push(
        Math.sin(phi) * Math.cos(theta) * 0.02,
        Math.sin(phi) * Math.sin(theta) * 0.02,
        Math.cos(phi) * 0.02
      );
    }

    geometry.setAttribute(
      'position',
      new THREE.Float32BufferAttribute(positions, 3)
    );

    // パーティクルのマテリアル
    const material = new THREE.PointsMaterial({
      color: new THREE.Color(color),
      size: 0.1,
      transparent: true,
      opacity: 0.8
    });

    this.particles = new THREE.Points(geometry, material);
    this.velocities = velocities;
    this.scene.add(this.particles);
  }

  /**
   * パーティクルをアニメーション
   */
  update() {
    const positions = this.particles.geometry.attributes.position.array;

    for (let i = 0; i < positions.length; i += 3) {
      positions[i] += this.velocities[i];
      positions[i + 1] += this.velocities[i + 1];
      positions[i + 2] += this.velocities[i + 2];
    }

    this.particles.geometry.attributes.position.needsUpdate = true;

    // 透明度を徐々に下げる
    this.particles.material.opacity -= 0.01;

    // 完全に透明になったら削除
    return this.particles.material.opacity > 0;
  }

  dispose() {
    this.scene.remove(this.particles);
    this.particles.geometry.dispose();
    this.particles.material.dispose();
  }
}

window.ParticleSystem = ParticleSystem;
```

#### Task 3.3: パーティクルをカメラ移動時に表示

**ファイル**: `web/three_gacha_scene.js`

クラスに`particleSystems`配列を追加：

```javascript
constructor(canvas) {
  // ... 既存のコード ...
  this.particleSystems = [];  // ← 追加
}
```

`moveToOrb`メソッドを修正：

```javascript
moveToOrb(index, onComplete) {
  if (index >= this.orbs.length) {
    console.error('存在しないインデックスです:', index);
    return;
  }

  const targetOrb = this.orbs[index];
  const targetPosition = targetOrb.position.clone();

  // ★ パーティクルを生成
  const particles = new ParticleSystem(
    this.scene,
    targetPosition,
    targetOrb.userData.originalColor,
    30
  );
  this.particleSystems.push(particles);

  // カメラ移動
  const cameraDistance = 3;
  const direction = targetPosition.clone().normalize();
  const cameraTarget = direction.multiplyScalar(cameraDistance);

  this.animateCameraMove(cameraTarget, targetPosition, onComplete);
}
```

`startAnimation`メソッド内でパーティクルを更新：

```javascript
startAnimation() {
  const animate = () => {
    this.animationFrameId = requestAnimationFrame(animate);

    // 光の玉を浮遊
    this.orbs.forEach((orb, index) => {
      orb.position.y = Math.sin(Date.now() * 0.001 + index) * 0.2;
      
      // ライトも同期
      if (orb.userData.light) {
        orb.userData.light.position.copy(orb.position);
      }
    });

    // ★ パーティクルを更新
    this.particleSystems = this.particleSystems.filter(ps => ps.update());

    this.renderer.render(this.scene, this.camera);
  };

  animate();
}
```

#### Task 3.4: フォーカス時の玉の強調表示

**ファイル**: `web/three_gacha_scene.js`

`moveToOrb`メソッドに追加：

```javascript
moveToOrb(index, onComplete) {
  if (index >= this.orbs.length) return;

  const targetOrb = this.orbs[index];
  const targetPosition = targetOrb.position.clone();

  // ★ 玉のサイズを拡大
  const originalScale = targetOrb.scale.clone();
  this.animateOrbScale(targetOrb, 1.5, 500); // 1.5倍に拡大

  // ★ ライトの強度を上げる
  if (targetOrb.userData.light) {
    targetOrb.userData.light.intensity = 5;
  }

  // パーティクル生成
  const particles = new ParticleSystem(
    this.scene,
    targetPosition,
    targetOrb.userData.originalColor,
    30
  );
  this.particleSystems.push(particles);

  // カメラ移動
  const cameraDistance = 3;
  const direction = targetPosition.clone().normalize();
  const cameraTarget = direction.multiplyScalar(cameraDistance);

  this.animateCameraMove(cameraTarget, targetPosition, () => {
    // 移動完了後、サイズを元に戻す
    this.animateOrbScale(targetOrb, 1.0, 500);
    if (targetOrb.userData.light) {
      targetOrb.userData.light.intensity = 2;
    }
    if (onComplete) onComplete();
  });
}

/**
 * 玉のスケールをアニメーション
 */
animateOrbScale(orb, targetScale, duration) {
  const startScale = orb.scale.x;
  const startTime = Date.now();

  const animate = () => {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(elapsed / duration, 1);

    const eased = progress < 0.5
      ? 2 * progress * progress
      : 1 - Math.pow(-2 * progress + 2, 2) / 2;

    const currentScale = startScale + (targetScale - startScale) * eased;
    orb.scale.set(currentScale, currentScale, currentScale);

    if (progress < 1) {
      requestAnimationFrame(animate);
    }
  };

  animate();
}
```

---

### フェーズ4: 昇格演出の拡張構造（2時間）

**注意**: 昇格演出は将来実装予定ですが、拡張しやすい構造を今のうちに作成します。

#### Task 4.1: 演出コンテナの実装

**新規ファイル**: `web/three_effect_container.js`

```javascript
/**
 * エフェクトコンテナ
 * 各玉の演出を管理し、昇格演出を差し替え可能にする
 */
class EffectContainer {
  constructor(orb, scene) {
    this.orb = orb;
    this.scene = scene;
    this.currentEffect = null;
  }

  /**
   * 通常演出を再生
   */
  playNormalEffect() {
    // パーティクルを生成
    const particles = new ParticleSystem(
      this.scene,
      this.orb.position,
      this.orb.userData.originalColor,
      30
    );
    this.currentEffect = particles;
    return particles;
  }

  /**
   * 昇格演出を再生（将来実装）
   * @param {string} newColor - 昇格後の色
   * @param {Function} onComplete - 完了コールバック
   */
  playUpgradeEffect(newColor, onComplete) {
    // TODO: 将来実装
    // - 玉が激しく点滅
    // - 色が変化
    // - 波紋エフェクト
    // - 他の玉に影響を与える連鎖エフェクト
    
    console.log('昇格演出（未実装）:', newColor);
    
    // 仮実装: 色を変更
    this.orb.material.color = new THREE.Color(newColor);
    this.orb.material.emissive = new THREE.Color(newColor);
    this.orb.userData.originalColor = newColor;
    
    if (onComplete) onComplete();
  }

  /**
   * エフェクトをクリーンアップ
   */
  dispose() {
    if (this.currentEffect && this.currentEffect.dispose) {
      this.currentEffect.dispose();
    }
  }
}

window.EffectContainer = EffectContainer;
```

#### Task 4.2: Three.jsシーンに統合

**ファイル**: `web/three_gacha_scene.js`

`createOrbs`メソッドを修正：

```javascript
createOrbs(orbDataList) {
  const radius = 5;
  const count = orbDataList.length;

  orbDataList.forEach((data, index) => {
    const angle = (index / count) * Math.PI * 2;
    const x = Math.cos(angle) * radius;
    const z = Math.sin(angle) * radius;

    const geometry = new THREE.SphereGeometry(0.5, 16, 16);
    const material = new THREE.MeshStandardMaterial({
      color: new THREE.Color(data.color),
      emissive: new THREE.Color(data.color),
      emissiveIntensity: 0.8
    });

    const orb = new THREE.Mesh(geometry, material);
    orb.position.set(x, 0, z);

    const light = new THREE.PointLight(
      new THREE.Color(data.color),
      2,
      10
    );
    light.position.copy(orb.position);
    this.scene.add(light);

    // ★ エフェクトコンテナを作成
    const effectContainer = new EffectContainer(orb, this.scene);

    orb.userData = {
      index: index,
      rarityName: data.rarityName,
      originalColor: data.color,
      light: light,
      effectContainer: effectContainer  // ← 追加
    };

    this.scene.add(orb);
    this.orbs.push(orb);
  });
}
```

`moveToOrb`でエフェクトコンテナを使用：

```javascript
moveToOrb(index, onComplete) {
  if (index >= this.orbs.length) return;

  const targetOrb = this.orbs[index];
  const targetPosition = targetOrb.position.clone();

  // 玉のサイズ拡大
  this.animateOrbScale(targetOrb, 1.5, 500);

  // ライト強度アップ
  if (targetOrb.userData.light) {
    targetOrb.userData.light.intensity = 5;
  }

  // ★ エフェクトコンテナ経由で演出再生
  const effect = targetOrb.userData.effectContainer.playNormalEffect();
  this.particleSystems.push(effect);

  // カメラ移動
  const cameraDistance = 3;
  const direction = targetPosition.clone().normalize();
  const cameraTarget = direction.multiplyScalar(cameraDistance);

  this.animateCameraMove(cameraTarget, targetPosition, () => {
    this.animateOrbScale(targetOrb, 1.0, 500);
    if (targetOrb.userData.light) {
      targetOrb.userData.light.intensity = 2;
    }
    if (onComplete) onComplete();
  });
}
```

#### Task 4.3: デバッグモードの実装

**ファイル**: `web/three_gacha_scene.js`

クラスに以下を追加：

```javascript
/**
 * デバッグモード: 特定の玉で昇格演出を強制発動
 * @param {number} orbIndex - 昇格させる玉のインデックス
 * @param {string} newColor - 昇格後の色（例: '#FFC107'）
 */
debugTriggerUpgrade(orbIndex, newColor) {
  if (orbIndex >= this.orbs.length) {
    console.error('無効なインデックス:', orbIndex);
    return;
  }

  const targetOrb = this.orbs[orbIndex];
  
  console.log(`デバッグ: 玉 ${orbIndex} を昇格`);
  
  targetOrb.userData.effectContainer.playUpgradeEffect(newColor, () => {
    console.log('昇格演出完了');
  });
}
```

**Dart側でデバッグモードを呼び出す**:

`lib/gacha/animations/three_scene_manager.dart`に追加：

```dart
/// デバッグ: 昇格演出をテスト
void debugTriggerUpgrade(int orbIndex, String newColor) {
  _sceneController?.callMethod('debugTriggerUpgrade', [orbIndex, newColor]);
}
```

**使用例** (開発時のみ):
```dart
// 0番目の玉を金色に昇格
_sceneManager.debugTriggerUpgrade(0, '#FFC107');
```

---

### フェーズ5: 最終調整とパフォーマンス最適化（2時間）

#### Task 5.1: HTMLファイルの読み込み設定

**ファイル**: `web/index.html`

`<head>`タグ内に以下を追加：

```html
<!-- Three.js -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>

<!-- カスタムスクリプト -->
<script src="three_gacha_scene.js" defer></script>
<script src="three_particle_system.js" defer></script>
<script src="three_effect_container.js" defer></script>
```

#### Task 5.2: パフォーマンス最適化

**ファイル**: `web/three_gacha_scene.js`

以下の最適化を実施：

```javascript
initScene() {
  // ... 既存のコード ...

  // ★ レンダラーの最適化設定
  this.renderer = new THREE.WebGLRenderer({
    canvas: this.canvas,
    antialias: window.devicePixelRatio < 2, // 高DPIではアンチエイリアス無効
    alpha: true,
    powerPreference: 'high-performance'  // パフォーマンス優先
  });

  // ★ シャドウは無効（重いため）
  this.renderer.shadowMap.enabled = false;

  // ★ デバイスピクセル比の上限設定
  this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
}
```

**パーティクル数の削減** (モバイル対応):

```javascript
createParticles(position, color, count) {
  // ★ デバイスに応じてパーティクル数を調整
  const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
  const particleCount = isMobile ? Math.floor(count / 2) : count;

  // ... 既存のコード（countをparticleCountに変更）...
}
```

#### Task 5.3: メモリリークの防止

**ファイル**: `web/three_gacha_scene.js`

`dispose`メソッドを強化：

```javascript
dispose() {
  // アニメーションフレームをキャンセル
  if (this.animationFrameId) {
    cancelAnimationFrame(this.animationFrameId);
  }

  // パーティクルシステムを破棄
  this.particleSystems.forEach(ps => ps.dispose());
  this.particleSystems = [];

  // 玉とライトを破棄
  this.orbs.forEach(orb => {
    orb.geometry.dispose();
    orb.material.dispose();
    
    if (orb.userData.light) {
      this.scene.remove(orb.userData.light);
    }
    
    if (orb.userData.effectContainer) {
      orb.userData.effectContainer.dispose();
    }
  });

  // レンダラーを破棄
  this.renderer.dispose();

  // イベントリスナーを削除
  window.removeEventListener('resize', this.onWindowResize);

  console.log('Three.jsシーンを破棄しました');
}
```

#### Task 5.4: エラーハンドリング

**ファイル**: `lib/gacha/animations/three_gacha_animation_screen.dart`

初期化時のエラーハンドリングを追加：

```dart
Future<void> _initializeScene() async {
  try {
    _canvas = html.CanvasElement()
      ..width = html.window.innerWidth!
      ..height = html.window.innerHeight!;

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'three-gacha-canvas',
      (int viewId) => _canvas,
    );

    _sceneManager = ThreeSceneManager();
    await _sceneManager.initialize(_canvas);

    final orbData = widget.itemsWithStatus.map((itemWithStatus) {
      final item = itemWithStatus.item;
      return {
        'color': '#${item.rarity.color.value.toRadixString(16).substring(2)}',
        'rarityName': item.rarity.name,
      };
    }).toList();

    _sceneManager.createOrbs(orbData);
    _sceneManager.startAnimation();

    setState(() {
      _isInitialized = true;
    });
  } catch (e) {
    print('Three.jsシーン初期化エラー: $e');
    
    // エラー時はフォールバック（既存のアニメーション画面へ）
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiGachaAnimationScreen(
            itemsWithStatus: widget.itemsWithStatus,
            config: widget.config,
          ),
        ),
      );
    }
  }
}
```

---

## テスト計画

### テストケース一覧

| ID | テスト項目 | 期待結果 | 優先度 |
|----|----------|---------|--------|
| T1 | 10連ガチャ実行後にThree.js画面が表示される | 黒背景に光の玉が円周上に配置 | 高 |
| T2 | タップで最初の玉にカメラが移動 | 滑らかに移動、パーティクル表示 | 高 |
| T3 | 連続タップで全ての玉を巡回 | カメラが順番に移動 | 高 |
| T4 | 全ての玉を見終わると結果画面へ遷移 | SequentialGachaFlowScreenが表示 | 高 |
| T5 | レアリティに応じた色が正しく表示される | 各玉の色がレアリティ色と一致 | 中 |
| T6 | モバイル端末でも動作する | iPhone/Androidで正常動作 | 高 |
| T7 | メモリリークがない | 画面を閉じた後もメモリが増加しない | 中 |
| T8 | デバッグモードで昇格演出が発動 | 玉の色が変化 | 低 |

### テスト手順

#### 手順1: 基本動作確認

1. アプリを起動し、ガチャ画面へ移動
2. 10連ガチャを実行（900コイン消費）
3. Three.js画面が表示されることを確認
4. 光の玉が10個、円周上に配置されていることを確認
5. 画面をタップ
6. カメラが最初の玉に移動することを確認
7. 連続でタップし、全ての玉を巡回
8. 最後のタップ後、結果画面に遷移することを確認

#### 手順2: レアリティ色の確認

1. 各玉の色が以下と一致するか確認：
   - コモン: グレー (#9E9E9E)
   - レア: ブルー (#2196F3)
   - 激レア: パープル (#9C27B0)
   - 超激レア: イエロー (#FFC107)
   - OWN_CHIN: ピンク (#E91E63)

#### 手順3: パフォーマンス確認

1. Chrome DevToolsを開く（F12）
2. Performance タブで記録開始
3. 10連ガチャを実行
4. アニメーション完了まで記録
5. FPS が 30fps 以上を維持していることを確認
6. Memory タブでメモリリークがないことを確認

---

## トラブルシューティング

### 問題1: Three.jsが読み込まれない

**症状**: コンソールに「THREE is not defined」エラー

**原因**: CDNからのスクリプト読み込み失敗

**解決策**:
1. `web/index.html`で以下を確認：
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
```
2. ネットワーク接続を確認
3. CDNが利用可能か確認（別ブラウザで直接アクセス）

---

### 問題2: 画面が真っ黒のまま

**症状**: Three.js画面が表示されるが、何も見えない

**原因**: カメラ位置またはライティングの問題

**解決策**:
1. ブラウザのコンソールを開き、エラーを確認
2. `three_gacha_scene.js`の`initScene`でカメラ位置を確認：
```javascript
this.camera.position.z = 10; // 値を大きくしてみる
```
3. 環境光の強度を上げてみる：
```javascript
const ambientLight = new THREE.AmbientLight(0xffffff, 1.0); // 0.3 → 1.0
```

---

### 問題3: カメラが移動しない

**症状**: タップしてもカメラが動かない

**原因**: Dart ↔ JavaScript連携の問題

**解決策**:
1. コンソールで以下を確認：
```javascript
console.log(window.ThreeGachaScene); // undefinedでないか確認
```
2. `three_gacha_scene.js`が正しく読み込まれているか確認
3. `three_scene_manager.dart`の`moveToNextOrb`にログを追加：
```dart
Future<void> moveToNextOrb(int index) async {
  print('moveToNextOrb called: $index');
  // ... 既存のコード ...
}
```

---

### 問題4: パーティクルが表示されない

**症状**: カメラは移動するが、パーティクルが見えない

**原因**: パーティクルのサイズまたは色の問題

**解決策**:
1. `three_particle_system.js`でサイズを大きくする：
```javascript
const material = new THREE.PointsMaterial({
  color: new THREE.Color(color),
  size: 0.3,  // 0.1 → 0.3
  transparent: true,
  opacity: 1.0  // 0.8 → 1.0
});
```

---

### 問題5: モバイルで動作が重い

**症状**: スマートフォンでFPSが低い

**原因**: パーティクル数やポリゴン数が多すぎる

**解決策**:
1. 球体のポリゴン数を削減：
```javascript
const geometry = new THREE.SphereGeometry(0.5, 8, 8); // 16 → 8
```
2. パーティクル数を削減（Task 5.2参照）
3. ライトの数を削減（全体で1つの環境光のみにする）

---

### 問題6: メモリリークが発生

**症状**: アニメーション終了後もメモリ使用量が高い

**原因**: リソースの破棄漏れ

**解決策**:
1. `dispose`メソッドが正しく呼ばれているか確認
2. ブラウザのMemoryプロファイラで確認
3. 各Geometryとmaterialが確実に破棄されているか確認

---

## 実装チェックリスト

実装者は以下をチェックしてください：

### フェーズ0
- [ ] `pubspec.yaml`にアセットパス追加
- [ ] `assets/gacha/three_gacha_scene.html`作成（参考用）

### フェーズ1
- [ ] `three_scene_manager.dart`作成
- [ ] `web/three_gacha_scene.js`作成
- [ ] `three_gacha_animation_screen.dart`作成
- [ ] `gacha_screen.dart`の遷移先を変更

### フェーズ2
- [ ] カメラ移動機能実装（JS側）
- [ ] タップ操作実装（Dart側）
- [ ] 結果画面への遷移実装

### フェーズ3
- [ ] グローエフェクト実装
- [ ] `three_particle_system.js`作成
- [ ] パーティクル表示実装
- [ ] フォーカス時の強調表示実装

### フェーズ4
- [ ] `three_effect_container.js`作成
- [ ] エフェクトコンテナ統合
- [ ] デバッグモード実装

### フェーズ5
- [ ] `web/index.html`にスクリプト追加
- [ ] パフォーマンス最適化
- [ ] メモリリーク対策
- [ ] エラーハンドリング追加

### テスト
- [ ] 全テストケース実行
- [ ] モバイル端末で動作確認
- [ ] メモリプロファイリング

---

## 完成後の確認事項

実装完了後、以下を確認してください：

1. ✅ 10連ガチャ実行後に3Dアニメーションが表示される
2. ✅ タップで各玉を順番に見ることができる
3. ✅ レアリティに応じた色で表示される
4. ✅ パーティクルエフェクトが表示される
5. ✅ 全ての玉を見終わると結果画面に遷移する
6. ✅ モバイル端末でも動作する
7. ✅ メモリリークがない
8. ✅ 昇格演出用の拡張構造が実装されている

---

## 補足: 昇格演出の実装（将来対応）

昇格演出を実装する際は、以下の手順で進めてください：

### ステップ1: 昇格ロジックの実装

`web/three_effect_container.js`の`playUpgradeEffect`メソッドを実装：

```javascript
playUpgradeEffect(newColor, onComplete) {
  // 1. 玉を激しく点滅させる
  let blinkCount = 0;
  const blinkInterval = setInterval(() => {
    this.orb.material.emissiveIntensity = 
      blinkCount % 2 === 0 ? 1.5 : 0.5;
    blinkCount++;
    
    if (blinkCount > 10) {
      clearInterval(blinkInterval);
      
      // 2. 色を変更
      this.orb.material.color = new THREE.Color(newColor);
      this.orb.material.emissive = new THREE.Color(newColor);
      this.orb.userData.originalColor = newColor;
      
      // 3. 波紋エフェクト
      this.createRippleEffect(newColor);
      
      if (onComplete) onComplete();
    }
  }, 100);
}

createRippleEffect(color) {
  // TODO: 波紋エフェクトの実装
  // リング状のジオメトリを作成し、外側に拡大していくアニメーション
}
```

### ステップ2: 昇格判定の追加

Dart側で昇格判定ロジックを実装し、該当する玉でのみ昇格演出を再生。

---

## まとめ

このロードマップに従って実装することで、以下が実現できます：

- ✅ **没入感のある3Dガチャ演出**
- ✅ **レアリティに応じた視覚的フィードバック**
- ✅ **将来の昇格演出拡張に対応した設計**
- ✅ **モバイル端末でも動作するパフォーマンス**

実装中に不明点があれば、各フェーズの説明を再度確認してください。
頑張ってください！
    