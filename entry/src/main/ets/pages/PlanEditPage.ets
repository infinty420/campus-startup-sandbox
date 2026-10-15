/**
 * 方案编辑页（V2）：动态成本条目 / 收入与季节 / 资金与资源 + 实时仿真指标
 */
import { router } from '@kit.ArkUI';
import {
  Plan, CostItem, CostKind, ThresholdRule, StagedInvest,
  createEmptyPlan, createCostItem, curveFlat, curveVacation, curveSemesterStart, curveExam
} from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { simulate, fmtMoney, fmtNum } from '../service/SimEngine';
import { NumberField } from '../components/NumberField';
import { MetricCard } from '../components/MetricCard';
import { CostItemRow } from '../components/CostItemRow';
import { SeasonInput } from '../components/SeasonInput';
import { C_BRAND, C_BRAND_2 } from '../common/Theme';

interface EditParams {
  planId: string;
}

@Entry
@Component
struct PlanEditPage {
  private store: PlanStore = PlanStore.getInstance();
  private planId: string = '';
  @State name: string = '';
  @State type: string = '';
  @State note: string = '';
  // 收入
  @State unitPrice: number = 0;
  @State dailyOrders: number = 0;
  @State daysPerMonth: number = 30;
  @State monthlyGrowthRate: number = 0;
  @State churnRate: number = 0;
  @State curve: number[] = curveFlat();
  // 成本
  @State costItems: CostItem[] = [];
  @State thresholds: ThresholdRule[] = [];
  // 资金与资源
  @State staffCount: number = 1;
  @State areaSqm: number = 0;
  @State selfFunds: number = 0;
  @State loanAmount: number = 0;
  @State loanRate: number = 6;
  @State loanMonths: number = 12;
  @State stopLossMonths: number = 0;
  @State staged: StagedInvest[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as EditParams;
    if (params !== undefined && params !== null && params.planId !== undefined) {
      this.planId = params.planId;
    }
    const p = this.store.getPlan(this.planId);
    const src: Plan = p !== undefined ? p : createEmptyPlan('未命名方案', '自定义');
    this.name = src.name;
    this.type = src.type;
    this.note = src.note;
    this.unitPrice = src.unitPrice;
    this.dailyOrders = src.dailyOrders;
    this.daysPerMonth = src.daysPerMonth;
    this.monthlyGrowthRate = src.monthlyGrowthRate;
    this.churnRate = src.churnRate;
    this.curve = src.seasonCurve.slice();
    this.costItems = src.costItems.slice();
    this.thresholds = src.thresholds.slice();
    this.staffCount = src.staffCount;
    this.areaSqm = src.areaSqm;
    this.selfFunds = src.selfFunds;
    this.loanAmount = src.loan.amount;
    this.loanRate = src.loan.annualRate;
    this.loanMonths = src.loan.months;
    this.stopLossMonths = src.stopLossMonths;
    this.staged = src.staged.slice();
  }

  private buildPlan(): Plan {
    return {
      id: this.planId,
      version: 2,
      name: this.name.length > 0 ? this.name : '未命名方案',
      type: this.type.length > 0 ? this.type : '自定义',
      note: this.note,
      unitPrice: this.unitPrice,
      dailyOrders: this.dailyOrders,
      daysPerMonth: this.daysPerMonth,
      monthlyGrowthRate: this.monthlyGrowthRate,
      churnRate: this.churnRate,
      seasonCurve: this.curve.slice(),
      costItems: this.costItems,
      selfFunds: this.selfFunds,
      loan: { amount: this.loanAmount, annualRate: this.loanRate, months: this.loanMonths },
      staged: this.staged,
      stopLossMonths: this.stopLossMonths,
      thresholds: this.thresholds,
      staffCount: this.staffCount,
      areaSqm: this.areaSqm
    };
  }

  private save(): void {
    this.store.savePlan(this.buildPlan()).then(() => {
      router.back();
    });
  }

  // ---- 成本条目操作 ----
  private addCostItem(): void {
    this.costItems.push(createCostItem('新成本项', 'monthly', 0));
    this.costItems = this.costItems.slice();
  }

