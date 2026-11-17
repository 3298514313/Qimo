import { describe, it, expect } from '@ohos/hypium';
import { RuleEngine } from '../../../main/ets/engine/RuleEngine';
import {
  Rule,
  RuleCondition,
  RuleAction,
  DeviceState,
  EnvSnapshot,
  ExecutedAction,
  SensorKey,
  CompareOp,
  LogicOp,
  DeviceKey
} from '../../../main/ets/model/Types';
import {
  defaultDevices,
  defaultRules,
  defaultScenarios
} from '../../../main/ets/mock/MockData';

/**
 * 规则引擎自动化测试。
 * 覆盖正常触发、边界等值、双条件/OR、异常输入、同级仲裁、重复指令、
 * 档位冲突、设备前后快照与潜在冲突提示。
 */
function makeEnv(temperature: number, humidity: number, illuminance: number,
  presence: number): EnvSnapshot {
  return {
    temperature: temperature,
    humidity: humidity,
    illuminance: illuminance,
    presence: presence
  };
}

function makeCondition(sensor: SensorKey, op: CompareOp, value: number): RuleCondition {
  return { sensor: sensor, op: op, value: value };
}

function makeAction(target: DeviceKey, command: string, param?: number): RuleAction {
  const result: RuleAction = { target: target, command: command };
  if (param !== undefined) {
    result.param = param;
  }
  return result;
}

function makeRule(id: string, name: string, priority: number, createdAt: number,
  conditions: RuleCondition[], actions: RuleAction[],
  logic: LogicOp = LogicOp.AND, enabled: boolean = true): Rule {
  return {
    id: id,
    name: name,
    enabled: enabled,
    logic: logic,
    conditions: conditions,
    actions: actions,
    priority: priority,
    createdAt: createdAt
  };
}

