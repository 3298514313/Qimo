import { common } from '@kit.AbilityKit';
import {
  Rule,
  DeviceKey,
  DeviceState,
  Scenario,
  EnvSnapshot,
  EnvPatch,
  LogEntry
} from '../model/Types';
import {
  defaultEnv,
  defaultDevices,
  defaultRules,
  defaultScenarios
} from '../mock/MockData';
import { RuleEngine } from '../engine/RuleEngine';
import { PreferencesStore } from '../store/PreferencesStore';
import { EventBus, AppEvent, AppPayload } from '../bus/EventBus';
import { MAX_LOGS, genId } from '../common/Constants';
import {
  cloneRule,
  cloneDevice,
  cloneDevices,
  cloneEnv,
  cloneLog,
  cloneScenario
} from '../common/Clone';
import { validateEnv } from '../common/Validation';

/**
 * 应用全局视图模型（单例）。
 * 页面只通过本类读写业务状态；规则计算、持久化与事件通知都集中在这里，
 * 从而避免页面之间直接耦合。
 */
export class AppViewModel {
  private static instance: AppViewModel | null = null;

  rules: Rule[] = [];
  devices: DeviceState[] = [];
  env: EnvSnapshot = defaultEnv();
  scenarios: Scenario[] = [];
  logs: LogEntry[] = [];
  /** 最近一次持久化/恢复错误，空字符串表示正常 */
  lastError: string = '';
  ready: boolean = false;

  private engine: RuleEngine = new RuleEngine();
  private store: PreferencesStore = new PreferencesStore();
  private restorePromise: Promise<void> | null = null;

  private constructor() {
  }

  static getInstance(): AppViewModel {
    if (AppViewModel.instance === null) {
      AppViewModel.instance = new AppViewModel();
    }
    return AppViewModel.instance;
  }

  /** 在 Ability 启动时注入上下文并初始化 Preferences */
  init(context: common.Context): void {
    try {
      this.store.init(context);
    } catch (error) {
      this.lastError = `本地存储初始化失败：${this.errorText(error)}`;
    }
  }

  /**
   * 冷启动恢复。多次调用共享同一个 Promise，避免页面并发读取覆盖状态。
   * 任一键损坏时回退到该键的演示数据，保证应用仍可进入。
   */
  async restore(): Promise<void> {
    if (this.ready) {
      return;
    }
    if (this.restorePromise !== null) {
      await this.restorePromise;
      return;
    }
    this.restorePromise = this.doRestore();
    try {
      await this.restorePromise;
    } finally {
      this.restorePromise = null;
    }
  }

  private async doRestore(): Promise<void> {
    try {
      const savedRules = await this.store.getJson<Rule[]>('rules', defaultRules());
      const savedDevices = await this.store.getJson<DeviceState[]>('devices', defaultDevices());
      const savedScenarios = await this.store.getJson<Scenario[]>('scenarios', defaultScenarios());
      const savedLogs = await this.store.getJson<LogEntry[]>('logs', []);
      const savedEnv = await this.store.getJson<EnvSnapshot>('env', defaultEnv());

      this.rules = Array.isArray(savedRules) ? savedRules.map((rule: Rule) => cloneRule(rule)) : defaultRules();
      this.devices = this.normalizeDevices(savedDevices);
      this.scenarios = this.normalizeScenarios(savedScenarios);
      this.logs = this.normalizeLogs(savedLogs);
      this.env = this.normalizeEnv(savedEnv);
      this.lastError = '';
    } catch (error) {
      this.applyDefaults();
      this.lastError = `本地数据恢复失败，已载入默认演示数据：${this.errorText(error)}`;
    }
    this.ready = true;
    EventBus.emit(AppEvent.DATA_READY, this.emptyPayload());
  }

  private applyDefaults(): void {
    this.rules = defaultRules();
    this.devices = defaultDevices();
    this.scenarios = defaultScenarios();
    this.logs = [];
    this.env = defaultEnv();
  }

