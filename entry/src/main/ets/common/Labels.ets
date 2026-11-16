import { SensorKey, DeviceKey, CompareOp, RuleCondition, RuleAction } from '../model/Types';

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
