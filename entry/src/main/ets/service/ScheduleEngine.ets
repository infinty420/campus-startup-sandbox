/**
 * 课表排班引擎：周课表 → 空闲窗口 / 可营业天数 / 方案学业冲突度 / 排班建议
 * 课表模型：7 天 × 12 个时段（8:00-20:00，每小时一格），true = 有课
 */
import { Plan } from '../model/PlanV2';

export const DAYS: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
export const SLOT_START_HOUR = 8;
export const SLOT_COUNT = 12;

export function defaultSchedule(): boolean[] {
  const s: boolean[] = [];
  for (let i = 0; i < DAYS.length * SLOT_COUNT; i++) {
    s.push(false);
  }
  return s;
}

export function isValidSchedule(s: boolean[]): boolean {
  return s.length === DAYS.length * SLOT_COUNT;
}

/** 某天的空闲时段数 */
export function freeSlotsOfDay(s: boolean[], day: number): number {
  let c = 0;
  for (let h = 0; h < SLOT_COUNT; h++) {
    if (!s[day * SLOT_COUNT + h]) {
      c++;
    }
  }
  return c;
}

/** 每周空闲总小时 */
export function totalFreeHours(s: boolean[]): number {
  let c = 0;
  for (const b of s) {
    if (!b) {
      c++;
    }
  }
  return c;
}

/** 每周可营业天数（空闲 ≥ minHours 的天） */
export function businessDaysAvailable(s: boolean[], minHours: number): number {
  let c = 0;
  for (let d = 0; d < DAYS.length; d++) {
    if (freeSlotsOfDay(s, d) >= minHours) {
      c++;
    }
  }
  return c;
}

export interface TimeWindow {
  day: number;
  startHour: number;
  endHour: number; // 不含
}

/** 提取连续空闲窗口（≥ 2 小时） */
export function freeWindows(s: boolean[]): TimeWindow[] {
  const out: TimeWindow[] = [];
  for (let d = 0; d < DAYS.length; d++) {
    let start = -1;
    for (let h = 0; h <= SLOT_COUNT; h++) {
      const free = h < SLOT_COUNT && !s[d * SLOT_COUNT + h];
      if (free && start < 0) {
        start = h;
      }
      if (!free && start >= 0) {
        if (h - start >= 2) {
          out.push({ day: d, startHour: start + SLOT_START_HOUR, endHour: h + SLOT_START_HOUR });
        }
        start = -1;
      }
    }
  }
  return out;
}

export function windowText(w: TimeWindow): string {
  return `${DAYS[w.day]} ${w.startHour}:00-${w.endHour}:00`;
}

/** 方案所需的创始人每周投入小时（假设每天营业 4 小时；每 4.33 周一月） */
export function requiredWeeklyHours(plan: Plan): number {
  const weeks = 4.33;
  return plan.daysPerMonth / weeks * 4;
}

export interface ConflictInfo {
  planName: string;
  required: number;   // 需要小时/周
  available: number;  // 空闲小时/周
  conflict: boolean;
  gap: number;        // 缺口（>0 表示冲突）
}

/** 全部方案的学业冲突评估 */
export function evaluateConflicts(plans: Plan[], s: boolean[]): ConflictInfo[] {
  const avail = totalFreeHours(s);
  const out: ConflictInfo[] = [];
  for (const p of plans) {
    const req = requiredWeeklyHours(p);
    out.push({
      planName: p.name,
      required: req,
      available: avail,
      conflict: req > avail,
      gap: Math.max(0, req - avail)
    });
  }
  return out;
}

export interface ShiftAssignment {
  windowText: string;
  staff: number;
}

/**
 * 贪心排班：把人力优先投到最长的空闲窗口，直至覆盖所需小时
 */
export function buildShifts(plans: Plan[], s: boolean[]): ShiftAssignment[] {
  const windows = freeWindows(s).slice();
  // 窗口按时长降序
  windows.sort((a: TimeWindow, b: TimeWindow) => (b.endHour - b.startHour) - (a.endHour - a.startHour));
  const out: ShiftAssignment[] = [];
  const totalHours = windows.reduce((acc: number, w: TimeWindow) => acc + (w.endHour - w.startHour), 0);
  if (windows.length === 0 || totalHours === 0) {
    return out;
  }
  let maxStaff = 1;
  for (const p of plans) {
    if (p.staffCount > maxStaff) {
      maxStaff = p.staffCount;
    }
  }
  for (const w of windows) {
    const len = w.endHour - w.startHour;
    // 主理人每窗 1 人；人力富余时给最长窗口加人
    let staff = 1;
    if (maxStaff > 1 && len >= 4) {
      staff = Math.min(maxStaff, 1 + Math.floor(len / 3));
    }
    const a: ShiftAssignment = { windowText: windowText(w), staff: staff };
    out.push(a);
  }
  return out;
}