  private normalizeDevices(saved: DeviceState[]): DeviceState[] {
    if (!Array.isArray(saved)) {
      return defaultDevices();
    }
    const defaults = defaultDevices();
    return defaults.map((fallback: DeviceState) => {
      const found = saved.find((item: DeviceState) => item.key === fallback.key);
      if (found === undefined || !Number.isFinite(found.level)) {
        return fallback;
      }
      return {
        key: fallback.key,
        powered: found.powered === true,
        level: found.level
      };
    });
  }

  private normalizeScenarios(saved: Scenario[]): Scenario[] {
    if (!Array.isArray(saved) || saved.length === 0) {
      return defaultScenarios();
    }
    return saved
      .filter((item: Scenario) => item !== null && item !== undefined && item.id !== undefined)
      .map((item: Scenario): Scenario => {
        const description = typeof item.description === 'string' ? item.description : '用户保存的场景';
        const expectation = typeof item.expectation === 'string' ? item.expectation : '按当前规则计算联动结果';
        return {
          id: item.id,
          name: item.name,
          description: description,
          expectation: expectation,
          env: cloneEnv(item.env),
          devices: cloneDevices(item.devices)
        };
      });
  }

  private normalizeEnv(saved: EnvSnapshot): EnvSnapshot {
    if (saved === null || saved === undefined) {
      return defaultEnv();
    }
    if (validateEnv(saved).length > 0) {
      return defaultEnv();
    }
    return cloneEnv(saved);
  }

  private normalizeLogs(saved: LogEntry[]): LogEntry[] {
    if (!Array.isArray(saved)) {
      return [];
    }
    const result: LogEntry[] = [];
    saved.forEach((item: LogEntry) => {
      if (item === null || item === undefined ||
        !Array.isArray(item.actions) || !Array.isArray(item.conflicts) ||
        !Array.isArray(item.deviceBefore) || !Array.isArray(item.deviceAfter)) {
        return;
      }
      result.push(cloneLog(item));
    });
    return result.slice(0, MAX_LOGS);
  }

  /** 持久化全部核心数据；失败时保留内存状态并发出错误事件 */
  private async persistAll(): Promise<boolean> {
    try {
      await this.store.saveRules(this.rules);
      await this.store.saveDevices(this.devices);
      await this.store.saveScenarios(this.scenarios);
      await this.store.saveLogs(this.logs);
      await this.store.saveEnv(this.env);
      this.lastError = '';
      EventBus.emit(AppEvent.PERSISTED, this.emptyPayload());
      return true;
    } catch (error) {
      this.lastError = `本地保存失败：${this.errorText(error)}`;
      const payload: AppPayload = { message: this.lastError };
      EventBus.emit(AppEvent.PERSIST_FAILED, payload);
      return false;
    }
  }

  private emptyPayload(): AppPayload {
    const payload: AppPayload = {};
    return payload;
  }

  private errorText(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return '未知错误';
  }

  /** 执行一次模拟演练；环境非法时抛出可读异常，由页面捕获展示 */
  async runSimulation(scenarioName: string): Promise<LogEntry> {
    const errors = validateEnv(this.env);
    if (errors.length > 0) {
      throw new Error(errors[0]);
    }
    const result = this.engine.evaluate(this.rules, this.env, this.devices, scenarioName);
    this.devices = result.devices;
    const log = result.log;
    this.logs = [log].concat(this.logs.slice(0, MAX_LOGS - 1));
    await this.persistAll();
    const payload: AppPayload = { logId: log.id };
    EventBus.emit(AppEvent.DEVICES_CHANGED, payload);
    EventBus.emit(AppEvent.LOG_PUSHED, payload);
    return log;
  }

  /** 恢复三组内置演示场景，便于验收时反复演示 */
  async resetDemoData(): Promise<void> {
    this.rules = defaultRules();
    this.devices = defaultDevices();
    this.scenarios = defaultScenarios();
    this.logs = [];
    this.env = defaultEnv();
    await this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
    EventBus.emit(AppEvent.DEVICES_CHANGED, this.emptyPayload());
    EventBus.emit(AppEvent.SCENARIOS_CHANGED, this.emptyPayload());
    EventBus.emit(AppEvent.LOG_PUSHED, this.emptyPayload());
  }

