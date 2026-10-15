/**
 * 存储迁移框架：v1（扁平字段）→ v2（动态条目）
 * 新版本出现时在 PlanStore 的迁移链中追加一步。
 */
import { Plan, CostItem, createCostItem } from '../model/PlanV2';

/** V1 旧模型（扁平字段），仅迁移用 */
export interface PlanV1 {
  id: string;
  name: string;
  type: string;
  note: string;
  monthlyRent: number;
  monthlySalary: number;
  monthlyUtility: number;
  monthlyMarketing: number;
  equipment: number;
  renovation: number;
  deposit: number;
  license: number;
  unitVariableCost: number;
  unitPrice: number;
  dailyOrders: number;
  daysPerMonth: number;
  monthlyGrowthRate: number;
  staffCount: number;
  areaSqm: number;
  startupFunds: number;
}

export function isV1(raw: object): boolean {
  const o = raw as PlanV1;
  return o.equipment !== undefined && o.monthlyRent !== undefined;
}

/** v1 → v2 字段映射 */
export function migrateV1toV2(v1: PlanV1): Plan {
  const items: CostItem[] = [];
  if (v1.monthlyRent > 0) {
    items.push(createCostItem('房租', 'monthly', v1.monthlyRent));
  }
  if (v1.monthlySalary > 0) {
    items.push(createCostItem('人工工资', 'monthly', v1.monthlySalary));
  }
  if (v1.monthlyUtility > 0) {
    items.push(createCostItem('水电杂费', 'monthly', v1.monthlyUtility));
  }
  if (v1.monthlyMarketing > 0) {
    items.push(createCostItem('营销费用', 'monthly', v1.monthlyMarketing));
  }
  if (v1.equipment > 0) {
    const it = createCostItem('设备购置', 'amortized', v1.equipment);
    it.amortMonths = 36;
    items.push(it);
  }
  if (v1.renovation > 0) {
    const it = createCostItem('装修', 'amortized', v1.renovation);
    it.amortMonths = 24;
    items.push(it);
  }
  if (v1.deposit > 0) {
    items.push(createCostItem('押金', 'onetime', v1.deposit));
  }
  if (v1.license > 0) {
    items.push(createCostItem('办证杂费', 'onetime', v1.license));
  }
  if (v1.unitVariableCost > 0) {
    items.push(createCostItem('原材料/包装', 'perUnit', v1.unitVariableCost));
  }
  return {
    id: v1.id,
    version: 2,
    name: v1.name,
    type: v1.type,
    note: v1.note,
    unitPrice: v1.unitPrice,
    dailyOrders: v1.dailyOrders,
    daysPerMonth: v1.daysPerMonth,
    monthlyGrowthRate: v1.monthlyGrowthRate,
    churnRate: 0,
    seasonCurve: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    costItems: items,
    selfFunds: v1.startupFunds > 0 ? v1.startupFunds : 0,
    loan: { amount: 0, annualRate: 6, months: 12 },
    staged: [],
    stopLossMonths: 0,
    thresholds: [],
    staffCount: v1.staffCount,
    areaSqm: v1.areaSqm
  };
}
