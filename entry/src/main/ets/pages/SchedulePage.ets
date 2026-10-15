/**
 * 课表排班页：点选周课表 → 空闲窗口 / 冲突评估 / 排班建议
 */
import { router } from '@kit.ArkUI';
import { Plan } from '../model/PlanV2';
import { PlanStore } from '../service/PlanStore';
import { fmtNum } from '../service/SimEngine';
import {
  DAYS, SLOT_COUNT, SLOT_START_HOUR, defaultSchedule, isValidSchedule,
  totalFreeHours, businessDaysAvailable, freeWindows, windowText,
  evaluateConflicts, buildShifts, ConflictInfo, ShiftAssignment, TimeWindow
} from '../service/ScheduleEngine';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct SchedulePage {
  private store: PlanStore = PlanStore.getInstance();
  @State plans: Plan[] = [];
  @State sched: boolean[] = defaultSchedule();

  aboutToAppear(): void {
    this.store.ensureLoaded().then(() => {
      this.plans = this.store.getPlans().slice();
      const saved = this.store.getSchedule();
      if (isValidSchedule(saved)) {
        this.sched = saved.slice();
      }
    });
  }

  private toggle(day: number, hour: number): void {
    const idx = day * SLOT_COUNT + hour;
    this.sched[idx] = !this.sched[idx];
    this.sched = this.sched.slice();
    this.store.setSchedule(this.sched);
  }

  private hourLabel(h: number): string {
    return `${h + SLOT_START_HOUR}`;
  }

  @Builder
  cell(day: number, hour: number) {
    Column()
      .width(34)
      .height(26)
      .borderRadius(4)
      .backgroundColor(this.sched[day * SLOT_COUNT + hour] ? '#d03050' : '#2e9e6b')
      .opacity(this.sched[day * SLOT_COUNT + hour] ? 0.85 : 0.35)
      .onClick(() => this.toggle(day, hour))
  }

  build() {
    Column() {
      TitleBar({ title: '课表排班', subtitle: '学业冲突检查 · 排班建议' })

      Scroll() {
        Column({ space: 16 }) {
          // ---- 课表编辑 ----
          Column({ space: 10 }) {
            Text('① 点选你的周课表（红色 = 有课，绿色 = 空闲，8:00-20:00）')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Column({ space: 4 }) {
              // 表头：小时
              Row({ space: 4 }) {
                Text('')
                  .width(40)
                ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (h: number) => {
                  Text(this.hourLabel(h))
                    .fontSize(9)
                    .fontColor($r('sys.color.font_tertiary'))
                    .width(34)
                    .textAlign(TextAlign.Center)
                }, (h: number) => `h_${h}`)
              }
              .width('100%')
              ForEach([0, 1, 2, 3, 4, 5, 6], (d: number) => {
                Row({ space: 4 }) {
                  Text(DAYS[d])
                    .fontSize(11)
                    .width(40)
                  ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (h: number) => {
                    this.cell(d, h)
                  }, (h: number) => `c_${d}_${h}`)
                }
                .width('100%')
              }, (d: number) => `d_${d}`)
            }
            .width('100%')

            Row({ space: 16 }) {
              Text(`每周空闲：${totalFreeHours(this.sched)} 小时`)
                .fontSize(13)
              Text(`可营业天数（空闲≥3h）：${businessDaysAvailable(this.sched, 3)} 天`)
                .fontSize(13)
            }
            .width('100%')
          }
          .padding(14)
          .borderRadius(12)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .width('100%')

          // ---- 冲突评估 ----
          Column({ space: 10 }) {
            Text('② 方案学业冲突评估')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            if (this.plans.length === 0) {
              Text('暂无方案')
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
            } else {
              ForEach(evaluateConflicts(this.plans, this.sched), (c: ConflictInfo) => {
                Row() {
                  Text(c.planName)
                    .fontSize(14)
                    .layoutWeight(1)
                  Text(`需 ${fmtNum(c.required)} h/周`)
                    .fontSize(12)
                    .fontColor($r('sys.color.font_secondary'))
                  Text(c.conflict ? `⚠ 缺口 ${fmtNum(c.gap)} h` : '✓ 时间可行')
                    .fontSize(13)
                    .fontColor(c.conflict ? '#d03050' : '#2e9e6b')
                    .width(110)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .padding(8)
                .borderRadius(8)
                .backgroundColor($r('sys.color.comp_background_secondary'))
              }, (c: ConflictInfo) => c.planName)
              Text('口径：方案按每天营业 4 小时、每月 4.33 周折算创始人投入。')
                .fontSize(11)
                .fontColor($r('sys.color.font_tertiary'))
                .width('100%')
            }
          }
          .padding(14)
          .borderRadius(12)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .width('100%')

          // ---- 排班建议 ----
          Column({ space: 10 }) {
            Text('③ 建议营业窗口（连续空闲 ≥ 2 小时，贪心分配人力）')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            if (freeWindows(this.sched).length === 0) {
              Text('没有 ≥2 小时的连续空闲窗口，建议放弃档口类方案，考虑无人值守模式')
                .fontSize(13)
                .fontColor('#d03050')
                .width('100%')
            } else {
              ForEach(buildShifts(this.plans, this.sched), (a: ShiftAssignment) => {
                Row() {
                  Text(a.windowText)
                    .fontSize(13)
                    .layoutWeight(1)
                  Text(`${a.staff} 人`)
                    .fontSize(13)
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')
                .padding(8)
                .borderRadius(8)
                .backgroundColor($r('sys.color.comp_background_secondary'))
              }, (a: ShiftAssignment) => a.windowText)
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
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
