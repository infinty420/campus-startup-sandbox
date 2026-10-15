/**
 * V2 数据模型：动态成本条目 + 融资 + 阶段投资 + 阈值规则 + 季节系数
 */

/** 成本条目类型：一次性 / 按月 / 按单 / 按月摊销 */
export type CostKind = 'onetime' | 'monthly' | 'perUnit' | 'amortized';

export interface CostItem {
  id: string;
  name: string;
  kind: CostKind;
  amount: number;        // onetime/monthly: 元；perUnit: 元/单；amortized: 总额
  amortMonths: number;   // amortized 专用：摊销月数
  startMonth: number;    // monthly 专用：生效起始月（1 起）
  endMonth: number;      // monthly 专用：生效结束月（含）
}

export interface LoanConfig {
  amount: number;      // 借款本金，<=0 表示无借款
  annualRate: number;  // 年利率 %
  months: number;      // 还款月数
}

export interface StagedInvest {
  month: number;   // 第几个月追加（1 起）
  amount: number;  // 金额
}

export interface ThresholdRule {
  threshold: number;     // 日均订单阈值
  addMonthlyCost: number; // 触发后每月增加成本（如加 1 人）
  note: string;
}

export interface Plan {
  id: string;
  version: number;   // = 2
  name: string;
  type: string;
  note: string;

  // 收入假设
  unitPrice: number;        // 客单价 元/单
  dailyOrders: number;      // 日均订单量
  daysPerMonth: number;     // 月营业天数
  monthlyGrowthRate: number; // 订单月增长率 %
  churnRate: number;        // 竞争流失率 %/月
  seasonCurve: number[];    // 12 个月季节系数

  // 成本假设
  costItems: CostItem[];

  // 资金
  selfFunds: number;       // 自筹资金
  loan: LoanConfig;
  staged: StagedInvest[];
  stopLossMonths: number;  // 连续 N 月现金 < 0 自动停业，0 = 不启用

  // 阈值规则
  thresholds: ThresholdRule[];

  // 资源需求
  staffCount: number;
  areaSqm: number;
}

export function genId(): string {
  return `id_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
}

export function createCostItem(name: string, kind: CostKind, amount: number): CostItem {
  return {
    id: genId(),
    name: name,
    kind: kind,
    amount: amount,
    amortMonths: 24,
    startMonth: 1,
    endMonth: 12
  };
}

export function createEmptyPlan(name: string, type: string): Plan {
  return {
    id: genId(),
    version: 2,
    name: name,
    type: type,
    note: '',
    unitPrice: 0,
    dailyOrders: 0,
    daysPerMonth: 30,
    monthlyGrowthRate: 0,
    churnRate: 0,
    seasonCurve: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    costItems: [],
    selfFunds: 0,
    loan: { amount: 0, annualRate: 6, months: 12 },
    staged: [],
    stopLossMonths: 0,
    thresholds: [],
    staffCount: 1,
    areaSqm: 0
  };
}

export function clonePlan(src: Plan, newName: string): Plan {
  const p = createEmptyPlan(newName, src.type);
  p.note = src.note;
  p.unitPrice = src.unitPrice;
  p.dailyOrders = src.dailyOrders;
  p.daysPerMonth = src.daysPerMonth;
  p.monthlyGrowthRate = src.monthlyGrowthRate;
  p.churnRate = src.churnRate;
  p.seasonCurve = src.seasonCurve.slice();
  p.selfFunds = src.selfFunds;
  p.stopLossMonths = src.stopLossMonths;
  p.staffCount = src.staffCount;
  p.areaSqm = src.areaSqm;
  for (const c of src.costItems) {
    p.costItems.push({
      id: genId(),
      name: c.name,
      kind: c.kind,
      amount: c.amount,
      amortMonths: c.amortMonths,
      startMonth: c.startMonth,
      endMonth: c.endMonth
    });
  }
  p.loan = { amount: src.loan.amount, annualRate: src.loan.annualRate, months: src.loan.months };
  for (const s of src.staged) {
    p.staged.push({ month: s.month, amount: s.amount });
  }
  for (const t of src.thresholds) {
    p.thresholds.push({ threshold: t.threshold, addMonthlyCost: t.addMonthlyCost, note: t.note });
  }
  return p;
}

/** 内置季节曲线 */
export function curveFlat(): number[] {
  return [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
}

/** 寒暑假型：2/7/8 月淡季 */
export function curveVacation(): number[] {
  return [1.0, 0.4, 1.0, 1.0, 1.0, 1.0, 0.5, 0.4, 1.2, 1.1, 1.0, 1.0];
}

/** 开学季型：3/9 月旺季 */
export function curveSemesterStart(): number[] {
  return [0.9, 1.2, 1.2, 1.0, 0.9, 0.9, 0.9, 0.9, 1.2, 1.2, 1.0, 0.9];
}

/** 考试周型：12/6 月旺季（打印/跑腿类） */
export function curveExam(): number[] {
  return [1.0, 0.9, 1.0, 1.0, 1.1, 1.4, 0.9, 0.9, 1.0, 1.0, 1.1, 1.4];
}
