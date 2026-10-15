/**
 * 决策引擎：AHP 权重（几何平均法 + 一致性检验 CR）+ TOPSIS 排序 + 结论文案
 */
import { Plan } from '../model/PlanV2';
import { simulate } from './SimEngine';

export const CRITERIA: string[] = ['盈利能力', '回本速度', '风险水平', '资金门槛', '人力占用', '场地需求'];

/** AHP 随机一致性指标 RI（n=1..10） */
const RI: number[] = [0, 0, 0.58, 0.90, 1.12, 1.24, 1.32, 1.41, 1.45, 1.49];

export interface AhpResult {
  weights: number[];
  cr: number;
  consistent: boolean;
}

/** 由两两比较矩阵（n*n 扁平，a[i*n+j]）计算权重与一致性比率 */
export function ahpWeights(matrix: number[]): AhpResult {
  const n = CRITERIA.length;
  // 几何平均法
  const geo: number[] = [];
  let sum = 0;
  for (let i = 0; i < n; i++) {
    let prod = 1;
    for (let j = 0; j < n; j++) {
      const v = matrix[i * n + j];
      prod *= v > 0 ? v : 1;
    }
    const g = Math.pow(prod, 1 / n);
    geo.push(g);
    sum += g;
  }
  const weights: number[] = [];
  for (let i = 0; i < n; i++) {
    weights.push(sum > 0 ? geo[i] / sum : 1 / n);
  }
  // λmax = (1/n) Σ (A w)_i / w_i
  let lambda = 0;
  for (let i = 0; i < n; i++) {
    let aw = 0;
    for (let j = 0; j < n; j++) {
      aw += matrix[i * n + j] * weights[j];
    }
    if (weights[i] > 0) {
      lambda += aw / weights[i];
    }
  }
  lambda /= n;
  const ci = n > 1 ? (lambda - n) / (n - 1) : 0;
  const ri = RI[n - 1];
  const cr = ri > 0 ? ci / ri : 0;
  return { weights: weights, cr: cr, consistent: cr < 0.1 };
}

/** 由权重向量生成完全一致的比较矩阵 */
export function matrixFromWeights(w: number[]): number[] {
  const n = CRITERIA.length;
  const m: number[] = [];
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      m.push(w[i] / w[j]);
    }
  }
  return m;
}

/** 预设权重档 */
export function presetWeights(profile: string): number[] {
  if (profile === '求稳') {
    return [0.8, 1.3, 1.6, 1.2, 1.0, 1.0];
  }
  if (profile === '激进') {
    return [1.8, 1.2, 0.7, 0.9, 0.7, 0.7];
  }
  return [1, 1, 1, 1, 1, 1];
}

export interface TopsisRow {
  name: string;
  score: number;   // 贴近度 0~1
  values: number[]; // 原始指标（与 CRITERIA 对齐）
}

export interface TopsisResult {
  rows: TopsisRow[];      // 按贴近度降序
  bestName: string;
}

/** TOPSIS：指标标准化 → 加权 → 正负理想解 → 贴近度 */
export function topsis(plans: Plan[], weights: number[]): TopsisResult {
  const n = CRITERIA.length;
  // 原始指标矩阵；true = 效益型（越大越好）
  const raw: number[][] = [];
  for (const p of plans) {
    const r = simulate(p);
    const payback = r.paybackMonths > 0 ? r.paybackMonths : 24;
    const riskScore = r.riskLevel === '低' ? 3 : (r.riskLevel === '中' ? 2 : 1);
    raw.push([
      r.monthlyProfit,      // 盈利能力（效益）
      -payback,             // 回本速度（成本 → 取负转为效益）
      riskScore,            // 风险水平（效益）
      -r.startupTotal,      // 资金门槛（成本 → 取负）
      -p.staffCount,        // 人力占用（成本）
      -p.areaSqm            // 场地需求（成本）
    ]);
  }
  const m = raw.length;
  if (m === 0) {
    return { rows: [], bestName: '' };
  }
  // 向量标准化
  const norm: number[][] = [];
  for (let i = 0; i < m; i++) {
    const row: number[] = [];
    for (let j = 0; j < n; j++) {
      row.push(raw[i][j]);
    }
    norm.push(row);
  }
  for (let j = 0; j < n; j++) {
    let s = 0;
    for (let i = 0; i < m; i++) {
      s += norm[i][j] * norm[i][j];
    }
    const d = Math.sqrt(s);
    if (d > 0) {
      for (let i = 0; i < m; i++) {
        norm[i][j] /= d;
      }
    }
  }
  // 加权
  for (let i = 0; i < m; i++) {
    for (let j = 0; j < n; j++) {
      norm[i][j] *= weights[j];
    }
  }
  // 正负理想解
  const best: number[] = [];
  const worst: number[] = [];
  for (let j = 0; j < n; j++) {
    let mx = norm[0][j];
    let mn = norm[0][j];
    for (let i = 1; i < m; i++) {
      if (norm[i][j] > mx) {
        mx = norm[i][j];
      }
      if (norm[i][j] < mn) {
        mn = norm[i][j];
      }
    }
    best.push(mx);
    worst.push(mn);
  }
  // 贴近度
  const rows: TopsisRow[] = [];
  for (let i = 0; i < m; i++) {
    let dPlus = 0;
    let dMinus = 0;
    for (let j = 0; j < n; j++) {
      dPlus += (norm[i][j] - best[j]) * (norm[i][j] - best[j]);
      dMinus += (norm[i][j] - worst[j]) * (norm[i][j] - worst[j]);
    }
    dPlus = Math.sqrt(dPlus);
    dMinus = Math.sqrt(dMinus);
    const score = (dPlus + dMinus) > 0 ? dMinus / (dPlus + dMinus) : 0.5;
    rows.push({ name: plans[i].name, score: score, values: raw[i] });
  }
  rows.sort((a: TopsisRow, b: TopsisRow) => b.score - a.score);
  return { rows: rows, bestName: rows.length > 0 ? rows[0].name : '' };
}

