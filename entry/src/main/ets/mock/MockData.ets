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

/** 默认设备状态 */
export function defaultDevices(): DeviceState[] {
  return [
    { key: DeviceKey.AirConditioner, powered: false, level: 26 },
    { key: DeviceKey.Light, powered: false, level: 80 },
    { key: DeviceKey.Curtain, powered: true, level: 100 },
    { key: DeviceKey.Humidifier, powered: false, level: 50 }
  ];
}

/**
 * 默认规则（共 4 条，满足“至少 4 条”要求）
 * 其中 R3 由两个条件共同决定（AND），满足“至少 1 条双条件规则”要求。
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
      name: '无人自动关灯拉帘',
      enabled: true,
      logic: LogicOp.AND,
      conditions: [
        { sensor: SensorKey.Presence, op: CompareOp.EQ, value: 0 }
      ],
      actions: [
        { target: DeviceKey.Light, command: 'turnOff' },
        { target: DeviceKey.Curtain, command: 'turnOff' }
      ],
      priority: 6,
      createdAt: now + 3
    }
  ];
}

/** 默认场景（共 2 组，满足“至少 2 组环境场景”要求） */
export function defaultScenarios(): Scenario[] {
  return [
    {
      id: 'sc-day',
      name: '白天在室',
      env: { temperature: 26, humidity: 55, illuminance: 600, presence: 1 },
      devices: defaultDevices()
    },
    {
      id: 'sc-night',
      name: '夜间宿舍',
      env: { temperature: 22, humidity: 45, illuminance: 50, presence: 1 },
      devices: defaultDevices()
    }
  ];
}
