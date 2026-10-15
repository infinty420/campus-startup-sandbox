/**
 * 决策看板：AHP 两两比较 → 权重（含一致性检验）→ TOPSIS 排序 → 自动结论
 */
import { router } from '@kit.ArkUI';
import { Plan } from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { simulate, fmtMoney, fmtNum } from '../service/SimEngine';
import {
  CRITERIA, ahpWeights, matrixFromWeights, presetWeights,
  topsis, buildConclusion, AhpResult, TopsisResult
} from '../service/DecisionEngine';
import { MetricCard } from '../components/MetricCard';
import { TitleBar } from '../components/TitleBar';

const SCALE_OPTIONS: string[] = [
  '前者极重要 9', '前者强烈重要 7', '前者较重要 5', '前者略重要 3', '同等重要 1',
  '后者略重要 1/3', '后者较重要 1/5', '后者强烈重要 1/7', '后者极重要 1/9'
];
const SCALE_VALUES: number[] = [9, 7, 5, 3, 1, 1 / 3, 1 / 5, 1 / 7, 1 / 9];

@Entry
@Component
struct DecisionPage {
  private store: PlanStore = PlanStore.getInstance();
  @State plans: Plan[] = [];
  @State matrix: number[] = matrixFromWeights([1, 1, 1, 1, 1, 1]);

  aboutToAppear(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
    });
  }

  private ahp(): AhpResult {
    return ahpWeights(this.matrix);
  }

  private result(): TopsisResult {
    return topsis(this.plans, this.ahp().weights);
  }

  private pairs(): number[][] {
    const out: number[][] = [];
    const n = CRITERIA.length;
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        out.push([i, j]);
      }
    }
    return out;
  }

  private scaleIndexOf(v: number): number {
    let best = 4;
    let dist = 1e9;
    for (let k = 0; k < SCALE_VALUES.length; k++) {
      const d = Math.abs(SCALE_VALUES[k] - v);
      if (d < dist) {
        dist = d;
        best = k;
      }
    }
    return best;
  }

  private applyPreset(profile: string): void {
    this.matrix = matrixFromWeights(presetWeights(profile));
  }

  @Builder
  weightBar(name: string, w: number) {
    Column({ space: 3 }) {
      Row() {
        Text(name)
          .fontSize(12)
          .layoutWeight(1)
        Text(`${fmtNum(w * 100)}%`)
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
          .width(`${Math.max(2, Math.min(100, w * 100))}%`)
          .height(8)
          .borderRadius(4)
          .backgroundColor('#7262fd')
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      TitleBar({ title: '决策看板', subtitle: 'AHP 权重 + TOPSIS 排序 · 自动结论' })

      if (this.plans.length === 0) {
        Column() {
          Text('请先在首页创建方案')
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Row({ space: 16 }) {
          // 左：AHP 两两比较
          Scroll() {
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Text('权重预设：')
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                ForEach(['均衡', '求稳', '激进'], (s: string) => {
                  Text(s)
                    .fontSize(13)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(12)
                    .backgroundColor($r('sys.color.comp_background_secondary'))
                    .onClick(() => this.applyPreset(s))
                }, (s: string) => s)
              }
              .width('100%')

              ForEach(this.pairs(), (pair: number[], idx: number) => {
                Column({ space: 4 }) {
                  Text(`${CRITERIA[pair[0]]} vs ${CRITERIA[pair[1]]}`)
                    .fontSize(12)
                    .fontColor($r('sys.color.font_secondary'))
                  Select(SCALE_OPTIONS.map((s: string) => {
                    const o: SelectOption = { value: s };
                    return o;
                  }))
                    .selected(this.scaleIndexOf(this.matrix[pair[0] * CRITERIA.length + pair[1]]))
                    .value(SCALE_OPTIONS[this.scaleIndexOf(this.matrix[pair[0] * CRITERIA.length + pair[1]])])
                    .font({ size: 13 })
                    .width('100%')
                    .onSelect((k: number) => {
                      const v = SCALE_VALUES[k];
                      const n = CRITERIA.length;
                      this.matrix[pair[0] * n + pair[1]] = v;
                      this.matrix[pair[1] * n + pair[0]] = 1 / v;
                      this.matrix = this.matrix.slice();
                    })
                }
                .width('100%')
              }, (pair: number[]) => `p_${pair[0]}_${pair[1]}`)

              Column({ space: 6 }) {
                Text('当前权重')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .width('100%')
                ForEach(CRITERIA, (c: string, i: number) => {
                  this.weightBar(c, this.ahp().weights[i])
                }, (c: string) => c)
                if (!this.ahp().consistent) {
                  Text(`⚠ 一致性比率 CR = ${fmtNum(this.ahp().cr, 3)} > 0.1，判断存在矛盾，建议用权重预设修正`)
                    .fontSize(11)
                    .fontColor('#d03050')
                    .width('100%')
                } else {
                  Text(`一致性检验通过（CR = ${fmtNum(this.ahp().cr, 3)} < 0.1）`)
                    .fontSize(11)
                    .fontColor('#2e9e6b')
                    .width('100%')
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
          }
          .layoutWeight(2)
          .align(Alignment.Top)

          // 右：TOPSIS 结果
          Scroll() {
            Column({ space: 12 }) {
              Text('综合排序（TOPSIS 贴近度，越接近 1 越优）')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')

              ForEach(this.result().rows, (row: RankRow, idx: number) => {
                Column({ space: 6 }) {
                  Row() {
                    Text(`第 ${idx + 1} 名`)
                      .fontSize(13)
                      .fontColor(idx === 0 ? '#d03050' : $r('sys.color.font_secondary'))
                      .width(56)
                    Text(row.name)
                      .fontSize(15)
                      .fontWeight(idx === 0 ? FontWeight.Bold : FontWeight.Normal)
                      .layoutWeight(1)
                    Text(row.score.toFixed(3))
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')
                  Stack({ alignContent: Alignment.Start }) {
                    Column()
                      .width('100%')
                      .height(10)
                      .borderRadius(5)
                      .backgroundColor($r('sys.color.comp_background_tertiary'))
                    Column()
                      .width(`${Math.max(2, row.score * 100)}%`)
                      .height(10)
                      .borderRadius(5)
                      .backgroundColor(idx === 0 ? '#d03050' : '#5b8ff9')
                  }
                  .width('100%')
                }
                .padding(10)
                .borderRadius(10)
                .backgroundColor(idx === 0 ? '#fdece8' : $r('sys.color.comp_background_secondary'))
                .width('100%')
              }, (row: RankRow) => row.name)

              Column({ space: 6 }) {
                Text('评估结论（本地规则生成）')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                Text(this.conclusionText())
                  .fontSize(13)
                  .lineHeight(22)
                  .width('100%')
              }
              .padding(12)
              .borderRadius(10)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .width('100%')
            }
            .width('100%')
            .padding({ top: 16, right: 16, bottom: 16 })
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

  private conclusionText(): string {
    return buildConclusion(this.plans, this.result(), this.ahp().weights);
  }
}

interface RankRow {
  name: string;
  score: number;
}
