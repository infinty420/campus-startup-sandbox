/**
 * 目标与预算：目标反推 + 盈亏平衡定价 + 预算组合优化
 */
import { router } from '@kit.ArkUI';
import { Plan } from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { simulate, fmtMoney, fmtNum } from '../service/SimEngine';
import {
  solveOrdersForProfit, solvePriceForProfit, minBreakEvenPrice,
  solveOrdersForPayback, optimizeCombo, ComboResult
} from '../service/Solver';
import { MetricCard } from '../components/MetricCard';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct SolverPage {
  private store: PlanStore = PlanStore.getInstance();
  @State plans: Plan[] = [];
  @State planIdx: number = 0;
  // 目标反推
  @State targetProfit: number = 3000;
  @State targetPayback: number = 6;
  // 预算
  @State budget: number = 30000;
  @State combo: ComboResult | null = null;

  aboutToAppear(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
    });
  }

  private currentPlan(): Plan | null {
    if (this.planIdx >= 0 && this.planIdx < this.plans.length) {
      return this.plans[this.planIdx];
    }
    return null;
  }

  private selPlan(): Plan {
    return this.plans[this.planIdx];
  }

  private reqOrders(): number {
    if (this.plans.length === 0) {
      return -1;
    }
    return solveOrdersForProfit(this.selPlan(), this.targetProfit);
  }

  private reqPrice(): number {
    if (this.plans.length === 0) {
      return -1;
    }
    return solvePriceForProfit(this.selPlan(), this.targetProfit);
  }

  private reqPayback(): number {
    if (this.plans.length === 0) {
      return -1;
    }
    return solveOrdersForPayback(this.selPlan(), this.targetPayback);
  }

  private minPrice(): number {
    if (this.plans.length === 0) {
      return -1;
    }
    return minBreakEvenPrice(this.selPlan());
  }

  private planOptions(): SelectOption[] {
    const opts: SelectOption[] = [];
    for (const p of this.plans) {
      const o: SelectOption = { value: p.name };
      opts.push(o);
    }
    return opts;
  }

  @Builder
  sectionCard(title: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
    }
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .width('100%')
  }

  @Builder
  numField(label: string, val: number, setter: (n: number) => void, unit: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      TextInput({ text: `${val}` })
        .height(32)
        .fontSize(13)
        .width(120)
        .onChange((v: string) => {
          const n = Number(v);
          if (v.length > 0 && !Number.isNaN(n)) {
            setter(n);
          }
        })
      Text(unit)
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
        .width(50)
    }
    .width('100%')
  }

  build() {
    Column() {
      TitleBar({ title: '目标与预算', subtitle: '目标反推 · 最低定价 · 组合优化' })

      if (this.plans.length === 0) {
        Column() {
          Text('请先在首页创建方案')
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // ---- 目标反推 ----
            Column({ space: 12 }) {
              Text('① 目标反推')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Select(this.planOptions())
                .selected(this.planIdx)
                .value(this.plans.length > 0 ? this.plans[this.planIdx].name : '选择方案')
                .font({ size: 14 })
                .width('100%')
                .onSelect((idx: number) => {
                  this.planIdx = idx;
                })

              this.numField('目标月利润', this.targetProfit, (n: number) => {
                this.targetProfit = n;
              }, '元')
              this.numField('目标回本时间', this.targetPayback, (n: number) => {
                this.targetPayback = n;
              }, '个月')

              if (this.plans.length > 0) {
                MetricCard({
                  title: `达到月利润 ${fmtMoney(this.targetProfit)} 元，需要日均单量`,
                  value: this.reqOrders() >= 0
                    ? `${fmtNum(this.reqOrders())} 单/天` : '无法达成（单位毛利 ≤ 0）',
                  sub: `当前假设 ${fmtNum(this.selPlan().dailyOrders, 0)} 单/天 · 差距 ${this.reqOrders() >= 0 ? fmtNum(Math.max(0, this.reqOrders() - this.selPlan().dailyOrders)) : '-'} 单/天`
                })
                MetricCard({
                  title: `达到月利润 ${fmtMoney(this.targetProfit)} 元，客单价需达到`,
                  value: this.reqPrice() >= 0
                    ? `${fmtNum(this.reqPrice(), 2)} 元/单` : '无法计算（订单量为 0）',
                  sub: `当前客单价 ${fmtNum(this.selPlan().unitPrice, 2)} 元/单`
                })
                MetricCard({
                  title: `${this.targetPayback} 个月内回本，需要日均单量`,
                  value: this.reqPayback() >= 0
                    ? `${fmtNum(this.reqPayback())} 单/天` : '12 个月内无法回本',
                  sub: '含季节系数、增长率、融资还款的完整推演（二分法求解）'
                })
                MetricCard({
                  title: '盈亏平衡最低客单价',
                  value: this.minPrice() >= 0
                    ? `${fmtNum(this.minPrice(), 2)} 元/单` : '无法计算',
                  sub: `低于此价每单必亏 · 当前毛利 ${fmtNum(simulate(this.selPlan()).grossMargin)}%`
                })
              }
            }
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .width('100%')

            // ---- 预算组合优化 ----
            Column({ space: 12 }) {
              Text('② 预算组合优化（0/1 背包）')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              this.numField('总预算', this.budget, (n: number) => {
                this.budget = n;
              }, '元')
              Button('求解最优组合')
                .fontSize(14)
                .width('100%')
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => {
                  this.combo = optimizeCombo(this.plans, this.budget);
                })

              if (this.combo !== null) {
                MetricCard({
                  title: '最优组合预计月利润合计',
                  value: `${fmtMoney(this.combo.totalProfit)} 元`,
                  sub: `组合启动投入 ${fmtMoney(this.combo.totalCost)} 元 / 预算 ${fmtMoney(this.combo.budget)} 元`
                })
                ForEach(this.plans, (p: Plan, i: number) => {
                  Row({ space: 10 }) {
                    Text(this.combo !== null && this.combo.selected[i] ? '✓ 选入' : '✗ 不选')
                      .fontSize(13)
                      .fontColor(this.combo !== null && this.combo.selected[i] ? '#2e9e6b' : $r('sys.color.font_tertiary'))
                      .width(70)
                    Text(p.name)
                      .fontSize(14)
                      .layoutWeight(1)
                    Text(`启动 ${fmtMoney(simulate(p).startupTotal)}元`)
                      .fontSize(12)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(`月利 ${fmtMoney(simulate(p).monthlyProfit)}元`)
                      .fontSize(12)
                      .fontColor(simulate(p).monthlyProfit >= 0 ? '#d03050' : '#2e9e6b')
                  }
                  .width('100%')
                  .padding(8)
                  .borderRadius(8)
                  .backgroundColor($r('sys.color.comp_background_secondary'))
                }, (p: Plan) => `kb_${p.id}`)
                Text('说明：月利润 ≤ 0 的方案不入选；以 100 元为刻度做离散化背包求解。')
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
              }
            }
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
