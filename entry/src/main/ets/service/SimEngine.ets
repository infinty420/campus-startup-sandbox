/**
 * 仿真内核：逐月推演引擎（纯函数，无 IO）
 * 管线：参数 → 季节/增长/流失 → 逐月推演（成本生效区间、摊销、阈值、融资、停业）→ 汇总指标
 */
import { Plan, CostItem } from '../model/PlanV2';

export interface MonthRow {
  month: number;       // 1..12
  coeff: number;       // 当月季节系数
  dailyOrders: number; // 当月日均单量
  revenue: number;     // 月收入
  variableCost: number; // 月变动成本
  fixedCost: number;   // 月固定成本（含摊销，不含还款）
  loanPay: number;     // 当月还款额
  invest: number;      // 当月投资支出（一次性 + 阶段追加）
  profit: number;      // 当月经营利润 = revenue - variable - fixed - loanPay
  cash: number;        // 月末累计现金（起点 0，负值即垫钱）
}

export interface SimResult {
  startupTotal: number;   // 启动投入合计（一次性 + 摊销总额 + 阶段追加）
  selfFunds: number;
  loanTotal: number;
  monthlyRevenue: number;  // 首月值（对比口径）
  monthlyVariable: number;
  monthlyFixed: number;
  monthlyProfit: number;   // 经营利润（不含还款）
  grossMargin: number;     // %
  paybackMonths: number;   // 现金流转正月，-1 = 12 个月内未转正
  breakEvenDailyOrders: number; // 首月口径，-1 = 无法达成
  annualRoi: number;       // %
  cashFlow: number[];      // 12 个月累计现金
  months: MonthRow[];
  stoppedMonth: number;    // 0 = 未停业，否则停业月份
  riskLevel: string;       // 低 / 中 / 高
}

function loanInstallment(amount: number, annualRate: number, months: number): number {
  if (amount <= 0 || months <= 0) {
    return 0;
  }
  const r = annualRate / 100 / 12;
  if (r <= 0) {
    return amount / months;
  }
  const f = Math.pow(1 + r, months);
  return amount * r * f / (f - 1);
}

/** 第 m 月的固定成本（按月生效区间 + 摊销窗口） */
function fixedCostAt(items: CostItem[], m: number): number {
  let sum = 0;
  for (const c of items) {
    if (c.kind === 'monthly' && m >= c.startMonth && m <= c.endMonth) {
      sum += c.amount;
    } else if (c.kind === 'amortized' && m <= c.amortMonths && c.amortMonths > 0) {
      sum += c.amount / c.amortMonths;
    }
  }
  return sum;
}

function perUnitCost(items: CostItem[]): number {
  let sum = 0;
  for (const c of items) {
    if (c.kind === 'perUnit') {
      sum += c.amount;
    }
  }
  return sum;
}

function onetimeSum(items: CostItem[]): number {
  let sum = 0;
  for (const c of items) {
    if (c.kind === 'onetime') {
      sum += c.amount;
    }
  }
  return sum;
}

function amortizedTotal(items: CostItem[]): number {
  let sum = 0;
  for (const c of items) {
    if (c.kind === 'amortized') {
      sum += c.amount;
    }
  }
  return sum;
}

function stagedAt(plan: Plan, m: number): number {
  let sum = 0;
  for (const s of plan.staged) {
    if (s.month === m) {
      sum += s.amount;
    }
  }
  return sum;
}

