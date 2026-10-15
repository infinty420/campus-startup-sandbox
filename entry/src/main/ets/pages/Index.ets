/**
 * 首页：左侧品牌侧边栏 + 右侧方案库（统计带 / 模板 / 方案卡片）
 */
import { router } from '@kit.ArkUI';
import { Plan, createEmptyPlan, clonePlan, genId } from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { getTemplates } from '../service/Templates';
import { simulate, SimResult, fmtMoney } from '../service/SimEngine';
import { C_BRAND, C_BRAND_2, C_GREEN, C_RED, RISK_COLOR, CARD_SHADOW, typeEmoji } from '../common/Theme';

interface NavItem {
  icon: string;
  label: string;
  url: string;
}

const NAV_ITEMS: NavItem[] = [
  { icon: '⚖️', label: '方案对比', url: 'pages/ComparePage' },
  { icon: '🧪', label: '仿真实验室', url: 'pages/SimLabPage' },
  { icon: '🎯', label: '目标与预算', url: 'pages/SolverPage' },
  { icon: '🧭', label: '决策看板', url: 'pages/DecisionPage' },
  { icon: '📅', label: '课表排班', url: 'pages/SchedulePage' },
  { icon: '📄', label: '报告中心', url: 'pages/ReportPage' }
];

@Entry
@Component
struct Index {
  @State plans: Plan[] = [];
  private store: PlanStore = PlanStore.getInstance();

  aboutToAppear(): void {
    this.refresh();
  }

  onPageShow(): void {
    this.refresh();
  }

