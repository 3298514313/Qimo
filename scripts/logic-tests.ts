import { RuleEngine } from './engine/RuleEngine';
import { validateEnv, validateRule } from './common/Validation';
import { defaultDevices, defaultRules, defaultScenarios } from './mock/MockData';
import {
  CompareOp,
  DeviceKey,
  DeviceState,
  EnvSnapshot,
  ExecutedAction,
  LogicOp,
  Rule,
  RuleAction,
  RuleCondition,
  SensorKey
} from './model/Types';

declare const process: { exitCode: number };

let passed = 0;
let failed = 0;

function check(name: string, condition: boolean, detail: string = ''): void {
  if (condition) {
    passed += 1;
    console.log(`PASS  ${name}${detail.length > 0 ? '  [' + detail + ']' : ''}`);
  } else {
    failed += 1;
    console.log(`FAIL  ${name}${detail.length > 0 ? '  [' + detail + ']' : ''}`);
  }
}

function makeEnv(temperature: number, humidity: number, illuminance: number,
  presence: number): EnvSnapshot {
  return { temperature, humidity, illuminance, presence };
}

function makeCondition(sensor: SensorKey, op: CompareOp, value: number): RuleCondition {
  return { sensor, op, value };
}

function makeAction(target: DeviceKey, command: string, param?: number): RuleAction {
  const result: RuleAction = { target, command };
  if (param !== undefined) {
    result.param = param;
  }
  return result;
}

function makeRule(id: string, name: string, priority: number, createdAt: number,
  conditions: RuleCondition[], actions: RuleAction[],
  logic: LogicOp = LogicOp.AND, enabled: boolean = true): Rule {
  return { id, name, enabled, logic, conditions, actions, priority, createdAt };
}

function acDevice(): DeviceState {
  return { key: DeviceKey.AirConditioner, powered: false, level: 26 };
}

const engine = new RuleEngine();

// 1. 正常触发
{
  const rule = makeRule('r1', '高温开空调', 10, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const result = engine.evaluate([rule], makeEnv(30, 55, 600, 1), [acDevice()], '正常');
  check('正常：高温触发开空调',
    engine.matchRule(rule, makeEnv(30, 55, 600, 1)) &&
    result.devices[0].powered &&
    result.log.actions.length === 1 &&
    result.log.actions[0].status === 'success',
    `actions=${result.log.actions.length}`);
}

// 2. 边界
{
  const at28 = makeEnv(28, 55, 600, 1);
  const gt = makeRule('r2', '>28', 5, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const gte = makeRule('r3', '>=28', 5, 2,
    [makeCondition(SensorKey.Temperature, CompareOp.GTE, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  check('边界：28℃ 时 > 不触发、>= 触发',
    !engine.matchRule(gt, at28) && engine.matchRule(gte, at28));
}

// 3. 双条件 AND
{
  const rule = makeRule('r4', '有人且昏暗', 8, 1, [
    makeCondition(SensorKey.Illuminance, CompareOp.LT, 200),
    makeCondition(SensorKey.Presence, CompareOp.EQ, 1)
  ], [makeAction(DeviceKey.Light, 'turnOn')]);
  check('双条件 AND：有人且昏暗',
    engine.matchRule(rule, makeEnv(22, 50, 150, 1)) &&
    !engine.matchRule(rule, makeEnv(22, 50, 150, 0)) &&
    !engine.matchRule(rule, makeEnv(22, 50, 300, 1)));
}

// 4. OR
{
  const rule = makeRule('r5', '高温或高湿', 6, 1, [
    makeCondition(SensorKey.Temperature, CompareOp.GT, 30),
    makeCondition(SensorKey.Humidity, CompareOp.GT, 70)
  ], [makeAction(DeviceKey.Humidifier, 'turnOn')], LogicOp.OR);
  check('OR：任一条件满足',
    engine.matchRule(rule, makeEnv(20, 80, 300, 1)) &&
    engine.matchRule(rule, makeEnv(31, 40, 300, 1)) &&
    !engine.matchRule(rule, makeEnv(20, 40, 300, 1)));
}

// 5. 异常：禁用、无条件、目标缺失
{
  const disabled = makeRule('r6', '禁用', 5, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')], LogicOp.AND, false);
  const empty = makeRule('r7', '无条件', 5, 2, [],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const missing = makeRule('r8', '目标缺失', 5, 3,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.Humidifier, 'turnOn')]);
  const result = engine.evaluate([disabled, empty, missing], makeEnv(30, 55, 600, 1),
    [acDevice()], '异常');
  check('异常：禁用/无条件不触发，目标缺失 blocked',
    !engine.matchRule(disabled, makeEnv(30, 55, 600, 1)) &&
    !engine.matchRule(empty, makeEnv(30, 55, 600, 1)) &&
    result.log.actions[0].status === 'blocked' &&
    result.log.actions[0].note.indexOf('不存在') >= 0);
}

// 6. 优先级冲突
{
  const high = makeRule('r9', '高温开机（高）', 10, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 30)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const low = makeRule('r10', '节能关机（低）', 2, 2,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 30)],
    [makeAction(DeviceKey.AirConditioner, 'turnOff')]);
  const result = engine.evaluate([low, high], makeEnv(32, 55, 600, 1),
    [acDevice()], '冲突');
  const blocked = result.log.actions.find((item: ExecutedAction) => item.status === 'blocked');
  check('冲突：高优先级获胜并记录拦截',
    result.devices[0].powered &&
    result.log.conflicts.length === 1 &&
    result.log.conflicts[0].winnerRuleId === 'r9' &&
    result.log.conflicts[0].loserRuleId === 'r10' &&
    blocked !== undefined);
}

// 7. 同级按创建时间
{
  const early = makeRule('r11', '早创建', 5, 100,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 25)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const late = makeRule('r12', '晚创建', 5, 200,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 25)],
    [makeAction(DeviceKey.AirConditioner, 'turnOff')]);
  const result = engine.evaluate([late, early], makeEnv(30, 50, 300, 1),
    [acDevice()], '同级');
  check('同级仲裁：创建更早的规则获胜',
    result.devices[0].powered && result.log.conflicts[0].winnerRuleId === 'r11');
}

// 8. 重复指令
{
  const a = makeRule('r13', '开空调 A', 8, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const b = makeRule('r14', '开空调 B', 7, 2,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const result = engine.evaluate([a, b], makeEnv(30, 50, 300, 1), [acDevice()], '重复');
  check('重复指令：同动作合并且无冲突',
    result.devices[0].powered && result.log.conflicts.length === 0 &&
    result.log.actions.length === 2);
}

// 9. 档位冲突
{
  const cool = makeRule('r15', '制冷 22', 9, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'setLevel', 22)]);
  const warm = makeRule('r16', '制热 28', 3, 2,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'setLevel', 28)]);
  const result = engine.evaluate([warm, cool], makeEnv(30, 50, 300, 1), [acDevice()], '档位');
  check('档位冲突：高优先级 22℃ 生效',
    result.devices[0].level === 22 &&
    result.log.conflicts.length === 1 &&
    result.log.actions[1].status === 'blocked');
}

