import {
  Rule,
  RuleCondition,
  RuleAction,
  SensorKey,
  CompareOp,
  LogicOp,
  DeviceKey,
  DeviceState,
  EnvSnapshot,
  LogEntry,
  ExecutedAction,
  ConflictRecord,
  EvaluateResult,
  ActionStatus
} from '../model/Types';
import { genId } from '../common/Constants';
import { cloneDevice, cloneDevices, cloneEnv } from '../common/Clone';
import { conditionsText, deviceLabel, priorityLabel } from '../common/Labels';

/**
 * 规则引擎（纯逻辑，不依赖 UI，便于单元测试）。
 *
 * 处理流程：
 * 1. 用 Mock 环境计算每条规则的 AND / OR 条件；
 * 2. 按“优先级降序 -> 创建时间升序 -> id 升序”确定执行顺序；
 * 3. 同一设备只允许先执行的规则占用，后续不同指令被拦截并记录冲突；
 * 4. 生成含触发条件、设备前后快照、动作顺序和冲突依据的日志。
 */
export class RuleEngine {

  /** 读取某传感器在环境快照中的数值 */
  readSensor(sensor: SensorKey, env: EnvSnapshot): number {
    switch (sensor) {
      case SensorKey.Temperature:
        return env.temperature;
      case SensorKey.Humidity:
        return env.humidity;
      case SensorKey.Illuminance:
        return env.illuminance;
      case SensorKey.Presence:
        return env.presence;
      default:
        return Number.NaN;
    }
  }

  /** 比较运算 */
  compare(actual: number, op: CompareOp, expected: number): boolean {
    switch (op) {
      case CompareOp.GT:
        return actual > expected;
      case CompareOp.LT:
        return actual < expected;
      case CompareOp.EQ:
        return actual === expected;
      case CompareOp.GTE:
        return actual >= expected;
      case CompareOp.LTE:
        return actual <= expected;
      default:
        return false;
    }
  }

  /** 单条条件是否成立（非法数据按不成立处理） */
  evalCondition(cond: RuleCondition, env: EnvSnapshot): boolean {
    const actual = this.readSensor(cond.sensor, env);
    if (!Number.isFinite(actual) || !Number.isFinite(cond.value)) {
      return false;
    }
    return this.compare(actual, cond.op, cond.value);
  }

  /** 整条规则是否匹配（禁用或无条件不触发） */
  matchRule(rule: Rule, env: EnvSnapshot): boolean {
    if (!rule.enabled || rule.conditions.length === 0) {
      return false;
    }
    const results: boolean[] = rule.conditions.map(
      (condition: RuleCondition) => this.evalCondition(condition, env)
    );
    if (rule.logic === LogicOp.OR) {
      return results.some((value: boolean) => value);
    }
    return results.every((value: boolean) => value);
  }

  /** 两个动作是否完全一致（用于识别重复指令） */
  sameAction(left: RuleAction, right: RuleAction): boolean {
    return left.target === right.target &&
      left.command === right.command &&
      left.param === right.param;
  }

  /** 两个动作是否不同（同一设备上的不同指令视为冲突） */
  actionsConflict(left: RuleAction, right: RuleAction): boolean {
    return !this.sameAction(left, right);
  }

  /** 将动作应用到设备状态副本 */
  private applyAction(device: DeviceState, action: RuleAction): void {
    switch (action.command) {
      case 'turnOn':
        device.powered = true;
        break;
      case 'turnOff':
        device.powered = false;
        break;
      case 'setLevel':
        if (action.param !== undefined) {
          device.level = action.param;
        }
        break;
      default:
        break;
    }
  }

  private copyAction(action: RuleAction): RuleAction {
    return {
      target: action.target,
      command: action.command,
      param: action.param
    };
  }

  /** 生成一条动作日志 */
  private recordAction(rule: Rule, action: RuleAction, status: ActionStatus,
    note: string): ExecutedAction {
    return {
      ruleId: rule.id,
      ruleName: rule.name,
      rulePriority: rule.priority,
      conditionSummary: conditionsText(rule),
      target: action.target,
      command: action.command,
      param: action.param,
      status: status,
      note: note
    };
  }