  refresh(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
    });
  }

  private createFromTemplate(idx: number): void {
    const templates = getTemplates();
    if (idx < 0 || idx >= templates.length) {
      return;
    }
    const t = templates[idx];
    const p = clonePlan(t, `${t.name}（副本）`);
    p.id = genId();
    this.store.savePlan(p).then(() => this.refresh());
  }

  private createBlank(): void {
    const p = createEmptyPlan('未命名方案', '自定义');
    this.store.savePlan(p).then(() => {
      this.refresh();
      router.pushUrl({ url: 'pages/PlanEditPage', params: { planId: p.id } });
    });
  }

  private duplicate(id: string): void {
    const src = this.store.getPlan(id);
    if (src === undefined) {
      return;
    }
    this.store.duplicatePlan(id, `${src.name}（副本）`).then(() => this.refresh());
  }

  private confirmDelete(id: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除方案',
      message: '删除后无法恢复，确定删除该方案？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: C_RED,
        action: () => {
          this.store.removePlan(id).then(() => this.refresh());
        }
      }
    });
  }

  // ---- 统计带数据 ----
  private avgProfit(): number {
    if (this.plans.length === 0) {
      return 0;
    }
    let sum = 0;
    for (const p of this.plans) {
      sum += simulate(p).monthlyProfit;
    }
    return sum / this.plans.length;
  }

  private totalStartup(): number {
    let sum = 0;
    for (const p of this.plans) {
      sum += simulate(p).startupTotal;
    }
    return sum;
  }

  private lowRiskCount(): number {
    let n = 0;
    for (const p of this.plans) {
      if (simulate(p).riskLevel === '低') {
        n++;
      }
    }
    return n;
  }

  // ---- 侧边栏 ----
  @Builder
  sideNav(item: NavItem) {
    Row({ space: 12 }) {
      Text(item.icon)
        .fontSize(18)
        .width(24)
        .textAlign(TextAlign.Center)
      Text(item.label)
        .fontSize(14)
        .fontColor('rgba(255,255,255,0.88)')
    }
    .width('100%')
    .padding({ left: 18, right: 12, top: 11, bottom: 11 })
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({ url: item.url });
    })
  }

  @Builder
  sidebar() {
    Column() {
      // 品牌区
      Row({ space: 12 }) {
        Text('¥')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(46)
          .height(46)
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .linearGradient({
            angle: 135,
            colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
          })
          .shadow({ radius: 10, color: 'rgba(124,58,237,0.45)', offsetY: 3 })
        Column({ space: 3 }) {
          Text('校园创业沙盘')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('成本 · 仿真 · 决策')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.55)')
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 22 })

      Text('工作台')
        .fontSize(11)
        .fontColor('rgba(255,255,255,0.40)')
        .letterSpacing(2)
        .width('100%')
        .padding({ left: 18, bottom: 8 })
        .textAlign(TextAlign.Start)

      ForEach(NAV_ITEMS, (item: NavItem) => {
        this.sideNav(item)
      }, (item: NavItem) => item.url)

      Blank()

      Row({ space: 6 }) {
        Text('🔒')
          .fontSize(12)
        Text('100% 本地运行 · 零联网')
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.45)')
      }
      .width('100%')
      .padding(16)
    }
    .width(220)
    .height('100%')
    .padding({ top: 22, bottom: 8 })
    .linearGradient({
      angle: 180,
      colors: [['#1E1B4B', 0.0], ['#312E81', 0.6], ['#3B3080', 1.0]]
    })
  }

  // ---- 统计带 ----
  @Builder
  statChip(label: string, value: string, color: ResourceColor) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
      Text(label)
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(CARD_SHADOW)
  }

  // ---- 方案卡片 ----
  @Builder
  cardStat(label: string, value: string, valueColor: ResourceColor) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  planCard(p: Plan) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(typeEmoji(p.name))
          .fontSize(20)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .borderRadius(12)
          .linearGradient({
            angle: 135,
            colors: [['rgba(79,70,229,0.12)', 0.0], ['rgba(124,58,237,0.16)', 1.0]]
          })
        Column({ space: 2 }) {
          Text(p.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(p.type)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(simulate(p).riskLevel + '风险')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 9, right: 9, top: 3, bottom: 3 })
          .borderRadius(10)
          .backgroundColor(RISK_COLOR[simulate(p).riskLevel])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('sys.color.comp_background_tertiary'))

      Row() {
        this.cardStat('启动投入', `${fmtMoney(simulate(p).startupTotal)}元`,
          $r('sys.color.font_primary'))
        this.cardStat('月净利润', `${fmtMoney(simulate(p).monthlyProfit)}元`,
          simulate(p).monthlyProfit >= 0 ? C_RED : C_GREEN)
        this.cardStat('回本周期', simulate(p).paybackMonths > 0
          ? `${simulate(p).paybackMonths.toFixed(1)}个月` : '无法回本',
          simulate(p).paybackMonths > 0 ? $r('sys.color.font_primary') : C_RED)
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('编辑')
          .fontSize(13)
          .height(32)
          .layoutWeight(1.4)
          .fontColor('#FFFFFF')
          .linearGradient({
            angle: 135,
            colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
          })
          .onClick(() => {
            router.pushUrl({ url: 'pages/PlanEditPage', params: { planId: p.id } });
          })
        Button('复制')
          .fontSize(13)
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .fontColor($r('sys.color.font_primary'))
          .border({ width: 1, color: $r('sys.color.comp_background_tertiary') })
          .onClick(() => this.duplicate(p.id))
        Button('删除')
          .fontSize(13)
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .fontColor(C_RED)
          .border({ width: 1, color: $r('sys.color.comp_background_tertiary') })
          .onClick(() => this.confirmDelete(p.id))
      }
      .width('100%')
    }
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({
      width: { left: 4 },
      color: { left: RISK_COLOR[simulate(p).riskLevel] }
    })
    .shadow(CARD_SHADOW)
    .width('100%')
  }

  // ---- 模板卡片（空态） ----
  @Builder
  templateCard(idx: number, t: Plan) {
    Row({ space: 12 }) {
      Text(typeEmoji(t.name))
        .fontSize(24)
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .linearGradient({
          angle: 135,
          colors: [['rgba(79,70,229,0.14)', 0.0], ['rgba(124,58,237,0.18)', 1.0]]
        })
      Column({ space: 3 }) {
        Text(t.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
        Text('点击一键创建，改改数字就能用')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('+')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(C_BRAND)
    }
    .width('47%')
    .margin({ right: 10, bottom: 10 })
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_background_tertiary') })
    .shadow(CARD_SHADOW)
    .onClick(() => this.createFromTemplate(idx))
  }

  build() {
    Row() {
      this.sidebar()

      // ---- 右侧主区 ----
      Column() {
        // 顶部标题区
        Row({ space: 16 }) {
          Column({ space: 3 }) {
            Text('方案库')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
            Text(this.plans.length > 0
              ? `共 ${this.plans.length} 个方案 · 数据保存在本机` : '创建你的第一个校园创业方案')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('+ 新建空白方案')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .height(40)
            .linearGradient({
              angle: 135,
              colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
            })
            .shadow({ radius: 10, color: 'rgba(79,70,229,0.35)', offsetY: 3 })
            .onClick(() => this.createBlank())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 22, bottom: 14 })

        // 统计带
        Row({ space: 12 }) {
          this.statChip('方案总数', `${this.plans.length}`, C_BRAND)
          this.statChip('平均月利润', this.plans.length > 0
            ? `${fmtMoney(this.avgProfit())}元` : '—',
            this.avgProfit() >= 0 ? C_RED : C_GREEN)
          this.statChip('总启动投入', this.plans.length > 0
            ? `${fmtMoney(this.totalStartup())}元` : '—', C_BRAND_2)
          this.statChip('低风险方案', `${this.lowRiskCount()} 个`, C_GREEN)
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 14 })

        // 内容区
        Scroll() {
          Column() {
            if (this.plans.length === 0) {
              // 空态 + 模板
              Column({ space: 14 }) {
                Text('🚀')
                  .fontSize(52)
                Text('从校园场景模板开始')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                Text('每个模板已预填一套合理的成本 / 收入 / 资源假设')
                  .fontSize(13)
                  .fontColor($r('sys.color.font_tertiary'))
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                  ForEach(getTemplates(), (t: Plan, idx: number) => {
                    this.templateCard(idx, t)
                  }, (t: Plan) => t.name)
                }
                .width('100%')
                .margin({ top: 8 })
              }
              .width('100%')
              .padding({ top: 40, left: 24, right: 24 })
            } else {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(this.plans, (p: Plan) => {
                  Column() {
                    this.planCard(p)
                  }
                  .width('31%')
                  .margin(5)
                }, (p: Plan) => p.id)
              }
              .width('100%')
              .padding({ left: 20, right: 20, bottom: 20 })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor($r('sys.color.background_primary'))
    }
    .width('100%')
    .height('100%')
  }
}
