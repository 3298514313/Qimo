import {
  Rule,
  DeviceState,
  Scenario,
  EnvSnapshot,
  DeviceKey,
  SensorKey,
  CompareOp,
  LogicOp
} from '../model/Types';

/** 默认环境：白天、有人、温度适宜 */
export function defaultEnv(): EnvSnapshot {
  return {
    temperature: 26,
    humidity: 55,
    illuminance: 600,
    presence: 1
  };
}

/** 默认设备状态：空调/灯光/加湿器关闭，窗帘打开 */
export function defaultDevices(): DeviceState[] {
  return [
    { key: DeviceKey.AirConditioner, powered: false, level: 26 },
    { key: DeviceKey.Light, powered: false, level: 80 },
    { key: DeviceKey.Curtain, powered: true, level: 100 },
    { key: DeviceKey.Humidifier, powered: false, level: 50 }
  ];
}

/**
 * 默认规则（共 5 条，超过“至少 4 条”要求）。
 * - R3 由“光照 + 有人”两个条件共同决定（AND）；
 * - R1 与 R4 都会控制空调，在“无人高温”场景形成可观察的优先级冲突。
 */
export function defaultRules(): Rule[] {
  const now = Date.now();
  return [
    {
      id: 'rule-high-temp',
      name: '高温自动开空调',
      enabled: true,
      logic: LogicOp.AND,
      conditions: [
        { sensor: SensorKey.Temperature, op: CompareOp.GT, value: 28 }
      ],
      actions: [
        { target: DeviceKey.AirConditioner, command: 'turnOn' }
      ],
      priority: 10,
      createdAt: now
    },
    {
      id: 'rule-dry-humidify',
      name: '干燥自动开加湿器',
      enabled: true,
      logic: LogicOp.AND,
      conditions: [
        { sensor: SensorKey.Humidity, op: CompareOp.LT, value: 40 }
      ],
      actions: [
        { target: DeviceKey.Humidifier, command: 'turnOn' }
      ],
      priority: 5,
      createdAt: now + 1
    },
    {
      id: 'rule-dark-light',
      name: '有人且昏暗自动开灯',
      enabled: true,
      logic: LogicOp.AND,
      conditions: [
        { sensor: SensorKey.Illuminance, op: CompareOp.LT, value: 200 },
        { sensor: SensorKey.Presence, op: CompareOp.EQ, value: 1 }
      ],
      actions: [
        { target: DeviceKey.Light, command: 'turnOn' }
      ],
      priority: 8,
      createdAt: now + 2
    },
    {
      id: 'rule-none-off',
      name: '无人节能关灯关空调',
      enabled: true,
      logic: LogicOp.AND,
      conditions: [
        { sensor: SensorKey.Presence, op: CompareOp.EQ, value: 0 }
      ],
      actions: [
        { target: DeviceKey.Light, command: 'turnOff' },
        { target: DeviceKey.Curtain, command: 'turnOff' },
        { target: DeviceKey.AirConditioner, command: 'turnOff' }
      ],
      priority: 6,
      createdAt: now + 3
    },
    {
      id: 'rule-bright-off',
      name: '光照充足自动关灯',
      enabled: true,
      logic: LogicOp.AND,
      conditions: [
        { sensor: SensorKey.Illuminance, op: CompareOp.GT, value: 500 },
        { sensor: SensorKey.Presence, op: CompareOp.EQ, value: 1 }
      ],
      actions: [
        { target: DeviceKey.Light, command: 'turnOff' }
      ],
      priority: 4,
      createdAt: now + 4
    }
  ];
}

/** 默认场景（3 组，覆盖无冲突、开灯与优先级冲突三条路径） */
export function defaultScenarios(): Scenario[] {
  return [
    {
      id: 'sc-day',
      name: '白天在室',
      description: '26℃、55%、600lux，有人在宿舍。',
      expectation: '光照充足规则关闭灯光；高温、干燥规则不触发。',
      env: { temperature: 26, humidity: 55, illuminance: 600, presence: 1 },
      devices: defaultDevices()
    },
    {
      id: 'sc-night',
      name: '夜间宿舍',
      description: '22℃、45%、50lux，有人但光线很暗。',
      expectation: '有人且昏暗规则开灯；空调、加湿器保持关闭。',
      env: { temperature: 22, humidity: 45, illuminance: 50, presence: 1 },
      devices: defaultDevices()
    },
    {
      id: 'sc-hot-empty',
      name: '无人高温',
      description: '32℃、60%、700lux，宿舍无人。',
      expectation: '高温开空调与无人节能关空调冲突，P10 高温规则获胜。',
      env: { temperature: 32, humidity: 60, illuminance: 700, presence: 0 },
      devices: defaultDevices()
    }
  ];
}