  /**
   * 批量评估规则并执行动作。
   * 入参设备不会被修改，返回值中的设备是副本。
   */
  evaluate(
    rules: Rule[],
    env: EnvSnapshot,
    devices: DeviceState[],
    scenarioName: string
  ): EvaluateResult {
    const triggered: Rule[] = rules.filter((rule: Rule) => this.matchRule(rule, env));
    const ordered: Rule[] = triggered.slice().sort((left: Rule, right: Rule): number => {
      if (left.priority !== right.priority) {
        return right.priority - left.priority;
      }
      if (left.createdAt !== right.createdAt) {
        return left.createdAt - right.createdAt;
      }
      return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });

    const before: DeviceState[] = cloneDevices(devices);
    const nextDevices: DeviceState[] = cloneDevices(devices);
    const actions: ExecutedAction[] = [];
    const conflicts: ConflictRecord[] = [];
    // 每个设备当前被哪条规则占用；后到的不同指令会被拦截。
    const deviceWinner: Map<DeviceKey, Rule> = new Map<DeviceKey, Rule>();

    ordered.forEach((rule: Rule, ruleIndex: number) => {
      rule.actions.forEach((action: RuleAction) => {
        const target = nextDevices.find((device: DeviceState) => device.key === action.target);
        if (target === undefined) {
          actions.push(this.recordAction(rule, action, 'blocked',
            `目标设备「${deviceLabel(action.target)}」不存在，动作被拦截`));
          return;
        }

        const winner = deviceWinner.get(action.target);
        if (winner !== undefined && winner.id !== rule.id) {
          const winnerAction = winner.actions.find(
            (item: RuleAction) => item.target === action.target
          );
          if (winnerAction !== undefined && this.actionsConflict(winnerAction, action)) {
            conflicts.push({
              device: action.target,
              winnerRuleId: winner.id,
              winnerRuleName: winner.name,
              loserRuleId: rule.id,
              loserRuleName: rule.name,
              reason: `${priorityLabel(winner.priority)}「${winner.name}」先占用${deviceLabel(action.target)}，` +
                `${priorityLabel(rule.priority)}「${rule.name}」的指令被拦截`
            });
            actions.push(this.recordAction(rule, action, 'blocked',
              `与「${winner.name}」冲突，按优先级保留先执行的规则`));
            return;
          }
          if (winnerAction !== undefined && this.sameAction(winnerAction, action)) {
            // 相同指令不重复下发，也不替换当前设备占用者，保证后续仲裁归属稳定。
            actions.push(this.recordAction(rule, action, 'success',
              `与「${winner.name}」动作一致，合并执行`));
            return;
          }
        }

        this.applyAction(target, this.copyAction(action));
        deviceWinner.set(action.target, rule);
        const note = winner === undefined || winner.id === rule.id
          ? `执行顺序 #${ruleIndex + 1}，${priorityLabel(rule.priority)}`
          : `同规则多动作合并执行，${priorityLabel(rule.priority)}`;
        actions.push(this.recordAction(rule, action, 'success', note));
      });
    });

    // 同一设备被多条规则写入不同动作时，给较早动作补记“仲裁生效”。
    actions.forEach((action: ExecutedAction) => {
      if (action.status !== 'success') {
        return;
      }
      const winner = deviceWinner.get(action.target);
      const conflicted = conflicts.some((conflict: ConflictRecord) =>
        conflict.device === action.target && conflict.winnerRuleId === action.ruleId);
      if (conflicted && winner !== undefined && winner.id === action.ruleId) {
        action.status = 'conflict-won';
      }
    });

    const log: LogEntry = {
      id: genId(),
      timestamp: Date.now(),
      scenarioName: scenarioName,
      env: cloneEnv(env),
      triggeredRuleIds: ordered.map((rule: Rule) => rule.id),
      actions: actions,
      conflicts: conflicts,
      deviceBefore: before,
      deviceAfter: cloneDevices(nextDevices)
    };

    return { devices: nextDevices, log: log };
  }

  /**
   * 静态检查规则之间的潜在竞争：同一设备、不同动作即提示。
   * 这不代表一定同时触发，运行时以真实环境计算为准。
   */
  potentialConflictRuleIds(rules: Rule[]): string[] {
    const ids: string[] = [];
    const enabled = rules.filter((rule: Rule) => rule.enabled);
    enabled.forEach((left: Rule) => {
      enabled.forEach((right: Rule) => {
        if (left.id >= right.id) {
          return;
        }
        left.actions.forEach((leftAction: RuleAction) => {
          right.actions.forEach((rightAction: RuleAction) => {
            if (leftAction.target === rightAction.target &&
              this.actionsConflict(leftAction, rightAction)) {
              if (ids.indexOf(left.id) < 0) {
                ids.push(left.id);
              }
              if (ids.indexOf(right.id) < 0) {
                ids.push(right.id);
              }
            }
          });
        });
      });
    });
    return ids;
  }
}
