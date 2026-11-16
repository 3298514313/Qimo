import { router } from '@kit.ArkUI';
import { AppViewModel } from '../viewmodel/AppViewModel';
import {
  Rule,
  RuleCondition,
  RuleAction,
  SensorKey,
  CompareOp,
  LogicOp,
  DeviceKey
} from '../model/Types';
import {
  sensorLabel,
  deviceLabel,
  COMPARE_OPS,
  DEVICE_KEYS,
  ACTION_COMMANDS
} from '../common/Labels';
import { genId, safeNumber } from '../common/Constants';

/** 路由跳转参数（显式接口） */
interface RouterParams {
  ruleId?: string;
}

/** 规则新增 / 编辑页：填写条件、动作、优先级，保存后回到规则管理 */
@Entry
@Component
struct RuleEdit {
  private vm: AppViewModel = AppViewModel.getInstance();

  private sensorKeys: SensorKey[] = [
    SensorKey.Temperature,
    SensorKey.Humidity,
    SensorKey.Illuminance,
    SensorKey.Presence
  ];
  private logicKeys: LogicOp[] = [LogicOp.AND, LogicOp.OR];

  @State editingId: string = '';
  @State name: string = '';
  @State sensorIndex1: number = 0;
  @State opIndex1: number = 0;
  @State value1: string = '28';
  @State enableCond2: boolean = false;
  @State sensorIndex2: number = 0;
  @State opIndex2: number = 0;
  @State value2: string = '1';
  @State logicIndex: number = 0;
  @State targetIndex: number = 0;
  @State commandIndex: number = 0;
  @State levelText: string = '50';
  @State priorityText: string = '5';
  @State error: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as RouterParams | undefined;
    const ruleId = params ? params.ruleId : undefined;
    if (ruleId) {
      const existing = this.vm.rules.find((r: Rule) => r.id === ruleId);
      if (existing) {
        this.editingId = existing.id;
        this.name = existing.name;
        this.logicIndex = existing.logic === LogicOp.OR ? 1 : 0;
        const c1 = existing.conditions[0];
        if (c1) {
          this.sensorIndex1 = this.sensorKeys.indexOf(c1.sensor);
          this.opIndex1 = COMPARE_OPS.indexOf(c1.op);
          this.value1 = c1.value.toString();
        }
        if (existing.conditions.length >= 2) {
          this.enableCond2 = true;
          const c2 = existing.conditions[1];
          this.sensorIndex2 = this.sensorKeys.indexOf(c2.sensor);
          this.opIndex2 = COMPARE_OPS.indexOf(c2.op);
          this.value2 = c2.value.toString();
        }
        const a1 = existing.actions[0];
        if (a1) {
          this.targetIndex = DEVICE_KEYS.indexOf(a1.target);
          this.commandIndex = ACTION_COMMANDS.indexOf(a1.command);
          if (a1.param !== undefined) {
            this.levelText = a1.param.toString();
          }
        }
        this.priorityText = existing.priority.toString();
      }
    }
  }

  private sensorOptions(): SelectOption[] {
    return this.sensorKeys.map((k: SensorKey): SelectOption => ({ value: sensorLabel(k) }));
  }

  private opOptions(): SelectOption[] {
    return COMPARE_OPS.map((op: CompareOp): SelectOption => ({ value: op as string }));
  }

  private logicOptions(): SelectOption[] {
    return this.logicKeys.map((l: LogicOp): SelectOption =>
      ({ value: l === LogicOp.AND ? '并且（AND）' : '或者（OR）' }));
  }

  private deviceOptions(): SelectOption[] {
    return DEVICE_KEYS.map((d: DeviceKey): SelectOption => ({ value: deviceLabel(d) }));
  }

  private commandOptions(): SelectOption[] {
    return ACTION_COMMANDS.map((c: string): SelectOption =>
      ({ value: c === 'turnOn' ? '打开' : c === 'turnOff' ? '关闭' : '调档位' }));
  }

  private buildConditions(): RuleCondition[] | null {
    const v1 = safeNumber(this.value1, Number.NaN);
    if (Number.isNaN(v1)) {
      this.error = '条件 1 的阈值不是有效数字';
      return null;
    }
    const first: RuleCondition = {
      sensor: this.sensorKeys[this.sensorIndex1],
      op: COMPARE_OPS[this.opIndex1],
      value: v1
    };
    const conditions: RuleCondition[] = [first];
    if (this.enableCond2) {
      const v2 = safeNumber(this.value2, Number.NaN);
      if (Number.isNaN(v2)) {
        this.error = '条件 2 的阈值不是有效数字';
        return null;
      }
      const second: RuleCondition = {
        sensor: this.sensorKeys[this.sensorIndex2],
        op: COMPARE_OPS[this.opIndex2],
        value: v2
      };
      conditions.push(second);
    }
    return conditions;
  }

  private save(): void {
    if (this.name.trim().length === 0) {
      this.error = '请填写规则名称';
      return;
    }
    const conditions = this.buildConditions();
    if (conditions === null) {
      return;
    }
    const command = ACTION_COMMANDS[this.commandIndex];
    const action: RuleAction = {
      target: DEVICE_KEYS[this.targetIndex],
      command,
      param: command === 'setLevel' ? safeNumber(this.levelText, 50) : undefined
    };
    const existing = this.vm.rules.find((r: Rule) => r.id === this.editingId);
    const rule: Rule = {
      id: this.editingId || genId(),
      name: this.name.trim(),
      enabled: existing ? existing.enabled : true,
      logic: this.logicKeys[this.logicIndex],
      conditions,
      actions: [action],
      priority: safeNumber(this.priorityText, 5),
      createdAt: existing ? existing.createdAt : Date.now()
    };

    if (this.editingId) {
      this.vm.updateRule(rule);
    } else {
      this.vm.addRule(rule);
    }
    router.back();
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text(this.editingId ? '编辑规则' : '新增规则')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .width('100%')

        TextInput({ placeholder: '规则名称', text: this.name })
          .onChange((v: string) => { this.name = v; })

        Text('条件 1').fontSize(14).fontWeight(FontWeight.Medium).width('100%')
        Row({ space: 8 }) {
          Select(this.sensorOptions())
            .selected(this.sensorIndex1)
            .onSelect((index: number) => { this.sensorIndex1 = index; })
          Select(this.opOptions())
            .selected(this.opIndex1)
            .onSelect((index: number) => { this.opIndex1 = index; })
          TextInput({ placeholder: '阈值', text: this.value1 })
            .layoutWeight(1)
            .onChange((v: string) => { this.value1 = v; })
        }

        Row() {
          Text('启用第二个条件（双条件规则）').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.enableCond2 })
            .onChange((isOn: boolean) => { this.enableCond2 = isOn; })
        }

        if (this.enableCond2) {
          Text('条件 2').fontSize(14).fontWeight(FontWeight.Medium).width('100%')
          Row({ space: 8 }) {
            Select(this.sensorOptions())
              .selected(this.sensorIndex2)
              .onSelect((index: number) => { this.sensorIndex2 = index; })
            Select(this.opOptions())
              .selected(this.opIndex2)
              .onSelect((index: number) => { this.opIndex2 = index; })
            TextInput({ placeholder: '阈值', text: this.value2 })
              .layoutWeight(1)
              .onChange((v: string) => { this.value2 = v; })
          }
          Row() {
            Text('条件关系').layoutWeight(1)
            Select(this.logicOptions())
              .selected(this.logicIndex)
              .onSelect((index: number) => { this.logicIndex = index; })
          }
        }

        Text('执行动作').fontSize(14).fontWeight(FontWeight.Medium).width('100%')
        Row({ space: 8 }) {
          Select(this.deviceOptions())
            .selected(this.targetIndex)
            .onSelect((index: number) => { this.targetIndex = index; })
          Select(this.commandOptions())
            .selected(this.commandIndex)
            .onSelect((index: number) => { this.commandIndex = index; })
        }
        if (ACTION_COMMANDS[this.commandIndex] === 'setLevel') {
          TextInput({ placeholder: '目标档位', text: this.levelText })
            .onChange((v: string) => { this.levelText = v; })
        }

        TextInput({ placeholder: '冲突优先级（数字越大越优先）', text: this.priorityText })
          .onChange((v: string) => { this.priorityText = v; })

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(13)
            .fontColor('#C62828')
            .width('100%')
        }

        Button('保存规则')
          .width('100%')
          .type(ButtonType.Capsule)
          .onClick(() => this.save())
      }
      .padding(16)
      .width('100%')
    }
  }
}
