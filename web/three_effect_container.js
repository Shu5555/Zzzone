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
