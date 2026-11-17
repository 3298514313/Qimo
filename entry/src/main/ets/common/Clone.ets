import {
  Rule,
  RuleCondition,
  RuleAction,
  DeviceState,
  EnvSnapshot,
  Scenario,
  LogEntry,
  ExecutedAction,
  ConflictRecord
} from '../model/Types';

/**
 * ArkTS 严格模式不支持对象展开（{...obj}）与析构声明，
 * 这里提供显式字段拷贝方法，保证状态副本独立、可持久化。
 */

export function cloneCondition(c: RuleCondition): RuleCondition {
  return { sensor: c.sensor, op: c.op, value: c.value };
}

export function cloneAction(a: RuleAction): RuleAction {
  return { target: a.target, command: a.command, param: a.param };
}

export function cloneRule(r: Rule): Rule {
  return {
    id: r.id,
    name: r.name,
    enabled: r.enabled,
    logic: r.logic,
    conditions: r.conditions.map((c: RuleCondition) => cloneCondition(c)),
    actions: r.actions.map((a: RuleAction) => cloneAction(a)),
    priority: r.priority,
    createdAt: r.createdAt
  };
}

export function cloneDevice(d: DeviceState): DeviceState {
  return { key: d.key, powered: d.powered, level: d.level };
}

export function cloneDevices(devices: DeviceState[]): DeviceState[] {
  return devices.map((device: DeviceState) => cloneDevice(device));
}

export function cloneEnv(e: EnvSnapshot): EnvSnapshot {
  return {
    temperature: e.temperature,
    humidity: e.humidity,
    illuminance: e.illuminance,
    presence: e.presence
  };
}

export function cloneScenario(s: Scenario): Scenario {
  return {
    id: s.id,
    name: s.name,
    description: s.description,
    expectation: s.expectation,
    env: cloneEnv(s.env),
    devices: cloneDevices(s.devices)
  };
}

export function cloneExecutedAction(a: ExecutedAction): ExecutedAction {
  return {
    ruleId: a.ruleId,
    ruleName: a.ruleName,
    rulePriority: a.rulePriority,
    conditionSummary: a.conditionSummary,
    target: a.target,
    command: a.command,
    param: a.param,
    status: a.status,
    note: a.note
  };
}

export function cloneConflict(c: ConflictRecord): ConflictRecord {
  return {
    device: c.device,
    winnerRuleId: c.winnerRuleId,
    winnerRuleName: c.winnerRuleName,
    loserRuleId: c.loserRuleId,
    loserRuleName: c.loserRuleName,
    reason: c.reason
  };
}

export function cloneLog(l: LogEntry): LogEntry {
  return {
    id: l.id,
    timestamp: l.timestamp,
    scenarioName: l.scenarioName,
    env: cloneEnv(l.env),
    triggeredRuleIds: l.triggeredRuleIds.slice(),
    actions: l.actions.map((a: ExecutedAction) => cloneExecutedAction(a)),
    conflicts: l.conflicts.map((c: ConflictRecord) => cloneConflict(c)),
    deviceBefore: cloneDevices(l.deviceBefore),
    deviceAfter: cloneDevices(l.deviceAfter)
  };
}
