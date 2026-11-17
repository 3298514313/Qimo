import { describe, it, expect } from '@ohos/hypium';
import { validateEnv, validateRule } from '../../../main/ets/common/Validation';
import {
  Rule,
  RuleAction,
  RuleCondition,
  SensorKey,
  CompareOp,
  LogicOp,
  DeviceKey,
  EnvSnapshot
} from '../../../main/ets/model/Types';

/** 规则/环境校验测试：覆盖合法输入、空字段、越界阈值和缺失档位 */
function makeAction(target: DeviceKey, command: string, param?: number): RuleAction {
  const result: RuleAction = { target: target, command: command };
  if (param !== undefined) {
    result.param = param;
  }
  return result;
}

function makeCondition(sensor: SensorKey, op: CompareOp, value: number): RuleCondition {
  return { sensor: sensor, op: op, value: value };
}

function makeValidRule(): Rule {
  return {
    id: 'r-valid',
    name: '合法规则',
    enabled: true,
    logic: LogicOp.AND,
    conditions: [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    actions: [makeAction(DeviceKey.AirConditioner, 'turnOn')],
    priority: 10,
    createdAt: 1
  };
}

function makeEnv(): EnvSnapshot {
  return { temperature: 26, humidity: 55, illuminance: 600, presence: 1 };
}
export default function validationTest(): void {
  describe('ValidationTest', () => {

    it('正常：完整规则与环境通过校验', 0, () => {
      expect(validateRule(makeValidRule()).length).assertEqual(0);
      expect(validateEnv(makeEnv()).length).assertEqual(0);
    });

    it('异常：空名称、空条件、越界优先级均被拒绝', 0, () => {
      const rule = makeValidRule();
      rule.name = '   ';
      rule.conditions = [];
      rule.priority = 120;
      const errors = validateRule(rule);
      expect(errors.length >= 3).assertTrue();
    });

    it('边界：有人条件只接受 0/1，传感器阈值受范围限制', 0, () => {
      const rule = makeValidRule();
      rule.conditions = [makeCondition(SensorKey.Presence, CompareOp.EQ, 2)];
      expect(validateRule(rule).length > 0).assertTrue();

      rule.conditions = [makeCondition(SensorKey.Humidity, CompareOp.GT, 120)];
      expect(validateRule(rule).length > 0).assertTrue();
    });

    it('异常：setLevel 缺少档位或空调档位越界会被拒绝', 0, () => {
      const rule = makeValidRule();
      rule.actions = [makeAction(DeviceKey.AirConditioner, 'setLevel')];
      expect(validateRule(rule).length > 0).assertTrue();

      rule.actions = [makeAction(DeviceKey.AirConditioner, 'setLevel', 50)];
      expect(validateRule(rule).length > 0).assertTrue();

      rule.actions = [makeAction(DeviceKey.AirConditioner, 'setLevel', 24)];
      expect(validateRule(rule).length).assertEqual(0);
    });

    it('异常：环境温度/湿度/有人标记越界时给出错误', 0, () => {
      const bad = makeEnv();
      bad.temperature = 60;
      bad.humidity = -5;
      bad.presence = 2;
      const errors = validateEnv(bad);
      expect(errors.length >= 3).assertTrue();
    });
  });
}