/** 规则化结论文案（全本地生成） */
export function buildConclusion(plans: Plan[], result: TopsisResult, weights: number[]): string {
  if (plans.length === 0) {
    return '尚无方案可评估，请先在首页创建或从模板生成创业方案。';
  }
  if (plans.length === 1) {
    const r = simulate(plans[0]);
    return `当前只有 1 个方案「${plans[0].name}」：月经营利润 ${r.monthlyProfit.toFixed(0)} 元，` +
      `${r.paybackMonths > 0 ? `预计第 ${r.paybackMonths} 个月现金转正` : '12 个月内现金无法转正'}，` +
      `风险评级 ${r.riskLevel}。建议再录入 1-2 个备选方案做多维对比。`;
  }
  const lines: string[] = [];
  const top = result.rows[0];
  const second = result.rows.length > 1 ? result.rows[1] : null;
  const topPlan = findPlan(plans, top.name);
  const topSim = topPlan !== null ? simulate(topPlan) : null;
  lines.push(`综合 ${CRITERIA.length} 个维度（${CRITERIA.join('、')}）的加权评估，推荐方案为「${top.name}」，综合贴近度得分 ${top.score.toFixed(3)}。`);
  if (second !== null) {
    const gap = top.score - second.score;
    if (gap < 0.05) {
      lines.push(`其与第二名「${second.name}」得分仅差 ${(gap * 100).toFixed(1)} 分（百分制），两者实力接近，建议结合启动资金与个人时间做最终选择。`);
    } else {
      lines.push(`领先第二名「${second.name}」 ${(gap * 100).toFixed(1)} 分（百分制），优势较为明确。`);
    }
  }
  if (topSim !== null) {
    if (topSim.monthlyProfit <= 0) {
      lines.push('注意：即便排名第一，该方案当前假设下月利润仍为负，应先优化成本结构或提价，再考虑启动。');
    } else {
      lines.push(`该方案月经营利润约 ${topSim.monthlyProfit.toFixed(0)} 元，启动投入 ${topSim.startupTotal.toFixed(0)} 元，` +
        `${topSim.paybackMonths > 0 ? `预计 ${topSim.paybackMonths} 个月现金转正` : '12 个月内难以回本'}，风险评级为「${topSim.riskLevel}」。`);
    }
    if (topSim.stoppedMonth > 0) {
      lines.push(`警告：按停业规则推演，该方案在第 ${topSim.stoppedMonth} 个月触发停业，需重点检查现金流。`);
    }
  }
  // 权重解读
  let maxIdx = 0;
  for (let i = 1; i < weights.length; i++) {
    if (weights[i] > weights[maxIdx]) {
      maxIdx = i;
    }
  }
  lines.push(`当前评估最看重「${CRITERIA[maxIdx]}」（权重 ${(weights[maxIdx] * 100).toFixed(1)}%），如侧重不同可在左侧调整两两比较。`);
  return lines.join('\n');
}

function findPlan(plans: Plan[], name: string): Plan | null {
  for (const p of plans) {
    if (p.name === name) {
      return p;
    }
  }
  return null;
}