  private updateCostNum(idx: number, field: string, val: number): void {
    const it = this.costItems[idx];
    if (it === undefined) {
      return;
    }
    if (field === 'amount') {
      it.amount = val;
    } else if (field === 'amortMonths') {
      it.amortMonths = val;
    } else if (field === 'startMonth') {
      it.startMonth = val;
    } else if (field === 'endMonth') {
      it.endMonth = val;
    }
  }

  private updateCostStr(idx: number, field: string, val: string): void {
    const it = this.costItems[idx];
    if (it === undefined) {
      return;
    }
    if (field === 'name') {
      it.name = val;
    } else if (field === 'kind') {
      it.kind = val as CostKind;
      this.costItems = this.costItems.slice(); // 触发行重绘（切换条件输入）
    }
  }

  private deleteCostItem(idx: number): void {
    this.costItems.splice(idx, 1);
    this.costItems = this.costItems.slice();
  }

  // ---- 阈值规则 ----
  private addThreshold(): void {
    this.thresholds.push({ threshold: 100, addMonthlyCost: 2000, note: '' });
    this.thresholds = this.thresholds.slice();
  }

  // ---- 阶段投资 ----
  private addStaged(): void {
    this.staged.push({ month: 6, amount: 2000 });
    this.staged = this.staged.slice();
  }

  @Builder
  sectionTitle(t: string) {
    Text(t)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .width('100%')
      .margin({ top: 8 })
  }

