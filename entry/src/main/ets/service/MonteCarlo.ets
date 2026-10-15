/**
 * 蒙特卡洛仿真（本地随机抽样，不联网）
 * - 客单价 / 日均订单量：三角分布(min, 最可能, max)，可用高斯 Copula 引入负相关
 * - 单位变动成本：均匀扰动 ±x%
 * - 输出：12 月末现金分位数、亏损/回本概率、直方图、方差贡献敏感度
 */
import { Plan, CostItem } from '../model/PlanV2';
import { simulate } from './SimEngine';

export interface McConfig {
  priceEnabled: boolean;
  priceMin: number;
  priceMode: number;
  priceMax: number;
  ordersEnabled: boolean;
  ordersMin: number;
  ordersMode: number;
  ordersMax: number;
  costEnabled: boolean;
  costJitter: number;   // 变动成本 ±%
  correlation: number;  // 客单价与订单量的相关系数（负值 = 价格敏感）
  runs: number;
}

export interface SensitivityItem {
  name: string;
  share: number; // %
}

export interface McResult {
  runs: number;
  cashP5: number;
  cashP50: number;
  cashP95: number;
  profitP5: number;
  profitP50: number;
  profitP95: number;
  lossProb: number;    // 12 月末现金 < 0 的概率 %
  paybackProb: number; // 12 月内现金转正的概率 %
  histBins: number[];  // 12 月末现金直方图（20 桶）
  histStart: number;
  histStep: number;
  sensitivity: SensitivityItem[];
}

/** 可复现的伪随机数（mulberry32） */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return (): number => {
    a = (a + 0x6D2B79F5) | 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Box-Muller 标准正态 */
function stdNormal(rng: () => number): number {
  const u1 = Math.max(rng(), 1e-12);
  const u2 = rng();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

/** 标准正态 CDF 近似（Abramowitz-Stegun） */
function phi(x: number): number {
  const t = 1 / (1 + 0.2316419 * Math.abs(x));
  const d = 0.3989423 * Math.exp(-x * x / 2);
  let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  if (x > 0) {
    return 1 - p;
  }
  return p;
}

/** 三角分布逆采样 */
function triInv(u: number, a: number, c: number, b: number): number {
  if (b <= a) {
    return Math.max(a, c);
  }
  const fc = (c - a) / (b - a);
  if (u < fc) {
    return a + Math.sqrt(u * (b - a) * (c - a));
  }
  return b - Math.sqrt((1 - u) * (b - a) * (b - c));
}

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) {
    return 0;
  }
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.round(p * (sorted.length - 1))));
  return sorted[idx];
}

function pearson(xs: number[], ys: number[]): number {
  const n = Math.min(xs.length, ys.length);
  if (n < 2) {
    return 0;
  }
  let mx = 0;
  let my = 0;
  for (let i = 0; i < n; i++) {
    mx += xs[i];
    my += ys[i];
  }
  mx /= n;
  my /= n;
  let sxy = 0;
  let sxx = 0;
  let syy = 0;
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - mx;
    const dy = ys[i] - my;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  if (sxx <= 0 || syy <= 0) {
    return 0;
  }
  return sxy / Math.sqrt(sxx * syy);
}

/** 构造抽样后的方案副本（仅替换客单价/订单量/按单成本） */
function sampledPlan(plan: Plan, price: number, orders: number, costMul: number): Plan {
  const items: CostItem[] = [];
  for (const c of plan.costItems) {
    if (c.kind === 'perUnit') {
      items.push({
        id: c.id, name: c.name, kind: c.kind, amount: c.amount * costMul,
        amortMonths: c.amortMonths, startMonth: c.startMonth, endMonth: c.endMonth
      });
    } else {
      items.push(c);
    }
  }
  return {
    id: plan.id, version: plan.version, name: plan.name, type: plan.type, note: plan.note,
    unitPrice: price, dailyOrders: orders, daysPerMonth: plan.daysPerMonth,
    monthlyGrowthRate: plan.monthlyGrowthRate, churnRate: plan.churnRate,
    seasonCurve: plan.seasonCurve, costItems: items, selfFunds: plan.selfFunds,
    loan: plan.loan, staged: plan.staged, stopLossMonths: plan.stopLossMonths,
    thresholds: plan.thresholds, staffCount: plan.staffCount, areaSqm: plan.areaSqm
  };
}

