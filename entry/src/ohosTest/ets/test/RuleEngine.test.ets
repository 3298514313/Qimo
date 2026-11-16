import { describe, it, expect } from '@ohos/hypium';
import { RuleEngine } from '../../../main/ets/engine/RuleEngine';
import {
  Rule,
  DeviceState,
  EnvSnapshot,
  ExecutedAction,
  SensorKey,
  CompareOp,
  LogicOp,
  DeviceKey
} from '../../../main/ets/model/Types';

/**
 * 规则引擎单元测试。
 * 覆盖：正常触发、边界值、异常输入、冲突仲裁 四类场景（共 4 条，满足每人至少 3 条要求）。
 */
export default function ruleEngineTest(): void {
  describe('RuleEngineTest', () => {
    const engine: RuleEngine = new RuleEngine();

    function baseEnv(): EnvSnapshot {
      return { temperature: 26, humidity: 55, illuminance: 600, presence: 1 };
    }

    function envWithTemperature(temperature: number): EnvSnapshot {
      const base = baseEnv();
      return {
        temperature,
        humidity: base.humidity,
        illuminance: base.illuminance,
        presence: base.presence
      };
    }

    it('正常：温度 30℃ 满足 >28，规则触发并打开空调', 0, () => {
      const env: EnvSnapshot = envWithTemperature(30);
      const rule: Rule = {
        id: 'r-high-temp',
        name: '高温开空调',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GT, value: 28 }],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOn' }],
        priority: 10,
        createdAt: 1
      };

      expect(engine.matchRule(rule, env)).assertTrue();

      const devices: DeviceState[] = [
        { key: DeviceKey.AirConditioner, powered: false, level: 26 }
      ];
      const result = engine.evaluate([rule], env, devices, '正常场景');
      expect(result.devices[0].powered).assertTrue();
      expect(result.log.actions.length).assertEqual(1);
      expect(result.log.actions[0].status).assertEqual('success');
    });

    it('边界：温度恰好等于 28 时，> 不触发，>= 触发', 0, () => {
      const env: EnvSnapshot = envWithTemperature(28);
      const gtRule: Rule = {
        id: 'r-gt',
        name: '大于28',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GT, value: 28 }],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOn' }],
        priority: 5,
        createdAt: 1
      };
      const gteRule: Rule = {
        id: 'r-gte',
        name: '大于等于28',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GTE, value: 28 }],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOn' }],
        priority: 5,
        createdAt: 2
      };

      expect(engine.matchRule(gtRule, env)).assertFalse();
      expect(engine.matchRule(gteRule, env)).assertTrue();
    });

    it('异常：禁用规则不触发；无条件规则不触发；动作目标不存在被拦截', 0, () => {
      const env: EnvSnapshot = envWithTemperature(30);

      const disabledRule: Rule = {
        id: 'r-disabled',
        name: '已禁用',
        enabled: false,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GT, value: 28 }],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOn' }],
        priority: 5,
        createdAt: 1
      };
      const emptyConditionRule: Rule = {
        id: 'r-empty',
        name: '无条件',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOn' }],
        priority: 5,
        createdAt: 2
      };
      const missingTargetRule: Rule = {
        id: 'r-missing',
        name: '动作目标缺失',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GT, value: 28 }],
        actions: [{ target: DeviceKey.Humidifier, command: 'turnOn' }],
        priority: 5,
        createdAt: 3
      };

      expect(engine.matchRule(disabledRule, env)).assertFalse();
      expect(engine.matchRule(emptyConditionRule, env)).assertFalse();

      const devices: DeviceState[] = [
        { key: DeviceKey.AirConditioner, powered: false, level: 26 }
      ];
      const result = engine.evaluate([missingTargetRule], env, devices, '异常场景');
      expect(result.log.actions[0].status).assertEqual('blocked');
    });

    it('冲突：高优先级规则获胜，低优先级相反指令被拦截并记录冲突', 0, () => {
      const env: EnvSnapshot = envWithTemperature(32);
      const highPriority: Rule = {
        id: 'r-high',
        name: '高温开机（高优先级）',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GT, value: 30 }],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOn' }],
        priority: 10,
        createdAt: 1
      };
      const lowPriority: Rule = {
        id: 'r-low',
        name: '高温关机（低优先级）',
        enabled: true,
        logic: LogicOp.AND,
        conditions: [{ sensor: SensorKey.Temperature, op: CompareOp.GT, value: 30 }],
        actions: [{ target: DeviceKey.AirConditioner, command: 'turnOff' }],
        priority: 2,
        createdAt: 2
      };

      const devices: DeviceState[] = [
        { key: DeviceKey.AirConditioner, powered: false, level: 26 }
      ];
      const result = engine.evaluate([lowPriority, highPriority], env, devices, '冲突场景');

      // 高优先级“开机”先生效
      expect(result.devices[0].powered).assertTrue();
      // 记录到一处冲突，低优先级“关机”被拦截
      expect(result.log.conflicts.length).assertEqual(1);
      const blocked = result.log.actions.find((a: ExecutedAction) => a.status === 'blocked');
      expect(blocked !== undefined).assertTrue();
      if (blocked !== undefined) {
        expect(blocked.ruleId).assertEqual('r-low');
      }
    });
  });
}
