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
    this.particleSystems = [];
    this.introAnimation = { startTime: Date.now(), duration: 2000 }; // ms
    
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
    // For portrait screens, pull the camera back to fit the width
    const aspect = window.innerWidth / window.innerHeight;
    if (aspect < 1) {
      this.camera.position.z = 10 / aspect;
    } else {
      this.camera.position.z = 10;
    }

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
    this.renderer.setSize(window.innerWidth, window.innerHeight);

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

  clearOrbs() {
    // Dispose and remove old orbs and lights
    this.orbs.forEach(orb => {
      orb.geometry.dispose();
      orb.material.dispose();
      
      if (orb.userData.light) {
        this.scene.remove(orb.userData.light);
      }
      
      if (orb.userData.effectContainer) {
        orb.userData.effectContainer.dispose();
      }
      this.scene.remove(orb); // Also remove the orb mesh itself
    });
    this.orbs = []; // Clear the array
  }

  /**
   * 光の玉を作成
   * @param {Array} orbDataList - [{color: '#FF0000', rarityName: 'レア'}, ...]
   */
  createOrbs(orbDataList, isIntro) {
    this.clearOrbs(); // Call clear first

    const radius = 5;
    const count = orbDataList.length;

    orbDataList.forEach((data, index) => {
      const angle = (index / count) * Math.PI * 2;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius;
      const targetY = -z * 0.4; // Calculated target Y for tilt

      const geometry = new THREE.SphereGeometry(0.5, 16, 16);
      let material;
      let light = null;

      if (data.isOpened) {
        // Style for opened orbs
        material = new THREE.MeshStandardMaterial({ color: 0x333333, transparent: true, opacity: 0.5 });
      } else if (data.rarityName === 'コモン') {
        // Common orb: Basic, non-reflective material (dark white)
        material = new THREE.MeshBasicMaterial({
          color: new THREE.Color("#BDBDBD")
        });
      } else {
        // Rarer orbs: Glowing material
        material = new THREE.MeshStandardMaterial({
          color: new THREE.Color(0x000000),
          emissive: new THREE.Color(data.color),
          emissiveIntensity: 1.5
        });
        light = new THREE.PointLight(new THREE.Color(data.color), 2, 10);
      }

      const orb = new THREE.Mesh(geometry, material);
      const initialY = isIntro ? 20 : targetY;
      orb.position.set(x, initialY, z);

      if (light) {
        light.position.copy(orb.position);
        this.scene.add(light);
      }

      const effectContainer = new EffectContainer(orb, this.scene);

      orb.userData = {
        index: index,
        rarityName: data.rarityName,
        originalColor: data.color,
        light: light,
        effectContainer: effectContainer,
        targetY: targetY,
        introDelay: Math.random() * 500,
      };

      this.scene.add(orb);
      this.orbs.push(orb);
    });
  }

  /**
   * 指定したインデックスの玉にカメラを移動
   * @param {number} index - 移動先の玉のインデックス
   * @param {Function} onComplete - 移動完了時のコールバック
   */
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

    // ★ エフェクトコンテナ経由で演出再生
    const effect = targetOrb.userData.effectContainer.playNormalEffect();
    this.particleSystems.push(effect);

    // カメラ移動
    const aspect = window.innerWidth / window.innerHeight;
    let cameraDistance = 8;
    if (aspect < 1) {
      cameraDistance = 8 / aspect;
    }
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

  /**
   * カメラアニメーション（滑らかな移動）
   */
  animateCameraMove(targetPos, lookAtPos, onComplete) {
    const duration = 1000; // 1秒
    const startPos = this.camera.position.clone();
    const startTime = Date.now();
    const startLookAt = new THREE.Vector3(0, 0, 0); // Assume we start by looking at the center
    const tempLookAt = new THREE.Vector3();

    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);

      // イージング関数（ease-in-out）
      const eased = progress < 0.5
        ? 2 * progress * progress
        : 1 - Math.pow(-2 * progress + 2, 2) / 2;

      // 位置を補間
      this.camera.position.lerpVectors(startPos, targetPos, eased);
      
      // 見る位置も補間
      tempLookAt.lerpVectors(startLookAt, lookAtPos, eased);
      this.camera.lookAt(tempLookAt);

      if (progress < 1) {
        requestAnimationFrame(animate);
      } else {
        if (onComplete) onComplete();
      }
    };

    animate();
  }

  /**
   * アニメーションループを開始
   */
  startAnimation(isIntro) {
    const animate = () => {
      this.animationFrameId = requestAnimationFrame(animate);
      const now = Date.now();
      const introElapsedTime = now - this.introAnimation.startTime;

      // Animate orbs
      this.orbs.forEach((orb, index) => {
        let y;
        // Only run intro animation if isIntro is true
        if (isIntro && introElapsedTime < this.introAnimation.duration + orb.userData.introDelay) {
          const orbElapsedTime = Math.max(0, introElapsedTime - orb.userData.introDelay);
          const progress = Math.min(orbElapsedTime / (this.introAnimation.duration - 500), 1);
          // Ease-out quint function
          const easedProgress = 1 - Math.pow(1 - progress, 5);
          y = 20 + (orb.userData.targetY - 20) * easedProgress;
        } else {
          // Gentle floating animation after intro
          const floatTime = now * 0.001 + index;
          y = orb.userData.targetY + Math.sin(floatTime) * 0.2;
        }
        orb.position.y = y;
        
        // Sync light position
        if (orb.userData.light) {
          orb.userData.light.position.copy(orb.position);
        }
      });

      // Update particle systems
      this.particleSystems = this.particleSystems.filter(ps => ps.update());

      this.renderer.render(this.scene, this.camera);
    };

    animate();
  }

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

  /**
   * クリーンアップ
   */
  dispose() {
    // アニメーションフレームをキャンセル
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }

    // パーティクルシステムを破棄
    this.particleSystems.forEach(ps => ps.dispose());
    this.particleSystems = [];

    this.clearOrbs(); // Use the new method

    // レンダラーを破棄
    this.renderer.dispose();

    // イベントリスナーを削除
    window.removeEventListener('resize', this.onWindowResize);

    console.log('Three.jsシーンを破棄しました');
  }
}

// グローバルに公開（Dartから呼び出せるようにする）
window.ThreeGachaScene = ThreeGachaScene;
window.threeGachaSceneReady = true;
