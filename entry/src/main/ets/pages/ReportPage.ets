/**
 * 报告中心：HTML 分析报告生成 / 快照对比 / 全量备份恢复
 */
import { router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { Plan } from '../model/PlanV2';
import { PlanStore, SnapshotEntry } from '../service/PlanStore';
import { simulate, fmtMoney, fmtNum } from '../service/SimEngine';
import { generateReportHtml } from '../service/ReportGenerator';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct ReportPage {
  private store: PlanStore = PlanStore.getInstance();
  @State plans: Plan[] = [];
  @State planIdx: number = 0;
  @State lastPath: string = '';
  // 快照对比
  @State snapA: number = 0;
  @State snapB: number = 1;
  // 备份
  @State backupPath: string = '';

  aboutToAppear(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
    });
  }

  private selPlan(): Plan {
    return this.plans[this.planIdx];
  }

  private planOptions(): SelectOption[] {
    const opts: SelectOption[] = [];
    for (const p of this.plans) {
      const o: SelectOption = { value: p.name };
      opts.push(o);
    }
    return opts;
  }

  private snapsOf(): SnapshotEntry[] {
    if (this.plans.length === 0) {
      return [];
    }
    return this.store.getSnapshots(this.selPlan().id);
  }

  private snapTimeText(e: SnapshotEntry): string {
    const d = new Date(e.time);
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private generate(): void {
    if (this.plans.length === 0) {
      return;
    }
    const html = generateReportHtml(this.selPlan());
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      const dir = `${ctx.filesDir}/reports`;
      try {
        fileIo.mkdirSync(dir, true);
      } catch (e) {
        // 目录已存在则忽略
      }
      const d = new Date();
      const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
      const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}`;
      const path = `${dir}/${this.selPlan().name}_${stamp}.html`;
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, html);
      fileIo.closeSync(file);
      this.lastPath = path;
      this.getUIContext().getPromptAction().showToast({ message: '报告已生成' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: `生成失败：${e}` });
    }
  }

  private backup(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      const data = JSON.stringify({ version: 2, plans: this.plans });
      const path = `${ctx.filesDir}/创业方案备份_${Date.now()}.json`;
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      this.backupPath = path;
      this.getUIContext().getPromptAction().showToast({ message: '备份已导出' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: `备份失败：${e}` });
    }
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
        .width(40)
    }
    .width('100%')
  }

  @Builder
  diffRow(label: string, va: number, vb: number, fmt: (n: number) => string, higherBetter: boolean) {
    Row() {
      Text(label)
        .fontSize(13)
        .width(120)
      Text(fmt(va))
        .fontSize(13)
        .layoutWeight(1)
      Text(fmt(vb))
        .fontSize(13)
        .layoutWeight(1)
      Text(this.deltaText(va, vb, fmt, higherBetter))
        .fontSize(13)
        .width(110)
        .textAlign(TextAlign.End)
        .fontColor(this.deltaColor(va, vb, higherBetter))
    }
    .width('100%')
    .padding(6)
    .borderRadius(6)
    .backgroundColor($r('sys.color.comp_background_secondary'))
  }

  private deltaText(va: number, vb: number, fmt: (n: number) => string, higherBetter: boolean): string {
    const d = vb - va;
    if (Math.abs(d) < 1e-9) {
      return '持平';
    }
    const good = higherBetter ? d > 0 : d < 0;
    return `${d > 0 ? '+' : ''}${fmt(d)} ${good ? '↑' : '↓'}`;
  }

  private deltaColor(va: number, vb: number, higherBetter: boolean): string {
    const d = vb - va;
    if (Math.abs(d) < 1e-9) {
      return '#888888';
    }
    const good = higherBetter ? d > 0 : d < 0;
    return good ? '#d03050' : '#2e9e6b';
  }

  build() {
    Column() {
      TitleBar({ title: '报告中心', subtitle: 'HTML 分析报告 · 快照对比 · 备份' })

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
            // ---- 报告生成 ----
            Column({ space: 12 }) {
              Text('① 生成分析报告（本地 HTML，可打印/转 PDF）')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Select(this.planOptions())
                .selected(this.planIdx)
                .value(this.selPlan().name)
                .font({ size: 14 })
                .width('100%')
                .onSelect((idx: number) => {
                  this.planIdx = idx;
                  this.snapA = 0;
                  this.snapB = 1;
                })
              Button('生成报告')
                .fontSize(14)
                .width('100%')
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => this.generate())
              if (this.lastPath.length > 0) {
                Text(`已生成：${this.lastPath}`)
                  .fontSize(12)
                  .fontColor('#2e9e6b')
                  .width('100%')
              }
            }
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .width('100%')

            // ---- 快照对比 ----
            Column({ space: 12 }) {
              Text('② 方案快照对比（每次保存自动留档，最近 10 个）')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              if (this.snapsOf().length < 2) {
                Text('快照不足 2 个：在编辑页多次保存方案后即可对比改参前后的变化。')
                  .fontSize(12)
                  .fontColor($r('sys.color.font_secondary'))
                  .width('100%')
              } else {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text('旧快照')
                      .fontSize(12)
                      .fontColor($r('sys.color.font_secondary'))
                    Select(this.snapOptions())
                      .selected(this.snapA)
                      .value(this.snapLabel(this.snapA))
                      .font({ size: 12 })
                      .onSelect((idx: number) => {
                        if (idx !== this.snapB) {
                          this.snapA = idx;
                        }
                      })
                  }
                  .layoutWeight(1)
                  Column({ space: 4 }) {
                    Text('新快照')
                      .fontSize(12)
                      .fontColor($r('sys.color.font_secondary'))
                    Select(this.snapOptions())
                      .selected(this.snapB)
                      .value(this.snapLabel(this.snapB))
                      .font({ size: 12 })
                      .onSelect((idx: number) => {
                        if (idx !== this.snapA) {
                          this.snapB = idx;
                        }
                      })
                  }
                  .layoutWeight(1)
                }
                .width('100%')

                if (this.snapA < this.snapsOf().length && this.snapB < this.snapsOf().length) {
                  Column({ space: 6 }) {
                    Row() {
                      Text('指标')
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .width(120)
                      Text(this.snapLabel(this.snapA))
                        .fontSize(12)
                        .layoutWeight(1)
                      Text(this.snapLabel(this.snapB))
                        .fontSize(12)
                        .layoutWeight(1)
                      Text('变化')
                        .fontSize(12)
                        .width(110)
                        .textAlign(TextAlign.End)
                    }
                    .width('100%')
                    this.diffRow('启动投入', simulate(this.snapsOf()[this.snapA].plan).startupTotal,
                      simulate(this.snapsOf()[this.snapB].plan).startupTotal,
                      (n: number) => fmtMoney(n), false)
                    this.diffRow('月收入', simulate(this.snapsOf()[this.snapA].plan).monthlyRevenue,
                      simulate(this.snapsOf()[this.snapB].plan).monthlyRevenue,
                      (n: number) => fmtMoney(n), true)
                    this.diffRow('月经营利润', simulate(this.snapsOf()[this.snapA].plan).monthlyProfit,
                      simulate(this.snapsOf()[this.snapB].plan).monthlyProfit,
                      (n: number) => fmtMoney(n), true)
                    this.diffRow('回本月数', simulate(this.snapsOf()[this.snapA].plan).paybackMonths > 0
                      ? simulate(this.snapsOf()[this.snapA].plan).paybackMonths : 99,
                      simulate(this.snapsOf()[this.snapB].plan).paybackMonths > 0
                        ? simulate(this.snapsOf()[this.snapB].plan).paybackMonths : 99,
                      (n: number) => n >= 99 ? '未回本' : fmtNum(n), false)
                    this.diffRow('年化 ROI %', simulate(this.snapsOf()[this.snapA].plan).annualRoi,
                      simulate(this.snapsOf()[this.snapB].plan).annualRoi,
                      (n: number) => fmtNum(n), true)
                  }
                  .width('100%')
                }
              }
            }
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .width('100%')

            // ---- 备份 ----
            Column({ space: 12 }) {
              Text('③ 全量备份')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Text(`将当前 ${this.plans.length} 个方案导出为 JSON 文件（应用沙箱内）`)
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
              Button('导出备份')
                .fontSize(14)
                .width('100%')
                .backgroundColor($r('sys.color.comp_background_secondary'))
                .fontColor($r('sys.color.brand'))
                .onClick(() => this.backup())
              if (this.backupPath.length > 0) {
                Text(`已导出：${this.backupPath}`)
                  .fontSize(12)
                  .fontColor('#2e9e6b')
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

  private snapOptions(): SelectOption[] {
    const opts: SelectOption[] = [];
    const snaps = this.snapsOf();
    for (let i = 0; i < snaps.length; i++) {
      const o: SelectOption = { value: this.snapTimeText(snaps[i]) };
      opts.push(o);
    }
    return opts;
  }

  private snapLabel(idx: number): string {
    const snaps = this.snapsOf();
    if (idx >= 0 && idx < snaps.length) {
      return this.snapTimeText(snaps[idx]);
    }
    return '-';
  }
}
