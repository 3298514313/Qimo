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
  EvaluateResult
} from '../model/Types';
import { genId } from '../common/Constants';
import { cloneDevice, cloneEnv } from '../common/Clone';

/**
 * 规则引擎（纯逻辑，不依赖 UI，便于单元测试）。
 * 职责：
 * 1. 根据 Mock 环境数据计算每条规则是否触发；
 * 2. 按优先级排序后依次执行设备动作；
 * 3. 对同一设备上相互冲突的相反指令做仲裁，高优先级获胜，低优先级被拦截并记录；
 * 4. 生成包含触发条件、设备变化、执行顺序与冲突记录的日志。
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

  /** 单条条件是否成立 */
  evalCondition(cond: RuleCondition, env: EnvSnapshot): boolean {
    const actual = this.readSensor(cond.sensor, env);
    if (Number.isNaN(actual)) {
      return false;
    }
    return this.compare(actual, cond.op, cond.value);
  }

  /** 整条规则是否匹配（禁用或无条件不触发） */
  matchRule(rule: Rule, env: EnvSnapshot): boolean {
    if (!rule.enabled || rule.conditions.length === 0) {
      return false;
    }
    const results: boolean[] = rule.conditions.map((c: RuleCondition) => this.evalCondition(c, env));
    if (rule.logic === LogicOp.OR) {
      return results.some((v: boolean) => v);
    }
    return results.every((v: boolean) => v);
  }

  /** 判断两条命令是否为相反控制（开/关互斥） */
  private isOpposite(a: string, b: string): boolean {
    return (a === 'turnOn' && b === 'turnOff') || (a === 'turnOff' && b === 'turnOn');
  }

  /** 将动作应用到设备状态副本 */
  private applyAction(dev: DeviceState, action: RuleAction): void {
    switch (action.command) {
      case 'turnOn':
        dev.powered = true;
        break;
      case 'turnOff':
        dev.powered = false;
        break;
      case 'setLevel':
        if (action.param !== undefined) {
          dev.level = action.param;
        }
        break;
      default:
        break;
    }
  }

  /**
   * 批量评估规则并执行动作。
   * @param rules 全部规则
   * @param env 当前 Mock 环境快照
   * @param devices 当前设备状态（方法内复制，不直接改入参）
   * @param scenarioName 场景名称，写入日志
   */
  evaluate(
    rules: Rule[],
    env: EnvSnapshot,
    devices: DeviceState[],
    scenarioName: string
  ): EvaluateResult {
    const triggered: Rule[] = rules.filter((r: Rule) => this.matchRule(r, env));
    // 冲突仲裁：优先级高的先执行；同优先级按规则创建顺序
    const ordered: Rule[] = triggered.slice().sort((a: Rule, b: Rule) => b.priority - a.priority);

    const nextDevices: DeviceState[] = devices.map((d: DeviceState) => cloneDevice(d));
    const actions: ExecutedAction[] = [];
    const conflicts: ConflictRecord[] = [];
    // 记录每个设备当前已生效的指令来自哪条规则（即当前获胜方）
    const deviceWinner = new Map<DeviceKey, string>();

    for (const rule of ordered) {
      for (const action of rule.actions) {
        const target = nextDevices.find((d: DeviceState) => d.key === action.target);
        if (!target) {
          // 异常分支：动作目标设备不存在，记录为被拦截
          const blocked: ExecutedAction = {
            ruleId: rule.id,
            ruleName: rule.name,
            target: action.target,
            command: action.command,
            param: action.param,
            status: 'blocked'
          };
          actions.push(blocked);
          continue;
        }

        const winnerId = deviceWinner.get(action.target);
        if (winnerId !== undefined) {
          const winnerRule = ordered.find((r: Rule) => r.id === winnerId);
          const winnerAction = winnerRule
            ? winnerRule.actions.find((a: RuleAction) => a.target === action.target)
            : undefined;
          if (winnerAction && this.isOpposite(winnerAction.command, action.command)) {
            const conflict: ConflictRecord = {
              device: action.target,
              winnerRuleId: winnerId,
              loserRuleId: rule.id,
              reason: '高优先级规则指令先生效，低优先级相反指令被拦截'
            };
            conflicts.push(conflict);
            const blocked: ExecutedAction = {
              ruleId: rule.id,
              ruleName: rule.name,
              target: action.target,
              command: action.command,
              param: action.param,
              status: 'blocked'
            };
            actions.push(blocked);
            continue;
          }
        }

        this.applyAction(target, action);
        deviceWinner.set(action.target, rule.id);
        const done: ExecutedAction = {
          ruleId: rule.id,
          ruleName: rule.name,
          target: action.target,
          command: action.command,
          param: action.param,
          status: winnerId === undefined ? 'success' : 'conflict-won'
        };
        actions.push(done);
      }
    }

    const log: LogEntry = {
      id: genId(),
      timestamp: Date.now(),
      scenarioName,
      env: cloneEnv(env),
      triggeredRuleIds: ordered.map((r: Rule) => r.id),
      actions,
      conflicts
    };

    const result: EvaluateResult = { devices: nextDevices, log };
    return result;
  }
}