  @Builder
  metricsPanel() {
    Column({ space: 10 }) {
      Text('实时仿真')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      MetricCard({
        title: '启动投入合计',
        value: `${fmtMoney(simulate(this.buildPlan()).startupTotal)} 元`,
        sub: '一次性 + 摊销总额 + 阶段追加'
      })
      MetricCard({
        title: '月收入 / 月成本',
        value: `${fmtMoney(simulate(this.buildPlan()).monthlyRevenue)} / ${fmtMoney(simulate(this.buildPlan()).monthlyVariable + simulate(this.buildPlan()).monthlyFixed)} 元`,
        sub: '成本 = 变动 + 固定（含摊销）'
      })
      MetricCard({
        title: '月经营利润',
        value: `${fmtMoney(simulate(this.buildPlan()).monthlyProfit)} 元`,
        sub: `毛利率 ${fmtNum(simulate(this.buildPlan()).grossMargin)}%`,
        color: simulate(this.buildPlan()).monthlyProfit >= 0 ? '#d03050' : '#2e9e6b'
      })
      MetricCard({
        title: '现金流转正',
        value: simulate(this.buildPlan()).paybackMonths > 0
          ? `第 ${simulate(this.buildPlan()).paybackMonths} 个月` : '12 个月内未转正',
        sub: `年化 ROI ${fmtNum(simulate(this.buildPlan()).annualRoi)}%`
      })
      MetricCard({
        title: '盈亏平衡日均单量',
        value: simulate(this.buildPlan()).breakEvenDailyOrders >= 0
          ? `${fmtNum(simulate(this.buildPlan()).breakEvenDailyOrders)} 单/天` : '当前定价无法覆盖成本',
        sub: `当前假设 ${fmtNum(this.dailyOrders, 0)} 单/天`,
        color: simulate(this.buildPlan()).breakEvenDailyOrders >= 0 && this.dailyOrders >= simulate(this.buildPlan()).breakEvenDailyOrders ? '#2e9e6b' : '#d03050'
      })
      if (simulate(this.buildPlan()).stoppedMonth > 0) {
        Text(`⚠ 触发停业规则：第 ${simulate(this.buildPlan()).stoppedMonth} 个月连续现金为负`)
          .fontSize(12)
          .fontColor('#d03050')
      }
      if (this.loanAmount > 0) {
        MetricCard({
          title: '月还款额（等额本息）',
          value: `${fmtMoney(simulate(this.buildPlan()).months.length > 0 ? simulate(this.buildPlan()).months[0].loanPay : 0)} 元/月`,
          sub: `借款 ${fmtMoney(this.loanAmount)} 元 · ${this.loanMonths} 期 · 年利率 ${fmtNum(this.loanRate)}%`
        })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 14 }) {
        Text('←')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_BRAND)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .onClick(() => router.back())

        Row()
          .width(5)
          .height(24)
          .borderRadius(3)
          .linearGradient({
            angle: 180,
            colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
          })

        TextInput({ text: this.name, placeholder: '方案名称' })
          .layoutWeight(1)
          .height(40)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .onChange((v: string) => {
            this.name = v;
          })
        TextInput({ text: this.type, placeholder: '类型' })
          .width(110)
          .height(40)
          .fontSize(14)
          .onChange((v: string) => {
            this.type = v;
          })
        Button('保存')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .height(38)
          .linearGradient({
            angle: 135,
            colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
          })
          .onClick(() => this.save())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Row({ space: 16 }) {
        // 左：录入表单
        Column() {
          Tabs() {
            // ---- 成本假设 ----
            TabContent() {
              Scroll() {
                Column({ space: 10 }) {
                  this.sectionTitle('成本条目（可任意增删）')
                  ForEach(this.costItems, (it: CostItem, idx: number) => {
                    CostItemRow({
                      item: it,
                      onUpdateNum: (field: string, val: number) => this.updateCostNum(idx, field, val),
                      onUpdateStr: (field: string, val: string) => this.updateCostStr(idx, field, val),
                      onDelete: () => this.deleteCostItem(idx)
                    })
                  }, (it: CostItem) => it.id)
                  Button('+ 添加成本项')
                    .fontSize(13)
                    .height(34)
                    .width('100%')
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                    .fontColor($r('sys.color.brand'))
                    .onClick(() => this.addCostItem())

                  this.sectionTitle('阶梯阈值规则（订单超阈值时增加月成本）')
                  ForEach(this.thresholds, (t: ThresholdRule, idx: number) => {
                    Row({ space: 6 }) {
                      Text('日均订单 >')
                        .fontSize(12)
                      TextInput({ text: `${t.threshold}` })
                        .height(32)
                        .fontSize(13)
                        .width(70)
                        .onChange((v: string) => {
                          const n = Number(v);
                          if (v.length > 0 && !Number.isNaN(n)) {
                            this.thresholds[idx].threshold = n;
                          }
                        })
                      Text('时，月成本 +')
                        .fontSize(12)
                      TextInput({ text: `${t.addMonthlyCost}` })
                        .height(32)
                        .fontSize(13)
                        .width(80)
                        .onChange((v: string) => {
                          const n = Number(v);
                          if (v.length > 0 && !Number.isNaN(n)) {
                            this.thresholds[idx].addMonthlyCost = n;
                          }
                        })
                      Text('元')
                        .fontSize(12)
                      Text('删除')
                        .fontSize(12)
                        .fontColor('#d03050')
                        .padding(4)
                        .onClick(() => {
                          this.thresholds.splice(idx, 1);
                          this.thresholds = this.thresholds.slice();
                        })
                    }
                    .width('100%')
                    .padding(8)
                    .borderRadius(8)
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                  }, (t: ThresholdRule, idx: number) => `th_${idx}`)
                  Button('+ 添加阈值规则')
                    .fontSize(13)
                    .height(34)
                    .width('100%')
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                    .fontColor($r('sys.color.brand'))
                    .onClick(() => this.addThreshold())
                }
                .width('100%')
                .padding(16)
              }
              .align(Alignment.Top)
            }
            .tabBar('成本假设')

            // ---- 收入假设 ----
            TabContent() {
              Scroll() {
                Column({ space: 10 }) {
                  this.sectionTitle('基础假设')
                  NumberField({ label: '客单价', unit: '元/单', value: $unitPrice })
                  NumberField({ label: '日均订单量', unit: '单/天', value: $dailyOrders })
                  NumberField({ label: '月营业天数', unit: '天', value: $daysPerMonth })
                  NumberField({ label: '订单月增长率', unit: '%/月', value: $monthlyGrowthRate })
                  NumberField({ label: '竞争流失率', unit: '%/月', value: $churnRate })

                  this.sectionTitle('月度季节系数（1 = 正常月）')
                  Row({ space: 8 }) {
                    Text('预设：')
                      .fontSize(12)
                      .fontColor($r('sys.color.font_secondary'))
                    Text('均匀')
                      .fontSize(12)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(10)
                      .backgroundColor($r('sys.color.comp_background_secondary'))
                      .onClick(() => {
                        this.curve = curveFlat();
                      })
                    Text('寒暑假')
                      .fontSize(12)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(10)
                      .backgroundColor($r('sys.color.comp_background_secondary'))
                      .onClick(() => {
                        this.curve = curveVacation();
                      })
                    Text('开学季')
                      .fontSize(12)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(10)
                      .backgroundColor($r('sys.color.comp_background_secondary'))
                      .onClick(() => {
                        this.curve = curveSemesterStart();
                      })
                    Text('考试周')
                      .fontSize(12)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(10)
                      .backgroundColor($r('sys.color.comp_background_secondary'))
                      .onClick(() => {
                        this.curve = curveExam();
                      })
                  }
                  .width('100%')
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                    ForEach(this.curve, (v: number, i: number) => {
                      SeasonInput({
                        monthIdx: i,
                        val: v,
                        onVal: (m: number, nv: number) => {
                          this.curve[m] = nv;
                        }
                      })
                    }, (v: number, i: number) => `c_${i}`)
                  }
                  .width('100%')

                  this.sectionTitle('备注')
                  TextArea({ text: this.note, placeholder: '记录关键假设，如：开学季旺季、竞争情况…' })
                    .height(80)
                    .onChange((v: string) => {
                      this.note = v;
                    })
                }
                .width('100%')
                .padding(16)
              }
              .align(Alignment.Top)
            }
            .tabBar('收入假设')

            // ---- 资金与资源 ----
            TabContent() {
              Scroll() {
                Column({ space: 10 }) {
                  this.sectionTitle('资源需求')
                  NumberField({ label: '所需人力', unit: '人', value: $staffCount })
                  NumberField({ label: '场地面积', unit: '㎡', value: $areaSqm })

                  this.sectionTitle('资金来源')
                  NumberField({ label: '自筹资金', unit: '元', value: $selfFunds })
                  NumberField({ label: '借款金额（0 = 无借款）', unit: '元', value: $loanAmount })
                  NumberField({ label: '借款年利率', unit: '%', value: $loanRate })
                  NumberField({ label: '还款月数', unit: '月', value: $loanMonths })

                  this.sectionTitle('阶段追加投资')
                  ForEach(this.staged, (s: StagedInvest, idx: number) => {
                    Row({ space: 6 }) {
                      Text('第')
                        .fontSize(12)
                      TextInput({ text: `${s.month}` })
                        .height(32)
                        .fontSize(13)
                        .width(60)
                        .onChange((v: string) => {
                          const n = Number(v);
                          if (v.length > 0 && !Number.isNaN(n)) {
                            this.staged[idx].month = Math.round(n);
                          }
                        })
                      Text('个月投入')
                        .fontSize(12)
                      TextInput({ text: `${s.amount}` })
                        .height(32)
                        .fontSize(13)
                        .width(90)
                        .onChange((v: string) => {
                          const n = Number(v);
                          if (v.length > 0 && !Number.isNaN(n)) {
                            this.staged[idx].amount = n;
                          }
                        })
                      Text('元')
                        .fontSize(12)
                      Text('删除')
                        .fontSize(12)
                        .fontColor('#d03050')
                        .padding(4)
                        .onClick(() => {
                          this.staged.splice(idx, 1);
                          this.staged = this.staged.slice();
                        })
                    }
                    .width('100%')
                    .padding(8)
                    .borderRadius(8)
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                  }, (s: StagedInvest, idx: number) => `st_${idx}`)
                  Button('+ 添加阶段投资')
                    .fontSize(13)
                    .height(34)
                    .width('100%')
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                    .fontColor($r('sys.color.brand'))
                    .onClick(() => this.addStaged())

                  this.sectionTitle('风险控制')
                  NumberField({ label: '连续 N 月现金为负自动停业（0 = 不启用）', unit: '月', value: $stopLossMonths })
                }
                .width('100%')
                .padding(16)
              }
              .align(Alignment.Top)
            }
            .tabBar('资金与资源')
          }
          .barMode(BarMode.Fixed)
          .layoutWeight(1)
        }
        .layoutWeight(3)

        // 右：实时指标
        Scroll() {
          this.metricsPanel()
        }
        .layoutWeight(2)
        .align(Alignment.Top)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
