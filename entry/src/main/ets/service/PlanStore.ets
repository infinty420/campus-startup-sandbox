/**
 * 本地持久化（preferences + JSON，零联网零权限）
 * V2 起带版本号与链式迁移：{"version":2,"plans":[...]}
 * 旧版裸数组 [planV1,...] 自动迁移到 v2。
 */
import { preferences } from '@kit.ArkData';
import { Plan, clonePlan, genId } from '../model/PlanV2';
import { PlanV1, migrateV1toV2, isV1 } from '../model/Migration';

const STORE_NAME = 'campus_venture_store';
const KEY_DATA = 'plans_v2';
const KEY_LEGACY = 'plans';
const KEY_SCHEDULE = 'schedule';
const DATA_VERSION = 2;

interface StoreData {
  version: number;
  plans: Plan[];
}

export interface SnapshotEntry {
  time: number;   // 毫秒时间戳
  plan: Plan;
}

const SNAPSHOT_LIMIT = 10;

export class PlanStore {
  private static instance: PlanStore | null = null;
  private prefs: preferences.Preferences | null = null;
  private plans: Plan[] = [];
  private loading: Promise<void> = Promise.resolve();
  private loaded: boolean = false;

  static getInstance(): PlanStore {
    if (PlanStore.instance === null) {
      PlanStore.instance = new PlanStore();
    }
    return PlanStore.instance;
  }

  /** 在 EntryAbility.onCreate 中调用，只做一次 */
  init(context: Context): Promise<void> {
    this.loading = preferences.getPreferences(context, STORE_NAME).then((p: preferences.Preferences) => {
      this.prefs = p;
      // 优先读新版结构
      const rawV2 = p.getSync(KEY_DATA, '') as string;
      if (rawV2.length > 0) {
        try {
          const data = JSON.parse(rawV2) as StoreData;
          if (Array.isArray(data.plans)) {
            this.plans = data.plans;
          }
        } catch (e) {
          this.plans = [];
        }
      } else {
        // 旧版裸数组 → 链式迁移 v1→v2
        const rawV1 = p.getSync(KEY_LEGACY, '') as string;
        if (rawV1.length > 0) {
          try {
            const arr = JSON.parse(rawV1) as object[];
            if (Array.isArray(arr)) {
              for (const o of arr) {
                if (isV1(o)) {
                  this.plans.push(migrateV1toV2(o as PlanV1));
                }
              }
              if (this.plans.length > 0) {
                // 迁移结果立即落盘为 v2
                this.persist();
              }
            }
          } catch (e) {
            this.plans = [];
          }
        }
      }
      this.loaded = true;
    });
    return this.loading;
  }

  /** 页面调用：确保数据已加载完成 */
  ensureLoaded(): Promise<void> {
    if (this.loaded) {
      return Promise.resolve();
    }
    return this.loading;
  }

  getPlans(): Plan[] {
    return this.plans;
  }

  getPlan(id: string): Plan | undefined {
    for (const p of this.plans) {
      if (p.id === id) {
        return p;
      }
    }
    return undefined;
  }

  async savePlan(plan: Plan): Promise<void> {
    const idx = this.plans.findIndex((p: Plan) => p.id === plan.id);
    if (idx >= 0) {
      this.plans[idx] = plan;
    } else {
      this.plans.push(plan);
    }
    await this.persist();
    await this.addSnapshot(plan);
  }

  /** 保存时自动留快照（最近 10 个） */
  async addSnapshot(plan: Plan): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    const key = `snap_${plan.id}`;
    const raw = this.prefs.getSync(key, '') as string;
    let list: SnapshotEntry[] = [];
    if (raw.length > 0) {
      try {
        const arr = JSON.parse(raw) as SnapshotEntry[];
        if (Array.isArray(arr)) {
          list = arr;
        }
      } catch (e) {
        list = [];
      }
    }
    const entry: SnapshotEntry = { time: Date.now(), plan: plan };
    list.unshift(entry);
    if (list.length > SNAPSHOT_LIMIT) {
      list = list.slice(0, SNAPSHOT_LIMIT);
    }
    await this.prefs.put(key, JSON.stringify(list));
    await this.prefs.flush();
  }

  getSnapshots(planId: string): SnapshotEntry[] {
    if (this.prefs === null) {
      return [];
    }
    const raw = this.prefs.getSync(`snap_${planId}`, '') as string;
    if (raw.length === 0) {
      return [];
    }
    try {
      const arr = JSON.parse(raw) as SnapshotEntry[];
      if (Array.isArray(arr)) {
        return arr;
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  async removePlan(id: string): Promise<void> {
    this.plans = this.plans.filter((p: Plan) => p.id !== id);
    await this.persist();
  }

  async duplicatePlan(id: string, newName: string): Promise<Plan | null> {
    const src = this.getPlan(id);
    if (src === undefined) {
      return null;
    }
    const copy = clonePlan(src, newName);
    copy.id = genId();
    this.plans.push(copy);
    await this.persist();
    return copy;
  }

  private async persist(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    const data: StoreData = { version: DATA_VERSION, plans: this.plans };
    await this.prefs.put(KEY_DATA, JSON.stringify(data));
    await this.prefs.flush();
  }

  /** 周课表（7×12 布尔，true = 有课） */
  getSchedule(): boolean[] {
    if (this.prefs === null) {
      return [];
    }
    const raw = this.prefs.getSync(KEY_SCHEDULE, '') as string;
    if (raw.length === 0) {
      return [];
    }
    try {
      const arr = JSON.parse(raw) as boolean[];
      if (Array.isArray(arr)) {
        return arr;
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  async setSchedule(s: boolean[]): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    await this.prefs.put(KEY_SCHEDULE, JSON.stringify(s));
    await this.prefs.flush();
  }
}
