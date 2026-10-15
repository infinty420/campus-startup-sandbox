/**
 * 全局设计规范：品牌色 / 风险色 / 通用样式常量
 * 页面背景仍用 sys.color 资源保证深色模式自适应，品牌强调色为固定值。
 */

// 品牌色（靛蓝 → 紫罗兰）
export const C_BRAND: string = '#4F46E5';
export const C_BRAND_2: string = '#7C3AED';

// 语义色
export const C_GREEN: string = '#10B981';
export const C_ORANGE: string = '#F59E0B';
export const C_RED: string = '#E5484D';
export const C_GOLD: string = '#FCD34D';

// 风险评级配色（低=绿 中=橙 高=红）
export const RISK_COLOR: Record<string, string> = {
  '低': C_GREEN,
  '中': C_ORANGE,
  '高': C_RED
};

// 卡片阴影
export const CARD_SHADOW: ShadowOptions = {
  radius: 16,
  color: 'rgba(79,70,229,0.10)',
  offsetY: 6
};

// 按方案名推断类型图标
export function typeEmoji(name: string): string {
  if (name.includes('奶茶')) {
    return '🧋';
  }
  if (name.includes('打印')) {
    return '🖨️';
  }
  if (name.includes('跑腿')) {
    return '🛵';
  }
  if (name.includes('书')) {
    return '📚';
  }
  if (name.includes('家教')) {
    return '🎓';
  }
  return '💼';
}
