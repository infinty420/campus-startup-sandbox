/**
 * 对比分析页：多方案指标对比表格 + 图表 + CSV 导出
 */
import { router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { Plan } from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { simulate, SimResult, fmtMoney, fmtNum } from '../service/SimEngine';
import { BarChart } from '../components/BarChart';
import { CashFlowChart } from '../components/CashFlowChart';
import { C_BRAND, C_BRAND_2 } from '../common/Theme';

const SORTS: string[] = ['默认顺序', '月利润最高', '回本最快', 'ROI 最高'];
const RISK_COLOR: Record<string, string> = {
  '低': '#2e9e6b',
  '中': '#d9822b',
  '高': '#d03050'
};

@Entry
@Component
struct ComparePage {
  private store: PlanStore = PlanStore.getInstance();
  @State plans: Plan[] = [];
  @State selected: Record<string, boolean> = {};
  @State sortIdx: number = 0;

  aboutToAppear(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
      for (const p of this.plans) {
        this.selected[p.id] = true;
      }
    });
  }

  private getSelectedPlans(): Plan[] {
    const list: Plan[] = [];
    for (const p of this.plans) {
      if (this.selected[p.id] === true) {
        list.push(p);
      }
    }
    if (this.sortIdx === 1) {
      list.sort((a: Plan, b: Plan) => simulate(b).monthlyProfit - simulate(a).monthlyProfit);
    } else if (this.sortIdx === 2) {
      list.sort((a: Plan, b: Plan) => {
        const ma = simulate(a).paybackMonths;
        const mb = simulate(b).paybackMonths;
        if (ma <= 0 && mb <= 0) {
          return 0;
        }
        if (ma <= 0) {
          return 1;
        }
        if (mb <= 0) {
          return -1;
        }
        return ma - mb;
      });
    } else if (this.sortIdx === 3) {
      list.sort((a: Plan, b: Plan) => simulate(b).annualRoi - simulate(a).annualRoi);
    }
    return list;
  }

  private exportCsv(): void {
    const sel = this.getSelectedPlans();
    if (sel.length === 0) {
      return;
    }
    const lines: string[] = [];
    const head: string[] = ['指标'];
    for (const p of sel) {
      head.push(p.name);
    }
    lines.push(head.join(','));
    const metrics: SimResult[] = [];
    for (const p of sel) {
      metrics.push(simulate(p));
    }
    const row = (label: string, get: (m: SimResult) => string): void => {
      const cells: string[] = [label];
      for (const m of metrics) {
        cells.push(get(m));
      }
      lines.push(cells.join(','));
    };
    row('启动投入(元)', (m: SimResult) => `${Math.round(m.startupTotal)}`);
    row('月收入(元)', (m: SimResult) => `${Math.round(m.monthlyRevenue)}`);
    row('月固定成本(元)', (m: SimResult) => `${Math.round(m.monthlyFixed)}`);
    row('月变动成本(元)', (m: SimResult) => `${Math.round(m.monthlyVariable)}`);
    row('月净利润(元)', (m: SimResult) => `${Math.round(m.monthlyProfit)}`);
    row('毛利率(%)', (m: SimResult) => fmtNum(m.grossMargin));
    row('回本周期(月)', (m: SimResult) => m.paybackMonths > 0 ? fmtNum(m.paybackMonths) : '无法回本');
    row('盈亏平衡日均单量', (m: SimResult) => m.breakEvenDailyOrders >= 0 ? fmtNum(m.breakEvenDailyOrders) : 'N/A');
    row('年化ROI(%)', (m: SimResult) => fmtNum(m.annualRoi));
    row('风险评级', (m: SimResult) => m.riskLevel);
    const resRow: string[] = ['所需人力(人)'];
    const areaRow: string[] = ['场地面积(㎡)'];
    for (const p of sel) {
      resRow.push(`${p.staffCount}`);
      areaRow.push(`${p.areaSqm}`);
    }
    lines.push(resRow.join(','));
    lines.push(areaRow.join(','));

    const content = '\uFEFF' + lines.join('\n');
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        const path = `${ctx.filesDir}/创业方案对比.csv`;
        const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, content);
        fileIo.closeSync(file);
        this.getUIContext().getPromptAction().showToast({ message: `已导出：${path}` });
      }
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: `导出失败：${e}` });
    }
  }

  /**
   * 表格行：label + 各方案值 + 最优值高亮
   * higherBetter: true 取最大值为最优；false 取最小值
   */
  private bestIndex(values: number[], higherBetter: boolean): number {
    if (values.length === 0) {
      return -1;
    }
    let best = 0;
    for (let i = 1; i < values.length; i++) {
      const v = values[i];
      const b = values[best];
      if (higherBetter && v > b) {
        best = i;
      }
      if (!higherBetter && v < b) {
        best = i;
      }
    }
    return best;
  }

  @Builder
  headerCell(t: string, w: string) {
    Text(t)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_secondary'))
      .width(w)
      .padding(8)
  }

  @Builder
  cell(t: string, w: string, highlight: boolean, color: string) {
    Text(t)
      .fontSize(13)
      .fontWeight(highlight ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(color.length > 0 ? color : $r('sys.color.font_primary'))
      .width(w)
      .padding(8)
      .backgroundColor(highlight ? '#fdece8' : Color.Transparent)
      .borderRadius(6)
  }

  @Builder
  metricRow(label: string, texts: string[], values: number[], higherBetter: boolean, colors: string[]) {
    Row() {
      this.headerCell(label, '150')
      ForEach(texts, (t: string, i: number) => {
        this.cell(t, '130', i === this.bestIndex(values, higherBetter),
          i < colors.length ? colors[i] : '')
      }, (t: string, i: number) => `${i}_${t}`)
    }
    .width('100%')
    .border({ width: { bottom: 1 }, color: $r('sys.color.comp_divider') })
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

        Row({ space: 10 }) {
          Row()
            .width(5)
            .height(22)
            .borderRadius(3)
            .linearGradient({
              angle: 180,
              colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
            })
          Column({ space: 2 }) {
            Text('方案对比分析')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
            Text('多方案指标横向对比 · 最优值自动高亮')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Button('导出 CSV')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .height(38)
          .linearGradient({
            angle: 135,
            colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
          })
          .onClick(() => this.exportCsv())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      if (this.plans.length === 0) {
        Column({ space: 8 }) {
          Text('还没有方案可对比')
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
          Button('去创建方案')
            .fontSize(14)
            .backgroundColor($r('sys.color.brand'))
            .onClick(() => router.back())
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 方案选择 + 排序
            Column({ space: 10 }) {
              Text('选择要对比的方案')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.plans, (p: Plan) => {
                  Row({ space: 6 }) {
                    Checkbox()
                      .select(this.selected[p.id] === true)
                      .selectedColor($r('sys.color.brand'))
                      .onChange((v: boolean) => {
                        this.selected[p.id] = v;
                      })
                    Text(p.name)
                      .fontSize(13)
                  }
                  .padding(6)
                  .borderRadius(8)
                  .backgroundColor($r('sys.color.comp_background_secondary'))
                  .margin(4)
                }, (p: Plan) => `chk_${p.id}`)
              }
              .width('100%')
              Row({ space: 8 }) {
                Text('排序：')
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                ForEach(SORTS, (s: string, i: number) => {
                  Text(s)
                    .fontSize(13)
                    .fontColor(this.sortIdx === i ? '#ffffff' : $r('sys.color.font_primary'))
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .borderRadius(14)
                    .backgroundColor(this.sortIdx === i ? $r('sys.color.brand') : $r('sys.color.comp_background_secondary'))
                    .onClick(() => {
                      this.sortIdx = i;
                    })
                }, (s: string) => s)
              }
              .width('100%')
            }
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .width('100%')

            // 对比表格
            if (this.getSelectedPlans().length > 0) {
              Column() {
                Text('指标对比（绿色底 = 最优）')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .padding({ top: 12, left: 12 })
                Scroll() {
                  Column() {
                    // 表头
                    Row() {
                      this.headerCell('指标', '150')
                      ForEach(this.getSelectedPlans(), (p: Plan) => {
                        this.headerCell(p.name, '130')
                      }, (p: Plan) => `h_${p.id}`)
                    }
                    .width('100%')
                    .border({ width: { bottom: 1 }, color: $r('sys.color.comp_divider') })

                    if (this.getSelectedPlans().length > 0) {
                      this.buildTableRows()
                    }
                  }
                  .width('100%')
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Auto)
                .width('100%')
              }
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')
            }

            // 图表
            if (this.getSelectedPlans().length > 0) {
              Column({ space: 8 }) {
                Text('月净利润对比（红=盈利 绿=亏损）')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                BarChart({
                  values: this.profitValues(),
                  labels: this.nameLabels()
                })
              }
              .padding(14)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')

              Column({ space: 8 }) {
                Text('12 个月累计现金流走势')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                CashFlowChart({
                  series: this.cashFlowSeries(),
                  labels: this.nameLabels()
                })
              }
              .padding(14)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  private profitValues(): number[] {
    const out: number[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(Math.round(simulate(p).monthlyProfit));
    }
    return out;
  }

  private nameLabels(): string[] {
    const out: string[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(p.name);
    }
    return out;
  }

  private cashFlowSeries(): number[][] {
    const out: number[][] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(simulate(p).cashFlow);
    }
    return out;
  }

  @Builder
  buildTableRows() {
    Column() {
      // 启动投入（越小越好）
      this.metricRow('启动投入',
        this.colText((m: SimResult) => `${fmtMoney(m.startupTotal)}元`),
        this.colNum((m: SimResult) => m.startupTotal), false, this.emptyColors())
      this.metricRow('月收入',
        this.colText((m: SimResult) => `${fmtMoney(m.monthlyRevenue)}元`),
        this.colNum((m: SimResult) => m.monthlyRevenue), true, this.emptyColors())
      this.metricRow('月固定成本',
        this.colText((m: SimResult) => `${fmtMoney(m.monthlyFixed)}元`),
        this.colNum((m: SimResult) => m.monthlyFixed), false, this.emptyColors())
      this.metricRow('月变动成本',
        this.colText((m: SimResult) => `${fmtMoney(m.monthlyVariable)}元`),
        this.colNum((m: SimResult) => m.monthlyVariable), false, this.emptyColors())
      this.metricRow('月净利润',
        this.colText((m: SimResult) => `${fmtMoney(m.monthlyProfit)}元`),
        this.colNum((m: SimResult) => m.monthlyProfit), true,
        this.profitColors())
      this.metricRow('毛利率',
        this.colText((m: SimResult) => `${fmtNum(m.grossMargin)}%`),
        this.colNum((m: SimResult) => m.grossMargin), true, this.emptyColors())
      this.metricRow('回本周期',
        this.colText((m: SimResult) => m.paybackMonths > 0 ? `${fmtNum(m.paybackMonths)}个月` : '无法回本'),
        this.colNum((m: SimResult) => m.paybackMonths > 0 ? m.paybackMonths : 999999), false, this.emptyColors())
      this.metricRow('盈亏平衡日均单量',
        this.colText((m: SimResult) => m.breakEvenDailyOrders >= 0 ? `${fmtNum(m.breakEvenDailyOrders)}单` : 'N/A'),
        this.colNum((m: SimResult) => m.breakEvenDailyOrders >= 0 ? m.breakEvenDailyOrders : 999999), false,
        this.emptyColors())
      this.metricRow('年化 ROI',
        this.colText((m: SimResult) => `${fmtNum(m.annualRoi)}%`),
        this.colNum((m: SimResult) => m.annualRoi), true, this.emptyColors())
      this.metricRow('风险评级',
        this.colText((m: SimResult) => m.riskLevel),
        this.colNum((m: SimResult) => m.riskLevel === '低' ? 3 : (m.riskLevel === '中' ? 2 : 1)), true,
        this.riskColors())
      this.metricRow('所需人力',
        this.resText((p: Plan) => `${p.staffCount}人`),
        this.resNum((p: Plan) => p.staffCount), false, this.emptyColors())
      this.metricRow('场地面积',
        this.resText((p: Plan) => `${p.areaSqm}㎡`),
        this.resNum((p: Plan) => p.areaSqm), false, this.emptyColors())
    }
    .width('100%')
  }

  private colText(get: (m: SimResult) => string): string[] {
    const out: string[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(get(simulate(p)));
    }
    return out;
  }

  private colNum(get: (m: SimResult) => number): number[] {
    const out: number[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(get(simulate(p)));
    }
    return out;
  }

  private resText(get: (p: Plan) => string): string[] {
    const out: string[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(get(p));
    }
    return out;
  }

  private resNum(get: (p: Plan) => number): number[] {
    const out: number[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(get(p));
    }
    return out;
  }

  private emptyColors(): string[] {
    const out: string[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push('');
    }
    return out;
  }

  private profitColors(): string[] {
    const out: string[] = [];
    for (const p of this.getSelectedPlans()) {
      out.push(simulate(p).monthlyProfit >= 0 ? '#d03050' : '#2e9e6b');
    }
    return out;
  }

  private riskColors(): string[] {
    const out: string[] = [];
    for (const p of this.getSelectedPlans()) {
      const lv = simulate(p).riskLevel;
      out.push(RISK_COLOR[lv]);
    }
    return out;
  }
}