export function runMonteCarlo(plan: Plan, cfg: McConfig, seed: number): McResult {
  const rng = mulberry32(seed);
  const runs = Math.max(100, Math.min(10000, Math.floor(cfg.runs)));
  const rho = Math.max(-0.9, Math.min(0.9, cfg.correlation));

  const finalCash: number[] = [];
  const firstProfit: number[] = [];
  const xsPrice: number[] = [];
  const xsOrders: number[] = [];
  const xsCost: number[] = [];
  let lossCount = 0;
  let paybackCount = 0;

  for (let i = 0; i < runs; i++) {
    // 高斯 Copula 生成相关均匀数
    const z1 = stdNormal(rng);
    const z2 = stdNormal(rng);
    const u1 = phi(z1);
    const u2 = phi(rho * z1 + Math.sqrt(1 - rho * rho) * z2);

    const price = cfg.priceEnabled
      ? triInv(u1, cfg.priceMin, cfg.priceMode, cfg.priceMax) : plan.unitPrice;
    const orders = cfg.ordersEnabled
      ? triInv(u2, cfg.ordersMin, cfg.ordersMode, cfg.ordersMax) : plan.dailyOrders;
    const costMul = cfg.costEnabled
      ? 1 + (rng() * 2 - 1) * cfg.costJitter / 100 : 1;

    const p = sampledPlan(plan, price, orders, costMul);
    const r = simulate(p);
    finalCash.push(r.cashFlow[r.cashFlow.length - 1]);
    firstProfit.push(r.monthlyProfit);
    if (r.cashFlow[r.cashFlow.length - 1] < 0) {
      lossCount++;
    }
    if (r.paybackMonths > 0) {
      paybackCount++;
    }
    xsPrice.push(price);
    xsOrders.push(orders);
    xsCost.push(costMul);
  }

  const cashSorted = finalCash.slice().sort((a: number, b: number) => a - b);
  const profitSorted = firstProfit.slice().sort((a: number, b: number) => a - b);

  // 直方图（20 桶）
  const binCount = 20;
  let lo = cashSorted[0];
  let hi = cashSorted[cashSorted.length - 1];
  if (hi <= lo) {
    hi = lo + 1;
  }
  const step = (hi - lo) / binCount;
  const bins: number[] = [];
  for (let b = 0; b < binCount; b++) {
    bins.push(0);
  }
  for (const v of finalCash) {
    let b = Math.floor((v - lo) / step);
    if (b < 0) {
      b = 0;
    }
    if (b >= binCount) {
      b = binCount - 1;
    }
    bins[b]++;
  }

  // 敏感度：corr(输入, 12月末现金)² 归一化
  const rPrice = pearson(xsPrice, finalCash);
  const rOrders = pearson(xsOrders, finalCash);
  const rCost = pearson(xsCost, finalCash);
  const q = [rPrice * rPrice, rOrders * rOrders, rCost * rCost];
  const qSum = q[0] + q[1] + q[2];
  const sens: SensitivityItem[] = [
    { name: '客单价', share: qSum > 0 ? q[0] / qSum * 100 : 0 },
    { name: '日均订单量', share: qSum > 0 ? q[1] / qSum * 100 : 0 },
    { name: '变动成本', share: qSum > 0 ? q[2] / qSum * 100 : 0 }
  ];

  return {
    runs: runs,
    cashP5: percentile(cashSorted, 0.05),
    cashP50: percentile(cashSorted, 0.5),
    cashP95: percentile(cashSorted, 0.95),
    profitP5: percentile(profitSorted, 0.05),
    profitP50: percentile(profitSorted, 0.5),
    profitP95: percentile(profitSorted, 0.95),
    lossProb: lossCount / runs * 100,
    paybackProb: paybackCount / runs * 100,
    histBins: bins,
    histStart: lo,
    histStep: step,
    sensitivity: sens
  };
}
