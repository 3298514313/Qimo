/**
 * 全局数据模型定义
 * 主题三：联动实验室——智能宿舍自动化规则编排 App
 */

/** 可被环境感知的传感器数据项（Mock 环境数据，共 4 项，满足“至少 3 项”要求） */
export enum SensorKey {
  Temperature = 'temperature',
  Humidity = 'humidity',
  Illuminance = 'illuminance',
  Presence = 'presence'
}

/** 可控制的宿舍设备类型（共 4 类，满足“至少 4 类”要求） */
export enum DeviceKey {
  AirConditioner = 'airConditioner',
  Light = 'light',
  Curtain = 'curtain',
  Humidifier = 'humidifier'
}

/** 条件比较运算符 */
export enum CompareOp {
  GT = '>',
  LT = '<',
  EQ = '==',
  GTE = '>=',
  LTE = '<='
}

/** 多条件之间的逻辑关系 */
export enum LogicOp {
  AND = 'AND',
  OR = 'OR'
}

/** 单条触发条件：当传感器值满足比较关系时成立 */
export interface RuleCondition {
  sensor: SensorKey;
  op: CompareOp;
  value: number;
}

/** 单条设备动作 */
export interface RuleAction {
  target: DeviceKey;
  /** turnOn / turnOff / setLevel */
  command: string;
  /** setLevel 时的目标档位（亮度/温度/湿度/开合度），可空 */
  param?: number;
}

/** 联动规则 */
export interface Rule {
  id: string;
  name: string;
  enabled: boolean;
  logic: LogicOp;
  conditions: RuleCondition[];
  actions: RuleAction[];
  /** 冲突仲裁优先级：数值越大优先级越高 */
  priority: number;
  createdAt: number;
}

/** 设备当前状态 */
export interface DeviceState {
  key: DeviceKey;
  powered: boolean;
  /** 档位：空调目标温度 / 灯光亮度 / 窗帘开合度 / 加湿器档位 */
  level: number;
}

/** 模拟环境快照 */
export interface EnvSnapshot {
  /** 室内温度 ℃ */
  temperature: number;
  /** 室内湿度 %RH */
  humidity: number;
  /** 光照强度 lux */
  illuminance: number;
  /** 是否有人：1 有人 / 0 无人 */
  presence: number;
}

/** 动作执行结果状态 */
export type ActionStatus = 'success' | 'blocked' | 'conflict-won';

/** 一条已执行动作的记录 */
export interface ExecutedAction {
  ruleId: string;
  ruleName: string;
  rulePriority: number;
  /** 触发该动作的条件快照，写入日志后即使规则被修改也可追溯 */
  conditionSummary: string;
  target: DeviceKey;
  command: string;
  param?: number;
  status: ActionStatus;
  /** 执行顺序/仲裁说明，便于界面直接展示 */
  note: string;
}

/** 设备控制冲突记录 */
export interface ConflictRecord {
  device: DeviceKey;
  winnerRuleId: string;
  winnerRuleName: string;
  loserRuleId: string;
  loserRuleName: string;
  reason: string;
}

/** 一次模拟演练的执行日志 */
export interface LogEntry {
  id: string;
  timestamp: number;
  scenarioName: string;
  env: EnvSnapshot;
  triggeredRuleIds: string[];
  actions: ExecutedAction[];
  conflicts: ConflictRecord[];
  /** 演练前后设备快照，用于展示设备变化 */
  deviceBefore: DeviceState[];
  deviceAfter: DeviceState[];
}

/** 可保存的环境场景（设备设置 + 环境数据） */
export interface Scenario {
  id: string;
  name: string;
  /** 场景说明，用于首页/演练页展示 */
  description: string;
  /** 预期联动结果，便于验收 */
  expectation: string;
  env: EnvSnapshot;
  devices: DeviceState[];
}

/** 规则引擎一次评估的返回结果 */
export interface EvaluateResult {
  devices: DeviceState[];
  log: LogEntry;
}

/** 环境数据局部补丁（字段均可空） */
export interface EnvPatch {
  temperature?: number;
  humidity?: number;
  illuminance?: number;
  presence?: number;
}