function makeAcDevice(): DeviceState {
  return { key: DeviceKey.AirConditioner, powered: false, level: 26 };
}
export default function ruleEngineTest(): void {
  describe('RuleEngineTest', () => {
    const engine: RuleEngine = new RuleEngine();

    it('正常：温度 30℃ 满足 >28，规则触发并打开空调', 0, () => {
      const highTemp = makeRule('r-high-temp', '高温开空调', 10, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const result = engine.evaluate([highTemp], makeEnv(30, 55, 600, 1),
        [makeAcDevice()], '正常场景');

      expect(engine.matchRule(highTemp, makeEnv(30, 55, 600, 1))).assertTrue();
      expect(result.devices[0].powered).assertTrue();
      expect(result.log.actions.length).assertEqual(1);
      expect(result.log.actions[0].status).assertEqual('success');
      expect(result.log.actions[0].conditionSummary.indexOf('温度') >= 0).assertTrue();
      expect(result.log.triggeredRuleIds.length).assertEqual(1);
    });

    it('边界：温度恰好 28℃ 时，> 不触发，>= 触发', 0, () => {
      const at28 = makeEnv(28, 55, 600, 1);
      const gtRule = makeRule('r-gt', '大于28', 5, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const gteRule = makeRule('r-gte', '大于等于28', 5, 2,
        [makeCondition(SensorKey.Temperature, CompareOp.GTE, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);

      expect(engine.matchRule(gtRule, at28)).assertFalse();
      expect(engine.matchRule(gteRule, at28)).assertTrue();
    });

    it('双条件：光照 <200 且有人 ==1 才触发，缺一不可', 0, () => {
      const darkAndPresent = makeRule('r-dark', '有人且昏暗开灯', 8, 1, [
        makeCondition(SensorKey.Illuminance, CompareOp.LT, 200),
        makeCondition(SensorKey.Presence, CompareOp.EQ, 1)
      ], [makeAction(DeviceKey.Light, 'turnOn')]);

      expect(engine.matchRule(darkAndPresent, makeEnv(22, 50, 150, 1))).assertTrue();
      expect(engine.matchRule(darkAndPresent, makeEnv(22, 50, 150, 0))).assertFalse();
      expect(engine.matchRule(darkAndPresent, makeEnv(22, 50, 300, 1))).assertFalse();
    });

    it('OR 逻辑：任一条件满足即可触发', 0, () => {
      const orRule = makeRule('r-or', '高温或高湿', 6, 1, [
        makeCondition(SensorKey.Temperature, CompareOp.GT, 30),
        makeCondition(SensorKey.Humidity, CompareOp.GT, 70)
      ], [makeAction(DeviceKey.Humidifier, 'turnOn')], LogicOp.OR);

      expect(engine.matchRule(orRule, makeEnv(20, 80, 300, 1))).assertTrue();
      expect(engine.matchRule(orRule, makeEnv(31, 40, 300, 1))).assertTrue();
      expect(engine.matchRule(orRule, makeEnv(20, 40, 300, 1))).assertFalse();
    });

    it('异常：禁用/无条件规则不触发，目标设备缺失记为 blocked', 0, () => {
      const disabled = makeRule('r-disabled', '已禁用', 5, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')], LogicOp.AND, false);
      const noCondition = makeRule('r-empty', '无条件', 5, 2, [],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const missingTarget = makeRule('r-missing', '目标缺失', 5, 3,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.Humidifier, 'turnOn')]);

      expect(engine.matchRule(disabled, makeEnv(30, 55, 600, 1))).assertFalse();
      expect(engine.matchRule(noCondition, makeEnv(30, 55, 600, 1))).assertFalse();

      const result = engine.evaluate([missingTarget], makeEnv(30, 55, 600, 1),
        [makeAcDevice()], '异常场景');
      expect(result.log.actions[0].status).assertEqual('blocked');
      expect(result.log.actions[0].note.indexOf('不存在') >= 0).assertTrue();
    });

    it('冲突：高优先级开机，低优先级关机被拦截并记录', 0, () => {
      const highPriority = makeRule('r-high', '高温开机（高）', 10, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 30)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const lowPriority = makeRule('r-low', '节能关机（低）', 2, 2,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 30)],
        [makeAction(DeviceKey.AirConditioner, 'turnOff')]);

      const result = engine.evaluate([lowPriority, highPriority],
        makeEnv(32, 55, 600, 1), [makeAcDevice()], '冲突场景');

      expect(result.devices[0].powered).assertTrue();
      expect(result.log.conflicts.length).assertEqual(1);
      expect(result.log.conflicts[0].winnerRuleId).assertEqual('r-high');
      expect(result.log.conflicts[0].loserRuleId).assertEqual('r-low');
      expect(result.log.conflicts[0].winnerRuleName).assertEqual('高温开机（高）');
      const blocked = result.log.actions.find((item: ExecutedAction) => item.status === 'blocked');
      expect(blocked !== undefined).assertTrue();
      if (blocked !== undefined) {
        expect(blocked.ruleId).assertEqual('r-low');
      }
    });

    it('同级仲裁：优先级相同时，创建时间更早的规则获胜', 0, () => {
      const early = makeRule('r-early', '早创建', 5, 100,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 25)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const late = makeRule('r-late', '晚创建', 5, 200,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 25)],
        [makeAction(DeviceKey.AirConditioner, 'turnOff')]);

      const result = engine.evaluate([late, early], makeEnv(30, 50, 300, 1),
        [makeAcDevice()], '同级冲突');
      expect(result.devices[0].powered).assertTrue();
      expect(result.log.conflicts[0].winnerRuleId).assertEqual('r-early');
    });

    it('重复指令：同设备相同动作不产生冲突，后一条合并执行', 0, () => {
      const first = makeRule('r-a', '开空调 A', 8, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const second = makeRule('r-b', '开空调 B', 7, 2,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);

      const result = engine.evaluate([first, second], makeEnv(30, 50, 300, 1),
        [makeAcDevice()], '重复指令');
      expect(result.devices[0].powered).assertTrue();
      expect(result.log.conflicts.length).assertEqual(0);
      expect(result.log.actions.length).assertEqual(2);
      expect(result.log.actions[0].status).assertEqual('success');
      expect(result.log.actions[1].status).assertEqual('success');
    });

    it('档位冲突：同一设备不同 setLevel，高优先级数值生效', 0, () => {
      const cool = makeRule('r-cool', '制冷 22℃', 9, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'setLevel', 22)]);
      const warm = makeRule('r-warm', '制热 28℃', 3, 2,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'setLevel', 28)]);

      const result = engine.evaluate([warm, cool], makeEnv(30, 50, 300, 1),
        [makeAcDevice()], '档位冲突');
      expect(result.devices[0].level).assertEqual(22);
      expect(result.log.conflicts.length).assertEqual(1);
      expect(result.log.actions[1].status).assertEqual('blocked');
    });

    it('设备快照：记录执行前后的状态，支持界面展示变化', 0, () => {
      const powerAndLevel = makeRule('r-power-level', '开机并设 24℃', 7, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn'),
          makeAction(DeviceKey.AirConditioner, 'setLevel', 24)]);

      const result = engine.evaluate([powerAndLevel], makeEnv(30, 50, 300, 1),
        [makeAcDevice()], '快照场景');
      expect(result.devices[0].powered).assertTrue();
      expect(result.devices[0].level).assertEqual(24);
      expect(result.log.deviceBefore[0].powered).assertFalse();
      expect(result.log.deviceBefore[0].level).assertEqual(26);
      expect(result.log.deviceAfter[0].powered).assertTrue();
      expect(result.log.deviceAfter[0].level).assertEqual(24);
    });

    it('潜在冲突：不同规则竞争同一设备时给出提示', 0, () => {
      const onRule = makeRule('r-on', '开空调', 8, 1,
        [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
        [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
      const offRule = makeRule('r-off', '关空调', 4, 2,
        [makeCondition(SensorKey.Temperature, CompareOp.LT, 18)],
        [makeAction(DeviceKey.AirConditioner, 'turnOff')]);

      const ids = engine.potentialConflictRuleIds([onRule, offRule]);
      expect(ids.length).assertEqual(2);
      expect(ids.indexOf('r-on') >= 0).assertTrue();
      expect(ids.indexOf('r-off') >= 0).assertTrue();
    });

    it('默认数据：无人高温场景产生空调冲突，P10 规则获胜', 0, () => {
      const scenario = defaultScenarios()[2];
      expect(scenario !== undefined).assertTrue();
      if (scenario === undefined) {
        return;
      }
      const result = engine.evaluate(defaultRules(), scenario.env,
        defaultDevices(), scenario.name);
      expect(result.log.conflicts.length).assertEqual(1);
      expect(result.log.conflicts[0].winnerRuleId).assertEqual('rule-high-temp');
      expect(result.log.conflicts[0].loserRuleId).assertEqual('rule-none-off');
      const ac = result.devices.find((device: DeviceState) => device.key === DeviceKey.AirConditioner);
      expect(ac !== undefined && ac.powered).assertTrue();
    });
  });
}
