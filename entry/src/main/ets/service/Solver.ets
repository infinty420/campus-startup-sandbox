/**
 * 求解器：目标反推（数值解）+ 预算组合优化（0/1 背包 DP）
 */
import { Plan } from '../model/PlanV2';
import { simulate } from './SimEngine';

/** 首月经营利润关于日均单量（线性，忽略阈值规则） */
function month1ProfitAtOrders(plan: Plan, orders: number): number {
  const days = plan.daysPerMonth;
  let perUnit = 0;
  let fixed = 0;
  for (const c of plan.costItems) {
    if (c.kind === 'perUnit') {
      perUnit += c.amount;
    } else if (c.kind === 'monthly') {
      fixed += c.amount;
    } else if (c.kind === 'amortized' && c.amortMonths > 0) {
      fixed += c.amount / c.amortMonths;
    }
  }
  return (plan.unitPrice - perUnit) * orders * days - fixed;
}

/** 反推：目标首月利润所需日均单量；-1 = 无法达成（单位毛利 ≤ 0） */
export function solveOrdersForProfit(plan: Plan, targetProfit: number): number {
  let perUnit = 0;
  for (const c of plan.costItems) {
    if (c.kind === 'perUnit') {
      perUnit += c.amount;
    }
  }
  const unitMargin = plan.unitPrice - perUnit;
  if (unitMargin <= 0 || plan.daysPerMonth <= 0) {
    return -1;
  }
  let fixed = 0;
  for (const c of plan.costItems) {
    if (c.kind === 'monthly') {
      fixed += c.amount;
    } else if (c.kind === 'amortized' && c.amortMonths > 0) {
      fixed += c.amount / c.amortMonths;
    }
  }
  const need = (targetProfit + fixed) / (unitMargin * plan.daysPerMonth);
  return need > 0 ? need : 0;
}

/** 反推：目标首月利润所需客单价（闭式解）；-1 = 无法计算 */
export function solvePriceForProfit(plan: Plan, targetProfit: number): number {
  const denom = plan.dailyOrders * plan.daysPerMonth;
  if (denom <= 0) {
    return -1;
  }
  let perUnit = 0;
  let fixed = 0;
  for (const c of plan.costItems) {
    if (c.kind === 'perUnit') {
      perUnit += c.amount;
    } else if (c.kind === 'monthly') {
      fixed += c.amount;
    } else if (c.kind === 'amortized' && c.amortMonths > 0) {
      fixed += c.amount / c.amortMonths;
    }
  }
  return (targetProfit + fixed) / denom + perUnit;
}

/** 盈亏平衡最低客单价 */
export function minBreakEvenPrice(plan: Plan): number {
  return solvePriceForProfit(plan, 0);
}

/** 反推：目标回本月数所需日均单量（数值二分，含完整 12 月推演）；-1 = 无法达成 */
export function solveOrdersForPayback(plan: Plan, targetMonths: number): number {
  if (targetMonths < 1 || targetMonths > 12) {
    return -1;
  }
  let perUnit = 0;
  for (const c of plan.costItems) {
    if (c.kind === 'perUnit') {
      perUnit += c.amount;
    }
  }
  if (plan.unitPrice - perUnit <= 0) {
    return -1;
  }
  const paybackAt = (orders: number): number => {
    const p: Plan = {
      id: plan.id, version: plan.version, name: plan.name, type: plan.type, note: plan.note,
      unitPrice: plan.unitPrice, dailyOrders: orders, daysPerMonth: plan.daysPerMonth,
      monthlyGrowthRate: plan.monthlyGrowthRate, churnRate: plan.churnRate,
      seasonCurve: plan.seasonCurve, costItems: plan.costItems, selfFunds: plan.selfFunds,
      loan: plan.loan, staged: plan.staged, stopLossMonths: plan.stopLossMonths,
      thresholds: plan.thresholds, staffCount: plan.staffCount, areaSqm: plan.areaSqm
    };
    return simulate(p).paybackMonths;
  };
  // 上界探测：扩大到 12 个月内能转正或放弃
  let hi = Math.max(plan.dailyOrders, 1);
  let found = false;
  for (let k = 0; k < 30; k++) {
    const pb = paybackAt(hi);
    if (pb > 0 && pb <= targetMonths) {
      found = true;
      break;
    }
    if (hi > 1e7) {
      break;
    }
    hi *= 2;
  }
  if (!found) {
    return -1;
  }
  let lo = 0;
  for (let it = 0; it < 60; it++) {
    const mid = (lo + hi) / 2;
    const pb = paybackAt(mid);
    if (pb > 0 && pb <= targetMonths) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

export interface ComboResult {
  selected: boolean[];
  totalProfit: number;
  totalCost: number;
  budget: number;
}

/**
 * 预算组合优化：0/1 背包（以 100 元为刻度离散化）
 * 目标：启动投入合计 ≤ 预算 的前提下，月利润总和最大
 */
export function optimizeCombo(plans: Plan[], budget: number): ComboResult {
  const n = plans.length;
  const selected: boolean[] = [];
  for (let i = 0; i < n; i++) {
    selected.push(false);
  }
  if (n === 0 || budget <= 0) {
    return { selected: selected, totalProfit: 0, totalCost: 0, budget: budget };
  }
  const cap = Math.floor(budget / 100);
  // dp[j] = 容量 j 下最大月利润
  const dp: number[] = [];
  for (let j = 0; j <= cap; j++) {
    dp.push(0);
  }
  // keep[i][j] = 是否选了第 i 件
  const keep: boolean[][] = [];
  for (let i = 0; i < n; i++) {
    const row: boolean[] = [];
    for (let j = 0; j <= cap; j++) {
      row.push(false);
    }
    keep.push(row);
  }
  for (let i = 0; i < n; i++) {
    const profit = simulate(plans[i]).monthlyProfit;
    const w = Math.ceil(simulate(plans[i]).startupTotal / 100);
    if (profit <= 0 || w <= 0) {
      continue; // 亏损方案不选；无启动成本的正利润方案后面兜底单独评估
    }
    for (let j = cap; j >= w; j--) {
      const cand = dp[j - w] + profit;
      if (cand > dp[j]) {
        dp[j] = cand;
        keep[i][j] = true;
      }
    }
  }
  // 回溯选择
  let j = cap;
  for (let i = n - 1; i >= 0; i--) {
    if (keep[i][j]) {
      selected[i] = true;
      const w = Math.ceil(simulate(plans[i]).startupTotal / 100);
      j -= w;
    }
  }
  // 兜底：零成本正利润方案（背包里 weight=0 被跳过的）
  for (let i = 0; i < n; i++) {
    if (!selected[i]) {
      const profit = simulate(plans[i]).monthlyProfit;
      const w = Math.ceil(simulate(plans[i]).startupTotal / 100);
      if (profit > 0 && w <= 0) {
        selected[i] = true;
      }
    }
  }
  let totalProfit = 0;
  let totalCost = 0;
  for (let i = 0; i < n; i++) {
    if (selected[i]) {
      totalProfit += simulate(plans[i]).monthlyProfit;
      totalCost += simulate(plans[i]).startupTotal;
    }
  }
  return { selected: selected, totalProfit: totalProfit, totalCost: totalCost, budget: budget };
}
