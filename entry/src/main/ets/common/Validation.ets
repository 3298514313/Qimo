import {
  DeviceKey,
  EnvSnapshot,
  Rule,
  RuleAction,
  RuleCondition,
  SensorKey
} from '../model/Types';
import {
  ACTION_COMMANDS,
  DEVICE_KEYS,
  deviceMax,
  deviceMin,
  sensorLabel
} from './Labels';

/** 传感器可接受的 Mock 数据范围 */
export function sensorMin(sensor: SensorKey): number {
  switch (sensor) {
    case SensorKey.Temperature:
      return 0;
    case SensorKey.Humidity:
      return 0;
    case SensorKey.Illuminance:
      return 0;
    default:
      return 0;
  }
}

export function sensorMax(sensor: SensorKey): number {
  switch (sensor) {
    case SensorKey.Temperature:
      return 50;
    case SensorKey.Humidity:
      return 100;
    case SensorKey.Illuminance:
      return 2000;
    default:
      return 1;
  }
}

/** 校验环境数据，供演练页在运行前拦截非法输入 */
export function validateEnv(env: EnvSnapshot): string[] {
  const errors: string[] = [];
  if (!Number.isFinite(env.temperature) || env.temperature < 0 || env.temperature > 50) {
    errors.push('温度需在 0–50℃ 之间');
  }
  if (!Number.isFinite(env.humidity) || env.humidity < 0 || env.humidity > 100) {
    errors.push('湿度需在 0–100% 之间');
  }
  if (!Number.isFinite(env.illuminance) || env.illuminance < 0 || env.illuminance > 2000) {
    errors.push('光照需在 0–2000lux 之间');
  }
  if (env.presence !== 0 && env.presence !== 1) {
    errors.push('“是否有人”只能是 0 或 1');
  }
  return errors;
}

function validateCondition(condition: RuleCondition, index: number): string[] {
  const errors: string[] = [];
  if (!Number.isFinite(condition.value)) {
    errors.push(`条件 ${index} 的阈值不是有效数字`);
    return errors;
  }
  if (condition.sensor === SensorKey.Presence) {
    if (condition.value !== 0 && condition.value !== 1) {
      errors.push('“有人”条件的阈值只能是 0 或 1');
    }
    return errors;
  }
  const min = sensorMin(condition.sensor);
  const max = sensorMax(condition.sensor);
  if (condition.value < min || condition.value > max) {
    errors.push(`${sensorLabel(condition.sensor)}条件需在 ${min}–${max} 之间`);
  }
  return errors;
}

function validateAction(action: RuleAction, index: number): string[] {
  const errors: string[] = [];
  if (DEVICE_KEYS.indexOf(action.target) < 0) {
    errors.push(`动作 ${index} 的设备类型无效`);
  }
  if (ACTION_COMMANDS.indexOf(action.command) < 0) {
    errors.push(`动作 ${index} 的命令无效`);
  }
  if (action.command === 'setLevel') {
    if (action.param === undefined || !Number.isFinite(action.param)) {
      errors.push(`动作 ${index} 缺少有效档位`);
    } else if (action.param < deviceMin(action.target) || action.param > deviceMax(action.target)) {
      errors.push(`动作 ${index} 的档位需在 ${deviceMin(action.target)}–${deviceMax(action.target)} 之间`);
    }
  }
  return errors;
}

/** 保存规则前的统一校验，页面与单元测试共用 */
export function validateRule(rule: Rule): string[] {
  const errors: string[] = [];
  if (rule.name.trim().length === 0) {
    errors.push('规则名称不能为空');
  } else if (rule.name.trim().length > 30) {
    errors.push('规则名称不能超过 30 个字符');
  }
  if (!Number.isFinite(rule.priority) || Math.round(rule.priority) !== rule.priority) {
    errors.push('优先级必须是整数');
  } else if (rule.priority < 0 || rule.priority > 99) {
    errors.push('优先级需在 0–99 之间');
  }
  if (rule.conditions.length === 0) {
    errors.push('至少需要 1 个触发条件');
  }
  if (rule.conditions.length > 2) {
    errors.push('当前版本最多支持 2 个触发条件');
  }
  const usedSensors: SensorKey[] = [];
  rule.conditions.forEach((condition: RuleCondition, index: number) => {
    if (usedSensors.indexOf(condition.sensor) >= 0) {
      errors.push('同一规则不能重复使用同一传感器');
    }
    usedSensors.push(condition.sensor);
    validateCondition(condition, index + 1).forEach((message: string) => errors.push(message));
  });
  if (rule.actions.length === 0) {
    errors.push('至少需要 1 个执行动作');
  }
  if (rule.actions.length > 3) {
    errors.push('当前版本最多支持 3 个执行动作');
  }
  rule.actions.forEach((action: RuleAction, index: number) => {
    validateAction(action, index + 1).forEach((message: string) => errors.push(message));
  });
  return errors;
}

/** 返回设备档位的可读范围 */
export function levelRangeText(device: DeviceKey): string {
  return `${deviceMin(device)}–${deviceMax(device)}`;
}
