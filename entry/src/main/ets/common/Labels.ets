import {
  SensorKey,
  DeviceKey,
  CompareOp,
  LogicOp,
  Rule,
  RuleCondition,
  RuleAction
} from '../model/Types';

/** 传感器中文名称 */
export function sensorLabel(sensor: SensorKey): string {
  switch (sensor) {
    case SensorKey.Temperature:
      return '温度';
    case SensorKey.Humidity:
      return '湿度';
    case SensorKey.Illuminance:
      return '光照';
    case SensorKey.Presence:
      return '有人';
    default:
      return '未知';
  }
}

/** 设备中文名称 */
export function deviceLabel(device: DeviceKey): string {
  switch (device) {
    case DeviceKey.AirConditioner:
      return '空调';
    case DeviceKey.Light:
      return '灯光';
    case DeviceKey.Curtain:
      return '窗帘';
    case DeviceKey.Humidifier:
      return '加湿器';
    default:
      return '未知设备';
  }
}

/** 动作命令中文描述 */
export function commandLabel(command: string): string {
  switch (command) {
    case 'turnOn':
      return '打开';
    case 'turnOff':
      return '关闭';
    case 'setLevel':
      return '调档位';
    default:
      return command;
  }
}

/** 单条条件的可读文本 */
export function conditionText(cond: RuleCondition): string {
  const unit = cond.sensor === SensorKey.Temperature ? '℃'
    : cond.sensor === SensorKey.Humidity ? '%'
      : cond.sensor === SensorKey.Illuminance ? 'lux' : '';
  return `${sensorLabel(cond.sensor)} ${cond.op} ${cond.value}${unit}`;
}

/** 单条动作的可读文本 */
export function actionText(action: RuleAction): string {
  const level = action.param !== undefined ? `（${action.param}）` : '';
  return `${deviceLabel(action.target)}${commandLabel(action.command)}${level}`;
}

/** 整条规则的条件文案，AND / OR 自动使用中文连接词 */
export function conditionsText(rule: Rule): string {
  if (rule.conditions.length === 0) {
    return '未设置条件';
  }
  const joinText = rule.logic === LogicOp.OR ? ' 或 ' : ' 且 ';
  return rule.conditions.map((item: RuleCondition) => conditionText(item)).join(joinText);
}

/** 整条规则的动作文案，多动作使用顿号连接 */
export function actionsText(rule: Rule): string {
  if (rule.actions.length === 0) {
    return '未设置动作';
  }
  return rule.actions.map((item: RuleAction) => actionText(item)).join('、');
}

/** 设备档位单位 */
export function deviceUnit(device: DeviceKey): string {
  return device === DeviceKey.AirConditioner ? '℃' : '%';
}

/** 设备档位下限 */
export function deviceMin(device: DeviceKey): number {
  return device === DeviceKey.AirConditioner ? 16 : 0;
}

/** 设备档位上限 */
export function deviceMax(device: DeviceKey): number {
  return device === DeviceKey.AirConditioner ? 30 : 100;
}

/** 设备主题色，用于卡片和图表 */
export function deviceColor(device: DeviceKey): string {
  switch (device) {
    case DeviceKey.AirConditioner:
      return '#2F6BFF';
    case DeviceKey.Light:
      return '#F79009';
    case DeviceKey.Curtain:
      return '#7A5AF8';
    case DeviceKey.Humidifier:
      return '#12B76A';
    default:
      return '#667085';
  }
}

/** 设备图标用的单字，避免依赖外部图标资源 */
export function deviceIconText(device: DeviceKey): string {
  switch (device) {
    case DeviceKey.AirConditioner:
      return '冷';
    case DeviceKey.Light:
      return '灯';
    case DeviceKey.Curtain:
      return '帘';
    case DeviceKey.Humidifier:
      return '湿';
    default:
      return '设';
  }
}

/** 设备当前状态的简短文案 */
export function deviceStateText(powered: boolean, level: number, device: DeviceKey): string {
  if (!powered) {
    return '已关闭';
  }
  return `${level}${deviceUnit(device)}`;
}

/** 动作执行状态中文文案 */
export function statusLabel(status: string): string {
  switch (status) {
    case 'success':
      return '已执行';
    case 'conflict-won':
      return '仲裁生效';
    case 'blocked':
      return '已拦截';
    default:
      return status;
  }
}

/** 优先级标签 */
export function priorityLabel(priority: number): string {
  return `P${priority}`;
}

/** 运算符列表（供下拉选择） */
export const COMPARE_OPS: CompareOp[] = [
  CompareOp.GT,
  CompareOp.LT,
  CompareOp.EQ,
  CompareOp.GTE,
  CompareOp.LTE
];

/** 设备列表（供下拉选择） */
export const DEVICE_KEYS: DeviceKey[] = [
  DeviceKey.AirConditioner,
  DeviceKey.Light,
  DeviceKey.Curtain,
  DeviceKey.Humidifier
];

/** 动作命令列表（供下拉选择） */
export const ACTION_COMMANDS: string[] = ['turnOn', 'turnOff', 'setLevel'];