// 10. 设备快照
{
  const rule = makeRule('r17', '开机并设 24', 7, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn'),
      makeAction(DeviceKey.AirConditioner, 'setLevel', 24)]);
  const result = engine.evaluate([rule], makeEnv(30, 50, 300, 1), [acDevice()], '快照');
  check('设备快照：记录 before/after',
    result.log.deviceBefore[0].powered === false &&
    result.log.deviceBefore[0].level === 26 &&
    result.log.deviceAfter[0].powered === true &&
    result.log.deviceAfter[0].level === 24);
}

// 11. 潜在冲突
{
  const on = makeRule('r18', '开空调', 8, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const off = makeRule('r19', '关空调', 4, 2,
    [makeCondition(SensorKey.Temperature, CompareOp.LT, 18)],
    [makeAction(DeviceKey.AirConditioner, 'turnOff')]);
  const ids = engine.potentialConflictRuleIds([on, off]);
  check('潜在冲突：同设备不同动作被标记',
    ids.length === 2 && ids.indexOf('r18') >= 0 && ids.indexOf('r19') >= 0);
}

// 12. 合法规则校验
{
  const rule = makeRule('r20', '合法规则', 10, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  check('校验：完整规则通过', validateRule(rule).length === 0);
}

// 13. 空字段校验
{
  const rule = makeRule('r21', ' ', 120, 1, [],
    [makeAction(DeviceKey.AirConditioner, 'turnOn')]);
  const errors = validateRule(rule);
  check('校验：空名称/空条件/越界优先级被拒绝', errors.length >= 3, `errors=${errors.length}`);
}

// 14. Presence 边界
{
  const rule = makeRule('r22', '非法有人值', 5, 1,
    [makeCondition(SensorKey.Presence, CompareOp.EQ, 2)],
    [makeAction(DeviceKey.Light, 'turnOn')]);
  check('校验：有人条件只接受 0/1', validateRule(rule).length > 0);
}

// 15. setLevel 校验
{
  const missing = makeRule('r23', '缺档位', 5, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'setLevel')]);
  const outOfRange = makeRule('r24', '档位越界', 5, 1,
    [makeCondition(SensorKey.Temperature, CompareOp.GT, 28)],
    [makeAction(DeviceKey.AirConditioner, 'setLevel', 50)]);
  check('校验：setLevel 缺失/越界被拒绝',
    validateRule(missing).length > 0 && validateRule(outOfRange).length > 0);
}

// 16. 环境校验
{
  const bad = makeEnv(60, -5, 300, 2);
  check('校验：环境温度/湿度/有人标记越界', validateEnv(bad).length >= 3);
}

// 17. 默认场景集成
{
  const scenario = defaultScenarios()[2];
  const result = engine.evaluate(defaultRules(), scenario.env, defaultDevices(), scenario.name);
  check('集成：无人高温场景产生空调冲突且 P10 获胜',
    result.log.conflicts.length === 1 &&
    result.log.conflicts[0].winnerRuleId === 'rule-high-temp' &&
    result.log.conflicts[0].loserRuleId === 'rule-none-off' &&
    result.devices[0].powered === true);
}

console.log(`\nRESULT: ${passed} passed, ${failed} failed, ${passed + failed} total`);
process.exitCode = failed === 0 ? 0 : 1;