  async addRule(rule: Rule): Promise<boolean> {
    this.rules = [cloneRule(rule)].concat(this.rules);
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
    return saved;
  }

  async updateRule(rule: Rule): Promise<boolean> {
    this.rules = this.rules.map((item: Rule) => item.id === rule.id ? cloneRule(rule) : item);
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
    return saved;
  }

  async toggleRule(ruleId: string): Promise<boolean> {
    this.rules = this.rules.map((item: Rule) => {
      if (item.id !== ruleId) {
        return item;
      }
      const copy = cloneRule(item);
      copy.enabled = !copy.enabled;
      return copy;
    });
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
    return saved;
  }

  async deleteRule(ruleId: string): Promise<boolean> {
    this.rules = this.rules.filter((item: Rule) => item.id !== ruleId);
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
    return saved;
  }

  /** 调整 Mock 环境数据（局部补丁，不立即写盘，演练/保存时统一持久化） */
  adjustEnv(patch: EnvPatch): void {
    const next = cloneEnv(this.env);
    if (patch.temperature !== undefined) {
      next.temperature = patch.temperature;
    }
    if (patch.humidity !== undefined) {
      next.humidity = patch.humidity;
    }
    if (patch.illuminance !== undefined) {
      next.illuminance = patch.illuminance;
    }
    if (patch.presence !== undefined) {
      next.presence = patch.presence;
    }
    this.env = next;
  }

  /** 仅保存环境设置（滑块松手/有人开关切换时调用） */
  async saveEnvironment(): Promise<boolean> {
    return this.persistAll();
  }

  /** 手动控制设备，便于验证“规则执行后仍可人工干预” */
  async setDevicePower(deviceKey: DeviceKey, powered: boolean): Promise<boolean> {
    this.devices = this.devices.map((device: DeviceState) => {
      if (device.key !== deviceKey) {
        return device;
      }
      return { key: device.key, powered: powered, level: device.level };
    });
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.DEVICES_CHANGED, this.emptyPayload());
    return saved;
  }

  async setDeviceLevel(deviceKey: DeviceKey, level: number): Promise<boolean> {
    this.devices = this.devices.map((device: DeviceState) => {
      if (device.key !== deviceKey) {
        return device;
      }
      return { key: device.key, powered: device.powered, level: level };
    });
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.DEVICES_CHANGED, this.emptyPayload());
    return saved;
  }

  /** 以当前环境与设备状态保存为一个场景 */
  async saveScenario(name: string): Promise<boolean> {
    const env = cloneEnv(this.env);
    const scenario: Scenario = {
      id: genId(),
      name: name.trim().length > 0 ? name.trim() : `场景 ${this.scenarios.length + 1}`,
      description: `温度 ${env.temperature}℃、湿度 ${env.humidity}%、光照 ${env.illuminance}lux，` +
        `${env.presence === 1 ? '有人' : '无人'}。`,
      expectation: '用户保存的自定义场景，按当前启用规则计算联动结果。',
      env: env,
      devices: cloneDevices(this.devices)
    };
    this.scenarios = this.scenarios.concat(cloneScenario(scenario));
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.SCENARIOS_CHANGED, this.emptyPayload());
    return saved;
  }

  /** 载入场景：恢复环境与设备设置，并写回本地 */
  async loadScenario(scenarioId: string): Promise<boolean> {
    const scenario = this.scenarios.find((item: Scenario) => item.id === scenarioId);
    if (scenario === undefined) {
      return false;
    }
    this.env = cloneEnv(scenario.env);
    this.devices = cloneDevices(scenario.devices);
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.DEVICES_CHANGED, this.emptyPayload());
    return saved;
  }

  async clearLogs(): Promise<boolean> {
    this.logs = [];
    const saved = await this.persistAll();
    EventBus.emit(AppEvent.LOG_PUSHED, this.emptyPayload());
    return saved;
  }

  /** 规则列表中标记可能竞争同一设备的规则 */
  potentialConflictRuleIds(): string[] {
    return this.engine.potentialConflictRuleIds(this.rules);
  }
}
