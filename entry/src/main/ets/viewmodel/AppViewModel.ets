import { common } from '@kit.AbilityKit';
import {
  Rule,
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
import { genId } from '../common/Constants';
import { cloneRule, cloneDevice, cloneEnv, cloneScenario } from '../common/Clone';

/**
 * 应用全局视图模型（单例）。
 * 持有规则、设备、环境、场景、日志等核心状态，串联规则引擎、本地持久化与事件总线。
 * 页面通过调用其方法修改状态，再从单例回读数据刷新界面。
 */
export class AppViewModel {
  private static instance: AppViewModel | null = null;

  rules: Rule[] = [];
  devices: DeviceState[] = [];
  env: EnvSnapshot = defaultEnv();
  scenarios: Scenario[] = [];
  logs: LogEntry[] = [];

  private engine: RuleEngine = new RuleEngine();
  private store: PreferencesStore = new PreferencesStore();

  private constructor() {
  }

  static getInstance(): AppViewModel {
    if (AppViewModel.instance === null) {
      AppViewModel.instance = new AppViewModel();
    }
    return AppViewModel.instance;
  }

  /** 在 Ability 启动时注入上下文并初始化持久化存储 */
  init(context: common.Context): void {
    this.store.init(context);
  }

  /** 进程重启后从 Preferences 恢复核心数据；数据缺失或损坏时回退到 Mock 默认值 */
  async restore(): Promise<void> {
    this.rules = await this.store.getJson<Rule[]>('rules', defaultRules());
    this.devices = await this.store.getJson<DeviceState[]>('devices', defaultDevices());
    this.scenarios = await this.store.getJson<Scenario[]>('scenarios', defaultScenarios());
    this.logs = await this.store.getJson<LogEntry[]>('logs', []);
  }

  /** 将当前核心数据整体写入本地持久化 */
  private async persistAll(): Promise<void> {
    await this.store.saveRules(this.rules);
    await this.store.saveDevices(this.devices);
    await this.store.saveScenarios(this.scenarios);
    await this.store.saveLogs(this.logs);
  }

  private emptyPayload(): AppPayload {
    const payload: AppPayload = {};
    return payload;
  }

  /** 执行一次模拟演练：计算规则触发、更新设备、写入日志并持久化 */
  async runSimulation(scenarioName: string): Promise<LogEntry> {
    const result = this.engine.evaluate(this.rules, this.env, this.devices, scenarioName);
    this.devices = result.devices;
    const log = result.log;
    const rest = this.logs.slice(0, 49);
    this.logs = [log].concat(rest);
    await this.persistAll();
    const payload: AppPayload = { logId: log.id };
    EventBus.emit(AppEvent.DEVICES_CHANGED, payload);
    EventBus.emit(AppEvent.LOG_PUSHED, payload);
    return log;
  }

  addRule(rule: Rule): void {
    this.rules = [cloneRule(rule)].concat(this.rules);
    void this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
  }

  updateRule(rule: Rule): void {
    this.rules = this.rules.map((r: Rule) => r.id === rule.id ? cloneRule(rule) : r);
    void this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
  }

  toggleRule(ruleId: string): void {
    this.rules = this.rules.map((r: Rule) => {
      if (r.id === ruleId) {
        const copy = cloneRule(r);
        copy.enabled = !copy.enabled;
        return copy;
      }
      return r;
    });
    void this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
  }

  deleteRule(ruleId: string): void {
    this.rules = this.rules.filter((r: Rule) => r.id !== ruleId);
    void this.persistAll();
    EventBus.emit(AppEvent.RULES_CHANGED, this.emptyPayload());
  }

  /** 调整 Mock 环境数据（局部补丁） */
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

  /** 以当前环境与设备状态保存为一个场景 */
  async saveScenario(name: string): Promise<void> {
    const scenario: Scenario = {
      id: genId(),
      name: name.trim().length > 0 ? name.trim() : `场景 ${this.scenarios.length + 1}`,
      env: cloneEnv(this.env),
      devices: this.devices.map((d: DeviceState) => cloneDevice(d))
    };
    this.scenarios = this.scenarios.concat(cloneScenario(scenario));
    await this.persistAll();
    EventBus.emit(AppEvent.SCENARIOS_CHANGED, this.emptyPayload());
  }

  /** 载入已有场景：恢复环境数据与设备设置 */
  loadScenario(scenarioId: string): void {
    const scenario = this.scenarios.find((s: Scenario) => s.id === scenarioId);
    if (scenario) {
      this.env = cloneEnv(scenario.env);
      this.devices = scenario.devices.map((d: DeviceState) => cloneDevice(d));
      EventBus.emit(AppEvent.DEVICES_CHANGED, this.emptyPayload());
    }
  }

  clearLogs(): void {
    this.logs = [];
    void this.persistAll();
    EventBus.emit(AppEvent.LOG_PUSHED, this.emptyPayload());
  }
}
