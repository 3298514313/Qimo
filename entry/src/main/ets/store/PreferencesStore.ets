import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { STORAGE_KEYS } from '../common/Constants';

/**
 * Preferences 持久化封装。
 * 负责规则、设备状态、场景、执行日志的本地保存与重启恢复；
 * 读取失败时返回兜底默认值，保证应用在数据异常时仍可启动。
 */
export class PreferencesStore {
  private pref: preferences.Preferences | null = null;

  init(context: common.Context): void {
    this.pref = preferences.getPreferencesSync(context, { name: 'dorm_link_store' });
  }

  private async putRaw(key: string, value: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(key, value);
    await this.pref.flush();
  }

  private async getRaw(key: string, fallback: string): Promise<string> {
    if (!this.pref) {
      return fallback;
    }
    const value = await this.pref.get(key, fallback);
    return value as string;
  }

  /** 写入 JSON 数据 */
  async setJson<T>(key: string, value: T): Promise<void> {
    await this.putRaw(key, JSON.stringify(value));
  }

  /** 读取 JSON 数据，解析失败或为空时返回兜底值 */
  async getJson<T>(key: string, fallback: T): Promise<T> {
    const raw = await this.getRaw(key, '');
    if (!raw) {
      return fallback;
    }
    try {
      return JSON.parse(raw) as T;
    } catch (error) {
      console.error(`[PreferencesStore] 解析 ${key} 失败: ${JSON.stringify(error)}`);
      return fallback;
    }
  }

  async saveRules<T>(rules: T): Promise<void> {
    await this.setJson(STORAGE_KEYS.RULES, rules);
  }

  async saveDevices<T>(devices: T): Promise<void> {
    await this.setJson(STORAGE_KEYS.DEVICES, devices);
  }

  async saveScenarios<T>(scenarios: T): Promise<void> {
    await this.setJson(STORAGE_KEYS.SCENARIOS, scenarios);
  }

  async saveLogs<T>(logs: T): Promise<void> {
    await this.setJson(STORAGE_KEYS.LOGS, logs);
  }
}
