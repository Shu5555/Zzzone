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
    // ★ デバイスに応じてパーティクル数を調整
    const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
    const particleCount = isMobile ? Math.floor(count / 2) : count;

    const geometry = new THREE.BufferGeometry();
    const positions = [];
    const velocities = [];

    // パーティクルの初期位置と速度をランダム生成
    for (let i = 0; i < particleCount; i++) {
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
