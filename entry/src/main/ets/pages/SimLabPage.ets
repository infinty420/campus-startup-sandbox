/**
 * 仿真实验室：蒙特卡洛抽样 → 分布 / 概率 / 敏感度
 */
import { router } from '@kit.ArkUI';
import { Plan } from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { runMonteCarlo, McConfig, McResult } from '../service/MonteCarlo';
import { fmtMoney, fmtNum } from '../service/SimEngine';
import { MetricCard } from '../components/MetricCard';
import { HistogramChart } from '../components/HistogramChart';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct SimLabPage {
  private store: PlanStore = PlanStore.getInstance();
  @State plans: Plan[] = [];
  @State planIdx: number = 0;
  // 客单价
  @State priceEnabled: boolean = true;
  @State priceMin: number = 8;
  @State priceMode: number = 10;
  @State priceMax: number = 12;
  // 订单量
  @State ordersEnabled: boolean = true;
  @State ordersMin: number = 40;
  @State ordersMode: number = 60;
  @State ordersMax: number = 90;
  // 变动成本
  @State costEnabled: boolean = true;
  @State costJitter: number = 15;
  // 相关性 / 规模
  @State correlation: number = -0.3;
  @State runs: number = 2000;
  @State result: McResult | null = null;
  @State running: boolean = false;

  aboutToAppear(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
      if (this.plans.length > 0) {
        const p = this.plans[0];
        this.priceMode = p.unitPrice;
        this.priceMin = Math.round(p.unitPrice * 0.8 * 100) / 100;
        this.priceMax = Math.round(p.unitPrice * 1.2 * 100) / 100;
        this.ordersMode = p.dailyOrders;
        this.ordersMin = Math.round(p.dailyOrders * 0.6);
        this.ordersMax = Math.round(p.dailyOrders * 1.5);
      }
    });
  }

  private currentPlan(): Plan | null {
    if (this.planIdx >= 0 && this.planIdx < this.plans.length) {
      return this.plans[this.planIdx];
    }
    return null;
  }

  private planOptions(): SelectOption[] {
    const opts: SelectOption[] = [];
    for (const p of this.plans) {
      const o: SelectOption = { value: p.name };
      opts.push(o);
    }
    return opts;
  }

  private run(): void {
    const p = this.currentPlan();
    if (p === null) {
      return;
    }
    this.running = true;
    const cfg: McConfig = {
      priceEnabled: this.priceEnabled,
      priceMin: this.priceMin,
      priceMode: this.priceMode,
      priceMax: this.priceMax,
      ordersEnabled: this.ordersEnabled,
      ordersMin: this.ordersMin,
      ordersMode: this.ordersMode,
      ordersMax: this.ordersMax,
      costEnabled: this.costEnabled,
      costJitter: this.costJitter,
      correlation: this.correlation,
      runs: this.runs
    };
    // 延迟一帧让按钮态生效，同步计算（2000 次 × 12 月推演，毫秒级）
    setTimeout(() => {
      this.result = runMonteCarlo(p, cfg, 20261015);
      this.running = false;
    }, 50);
  }

  @Builder
  numRow(label: string, val: number, setter: (n: number) => void) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width(70)
      TextInput({ text: `${val}` })
        .height(32)
        .fontSize(13)
        .layoutWeight(1)
        .onChange((v: string) => {
          const n = Number(v);
          if (v.length > 0 && !Number.isNaN(n)) {
            setter(n);
          }
        })
    }
    .width('100%')
  }

  @Builder
  toggleRow(label: string, val: boolean, setter: (b: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: val })
        .selectedColor($r('sys.color.brand'))
        .onChange((b: boolean) => setter(b))
    }
    .width('100%')
  }

  @Builder
  sensBar(name: string, share: number) {
    Column({ space: 4 }) {
      Row() {
        Text(name)
          .fontSize(12)
          .layoutWeight(1)
        Text(`${fmtNum(share)}%`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
        Column()
          .width(`${Math.max(2, Math.min(100, share))}%`)
          .height(8)
          .borderRadius(4)
          .backgroundColor('#5b8ff9')
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      TitleBar({ title: '仿真实验室', subtitle: '蒙特卡洛仿真 · 分布 / 概率 / 敏感度' })

      if (this.plans.length === 0) {
        Column({ space: 8 }) {
          Text('请先在首页创建方案')
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Row({ space: 16 }) {
          // 左：配置
          Scroll() {
            Column({ space: 12 }) {
              Select(this.planOptions())
                .selected(this.planIdx)
                .value(this.plans.length > 0 ? this.plans[this.planIdx].name : '选择方案')
                .font({ size: 14 })
                .width('100%')
                .onSelect((idx: number) => {
                  this.planIdx = idx;
                  this.result = null;
                })

              Column({ space: 8 }) {
                this.toggleRow('客单价随机（三角分布）', this.priceEnabled, (b: boolean) => {
                  this.priceEnabled = b;
                })
                if (this.priceEnabled) {
                  this.numRow('最小', this.priceMin, (n: number) => {
                    this.priceMin = n;
                  })
                  this.numRow('最可能', this.priceMode, (n: number) => {
                    this.priceMode = n;
                  })
                  this.numRow('最大', this.priceMax, (n: number) => {
                    this.priceMax = n;
                  })
                }
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')

              Column({ space: 8 }) {
                this.toggleRow('日均订单量随机（三角分布）', this.ordersEnabled, (b: boolean) => {
                  this.ordersEnabled = b;
                })
                if (this.ordersEnabled) {
                  this.numRow('最小', this.ordersMin, (n: number) => {
                    this.ordersMin = n;
                  })
                  this.numRow('最可能', this.ordersMode, (n: number) => {
                    this.ordersMode = n;
                  })
                  this.numRow('最大', this.ordersMax, (n: number) => {
                    this.ordersMax = n;
                  })
                }
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')

              Column({ space: 8 }) {
                this.toggleRow('变动成本随机（±% 扰动）', this.costEnabled, (b: boolean) => {
                  this.costEnabled = b;
                })
                if (this.costEnabled) {
                  this.numRow('扰动幅度 %', this.costJitter, (n: number) => {
                    this.costJitter = n;
                  })
                }
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')

              Column({ space: 8 }) {
                Text('价格-销量相关系数')
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                  .width('100%')
                Row({ space: 8 }) {
                  Slider({
                    value: this.correlation * 100,
                    min: -90,
                    max: 90,
                    step: 5
                  })
                    .layoutWeight(1)
                    .selectedColor($r('sys.color.brand'))
                    .onChange((v: number) => {
                      this.correlation = v / 100;
                    })
                  Text(`${fmtNum(this.correlation, 2)}`)
                    .fontSize(13)
                    .width(50)
                }
                .width('100%')
                Text('负值 = 提价则销量下滑（价格敏感）')
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')

              Column({ space: 8 }) {
                Text('抽样次数')
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                  .width('100%')
                Row({ space: 8 }) {
                  ForEach([500, 1000, 2000, 5000], (r: number) => {
                    Text(`${r}`)
                      .fontSize(13)
                      .fontColor(this.runs === r ? '#ffffff' : $r('sys.color.font_primary'))
                      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                      .borderRadius(14)
                      .backgroundColor(this.runs === r ? $r('sys.color.brand') : $r('sys.color.comp_background_secondary'))
                      .onClick(() => {
                        this.runs = r;
                      })
                  }, (r: number) => `r_${r}`)
                }
                .width('100%')
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .width('100%')

              Button(this.running ? '仿真中…' : `运行仿真（${this.runs} 次）`)
                .fontSize(15)
                .width('100%')
                .backgroundColor($r('sys.color.brand'))
                .enabled(!this.running)
                .onClick(() => this.run())
            }
            .width('100%')
          }
          .layoutWeight(2)
          .align(Alignment.Top)

          // 右：结果
          Scroll() {
            Column({ space: 12 }) {
              if (this.result === null) {
                Column({ space: 8 }) {
                  Text('左侧配置变量范围后运行仿真')
                    .fontSize(14)
                    .fontColor($r('sys.color.font_secondary'))
                  Text('将输出 12 月末现金分布、亏损概率与关键变量敏感度')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_tertiary'))
                }
                .width('100%')
                .padding(40)
              } else {
                Text(`结果（${this.result.runs} 次抽样）`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .width('100%')
                MetricCard({
                  title: '12 月末累计现金 P5 / P50 / P95',
                  value: `${fmtMoney(this.result.cashP5)} / ${fmtMoney(this.result.cashP50)} / ${fmtMoney(this.result.cashP95)} 元`,
                  sub: 'P5 = 悲观 5% 分位，P95 = 乐观 95% 分位'
                })
                MetricCard({
                  title: '首月利润 P5 / P50 / P95',
                  value: `${fmtMoney(this.result.profitP5)} / ${fmtMoney(this.result.profitP50)} / ${fmtMoney(this.result.profitP95)} 元`
                })
                MetricCard({
                  title: '12 个月后仍亏损的概率',
                  value: `${fmtNum(this.result.lossProb)}%`,
                  color: this.result.lossProb > 40 ? '#d03050' : (this.result.lossProb > 15 ? '#d9822b' : '#2e9e6b')
                })
                MetricCard({
                  title: '12 个月内回本（现金转正）的概率',
                  value: `${fmtNum(this.result.paybackProb)}%`,
                  color: this.result.paybackProb > 60 ? '#d03050' : '#333333'
                })

                Column({ space: 8 }) {
                  Text('12 月末现金分布（红色 = 亏损区）')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                  HistogramChart({
                    bins: this.result.histBins,
                    start: this.result.histStart,
                    step: this.result.histStep
                  })
                }
                .padding(12)
                .borderRadius(12)
                .backgroundColor($r('sys.color.comp_background_primary'))
                .width('100%')

                Column({ space: 10 }) {
                  Text('变量敏感度（对现金波动的方差贡献）')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .width('100%')
                  ForEach(this.result.sensitivity, (s: SensItem) => {
                    this.sensBar(s.name, s.share)
                  }, (s: SensItem) => s.name)
                }
                .padding(12)
                .borderRadius(12)
                .backgroundColor($r('sys.color.comp_background_primary'))
                .width('100%')
              }
            }
            .width('100%')
          }
          .layoutWeight(3)
          .align(Alignment.Top)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}

interface SensItem {
  name: string;
  share: number;
}