export function simulate(plan: Plan): SimResult {
  const days = plan.daysPerMonth > 0 ? plan.daysPerMonth : 0;
  const perUnit = perUnitCost(plan.costItems);
  const onetime = onetimeSum(plan.costItems);
  const amort = amortizedTotal(plan.costItems);
  let stagedTotal = 0;
  for (const s of plan.staged) {
    stagedTotal += s.amount;
  }
  const startupTotal = onetime + amort + stagedTotal;
  const installment = loanInstallment(plan.loan.amount, plan.loan.annualRate, plan.loan.months);

  const months: MonthRow[] = [];
  const cashFlow: number[] = [];
  let cum = 0;
  let growthFactor = 1;
  let consecNeg = 0;
  let stoppedMonth = 0;
  let paybackMonths = -1;

  const baseFixed = fixedCostAt(plan.costItems, 1);

  for (let m = 1; m <= 12; m++) {
    if (stoppedMonth > 0) {
      months.push({
        month: m, coeff: 0, dailyOrders: 0, revenue: 0, variableCost: 0,
        fixedCost: 0, loanPay: 0, invest: 0, profit: 0, cash: cum
      });
      cashFlow.push(cum);
      continue;
    }
    const coeff = m - 1 < plan.seasonCurve.length ? plan.seasonCurve[m - 1] : 1;
    const dailyOrdersM = plan.dailyOrders * growthFactor * coeff;
    const revenue = plan.unitPrice * dailyOrdersM * days;
    const variableCost = perUnit * dailyOrdersM * days;
    let fixedCost = fixedCostAt(plan.costItems, m);
    // 阈值规则：日均订单超阈值 → 增加月成本
    for (const t of plan.thresholds) {
      if (dailyOrdersM > t.threshold) {
        fixedCost += t.addMonthlyCost;
      }
    }
    const loanPay = m <= plan.loan.months ? installment : 0;
    const invest = (m === 1 ? onetime : 0) + stagedAt(plan, m);
    const profit = revenue - variableCost - fixedCost - loanPay;
    cum += profit - invest;
    months.push({
      month: m, coeff: coeff, dailyOrders: dailyOrdersM, revenue: revenue,
      variableCost: variableCost, fixedCost: fixedCost, loanPay: loanPay,
      invest: invest, profit: profit, cash: cum
    });
    cashFlow.push(Math.round(cum));
    if (paybackMonths < 0 && cum >= 0) {
      paybackMonths = m;
    }
    // 增长（次月生效）
    growthFactor *= 1 + (plan.monthlyGrowthRate - plan.churnRate) / 100;
    // 停业判定
    if (cum < 0) {
      consecNeg++;
    } else {
      consecNeg = 0;
    }
    if (plan.stopLossMonths > 0 && consecNeg >= plan.stopLossMonths) {
      stoppedMonth = m;
    }
  }

  const emptyRow: MonthRow = {
    month: 1, coeff: 1, dailyOrders: 0, revenue: 0, variableCost: 0,
    fixedCost: 0, loanPay: 0, invest: 0, profit: 0, cash: 0
  };
  const m1 = months.length > 0 ? months[0] : emptyRow;
  const monthlyProfit = m1.revenue - m1.variableCost - m1.fixedCost;
  const grossMargin = m1.revenue > 0 ? (m1.revenue - m1.variableCost) / m1.revenue * 100 : 0;
  const unitMargin = plan.unitPrice - perUnit;
  const breakEvenDailyOrders = unitMargin > 0 && days > 0 ? baseFixed / unitMargin / days : -1;
  const annualRoi = startupTotal > 0 ? monthlyProfit * 12 / startupTotal * 100 : 0;

  let riskLevel = '高';
  if (stoppedMonth === 0 && monthlyProfit > 0) {
    if (paybackMonths > 0 && paybackMonths <= 6) {
      riskLevel = '低';
    } else if (paybackMonths > 0 && paybackMonths <= 12) {
      riskLevel = '中';
    }
  }

  return {
    startupTotal: startupTotal,
    selfFunds: plan.selfFunds,
    loanTotal: plan.loan.amount,
    monthlyRevenue: m1.revenue,
    monthlyVariable: m1.variableCost,
    monthlyFixed: m1.fixedCost,
    monthlyProfit: monthlyProfit,
    grossMargin: grossMargin,
    paybackMonths: paybackMonths,
    breakEvenDailyOrders: breakEvenDailyOrders,
    annualRoi: annualRoi,
    cashFlow: cashFlow,
    months: months,
    stoppedMonth: stoppedMonth,
    riskLevel: riskLevel
  };
}

/** 金额格式化：>=1 万显示 x.xx万 */
export function fmtMoney(v: number): string {
  if (Math.abs(v) >= 10000) {
    return `${(v / 10000).toFixed(2)}万`;
  }
  return v.toFixed(0);
}

export function fmtNum(v: number, digits: number = 1): string {
  return v.toFixed(digits);
}
