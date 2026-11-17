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
  conditionText,
  actionText,
  COMPARE_OPS,
  DEVICE_KEYS,
  ACTION_COMMANDS,
  deviceMin,
  deviceMax
} from '../common/Labels';
import { cloneAction, cloneRule } from '../common/Clone';
import { genId, safeNumber } from '../common/Constants';
import { validateRule } from '../common/Validation';
import {
  BRAND,
  BG,
  CARD,
  TEXT,
  TEXT_SECONDARY,
  MUTED,
  BORDER,
  DANGER,
  DANGER_BG,
  RADIUS,
  PAGE_PADDING
} from '../common/Theme';

interface RouterParams {
  ruleId?: string;
}

/** 规则新增 / 编辑页：条件、动作、优先级、预览与统一校验 */
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
  @State ruleEnabled: boolean = true;
  @State sensorIndex1: number = 0;
  @State opIndex1: number = 0;
  @State value1: string = '28';
  @State enableCond2: boolean = false;
  @State sensorIndex2: number = 1;
  @State opIndex2: number = 0;
  @State value2: string = '60';
  @State logicIndex: number = 0;
  @State targetIndex: number = 0;
  @State commandIndex: number = 0;
  @State levelText: string = '26';
  @State priority: number = 10;
  @State error: string = '';
  @State existingActionCount: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as RouterParams | undefined;
    const ruleId = params === undefined ? undefined : params.ruleId;
    if (ruleId === undefined || ruleId.length === 0) {
      return;
    }
    const existing = this.vm.rules.find((rule: Rule) => rule.id === ruleId);
    if (existing === undefined) {
      return;
    }
    const rule = cloneRule(existing);
    this.editingId = rule.id;
    this.name = rule.name;
    this.ruleEnabled = rule.enabled;
    this.logicIndex = rule.logic === LogicOp.OR ? 1 : 0;
    this.priority = rule.priority;
    const first = rule.conditions[0];
    if (first !== undefined) {
      this.sensorIndex1 = this.sensorKeys.indexOf(first.sensor);
      this.opIndex1 = COMPARE_OPS.indexOf(first.op);
      this.value1 = first.value.toString();
    }
    if (rule.conditions.length >= 2) {
      this.enableCond2 = true;
      const second = rule.conditions[1];
      this.sensorIndex2 = this.sensorKeys.indexOf(second.sensor);
      this.opIndex2 = COMPARE_OPS.indexOf(second.op);
      this.value2 = second.value.toString();
    }
    const firstAction = rule.actions[0];
    if (firstAction !== undefined) {
      this.targetIndex = DEVICE_KEYS.indexOf(firstAction.target);
      this.commandIndex = ACTION_COMMANDS.indexOf(firstAction.command);
      if (firstAction.param !== undefined) {
        this.levelText = firstAction.param.toString();
      } else {
        this.levelText = deviceMin(firstAction.target).toString();
      }
    }
    this.existingActionCount = rule.actions.length;
  }

  private sensorOptions(): SelectOption[] {
    return this.sensorKeys.map((key: SensorKey): SelectOption => ({ value: sensorLabel(key) }));
  }

  private opOptions(): SelectOption[] {
    return COMPARE_OPS.map((op: CompareOp): SelectOption => ({ value: op as string }));
  }

  private logicOptions(): SelectOption[] {
    return this.logicKeys.map((logic: LogicOp): SelectOption =>
      ({ value: logic === LogicOp.AND ? '并且（AND）' : '或者（OR）' }));
  }

  private deviceOptions(): SelectOption[] {
    return DEVICE_KEYS.map((device: DeviceKey): SelectOption => ({ value: deviceLabel(device) }));
  }

  private commandOptions(): SelectOption[] {
    return ACTION_COMMANDS.map((command: string): SelectOption =>
      ({ value: command === 'turnOn' ? '打开' : command === 'turnOff' ? '关闭' : '调到指定档位' }));
  }

  private currentTarget(): DeviceKey {
    return DEVICE_KEYS[this.targetIndex];
  }

  private currentCommand(): string {
    return ACTION_COMMANDS[this.commandIndex];
  }

  private levelRange(): string {
    const target = this.currentTarget();
    return `${deviceMin(target)}–${deviceMax(target)}`;
  }

  private onTargetChange(index: number): void {
    this.targetIndex = index;
    const target = DEVICE_KEYS[index];
    const current = safeNumber(this.levelText, Number.NaN);
    if (Number.isNaN(current) || current < deviceMin(target) || current > deviceMax(target)) {
      this.levelText = target === DeviceKey.AirConditioner ? '26' : '50';
    }
  }

  private buildConditions(): RuleCondition[] | null {
    const firstValue = safeNumber(this.value1, Number.NaN);
    if (Number.isNaN(firstValue)) {
      this.error = '条件 1 的阈值不是有效数字';
      return null;
    }
    const conditions: RuleCondition[] = [{
      sensor: this.sensorKeys[this.sensorIndex1],
      op: COMPARE_OPS[this.opIndex1],
      value: firstValue
    }];
    if (this.enableCond2) {
      const secondValue = safeNumber(this.value2, Number.NaN);
      if (Number.isNaN(secondValue)) {
        this.error = '条件 2 的阈值不是有效数字';
        return null;
      }
      conditions.push({
        sensor: this.sensorKeys[this.sensorIndex2],
        op: COMPARE_OPS[this.opIndex2],
        value: secondValue
      });
    }
    return conditions;
  }

  private previewCondition(): string {
    const firstValue = safeNumber(this.value1, 0);
    let text = conditionText({
      sensor: this.sensorKeys[this.sensorIndex1],
      op: COMPARE_OPS[this.opIndex1],
      value: firstValue
    });
    if (this.enableCond2) {
      text += this.logicKeys[this.logicIndex] === LogicOp.OR ? ' 或 ' : ' 且 ';
      text += conditionText({
        sensor: this.sensorKeys[this.sensorIndex2],
        op: COMPARE_OPS[this.opIndex2],
        value: safeNumber(this.value2, 0)
      });
    }
    return text;
  }

  private previewAction(): string {
    const command = this.currentCommand();
    return actionText({
      target: this.currentTarget(),
      command: command,
      param: command === 'setLevel' ? safeNumber(this.levelText, 0) : undefined
    });
  }

  private async save(): Promise<void> {
    this.error = '';
    if (this.name.trim().length === 0) {
      this.error = '请先填写规则名称';
      return;
    }
    const conditions = this.buildConditions();
    if (conditions === null) {
      return;
    }
    const command = this.currentCommand();
    const firstAction: RuleAction = {
      target: this.currentTarget(),
      command: command,
      param: command === 'setLevel' ? safeNumber(this.levelText, 0) : undefined
    };
    const existing = this.vm.rules.find((rule: Rule) => rule.id === this.editingId);
    let actions: RuleAction[] = [firstAction];
    if (existing !== undefined && existing.actions.length > 0) {
      actions = existing.actions.map((item: RuleAction, index: number) =>
        index === 0 ? firstAction : cloneAction(item));
    }
    const rule: Rule = {
      id: this.editingId.length > 0 ? this.editingId : genId(),
      name: this.name.trim(),
      enabled: this.ruleEnabled,
      logic: this.logicKeys[this.logicIndex],
      conditions: conditions,
      actions: actions,
      priority: this.priority,
      createdAt: existing === undefined ? Date.now() : existing.createdAt
    };
    const errors = validateRule(rule);
    if (errors.length > 0) {
      this.error = errors[0];
      return;
    }

    const saved = existing === undefined ? await this.vm.addRule(rule) : await this.vm.updateRule(rule);
    if (!saved) {
      this.error = this.vm.lastError;
      return;
    }
    router.back();
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontColor(TEXT)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => router.back())
      Text(this.editingId.length > 0 ? '编辑规则' : '新建规则')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('保存')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(BRAND)
        .width(52)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => void this.save())
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 8 })
    .backgroundColor(CARD)
  }

  @Builder
  SectionLabel(title: string, hint: string) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT)
      Blank()
      if (hint.length > 0) {
        Text(hint)
          .fontSize(10)
          .fontColor(MUTED)
      }
    }
    .width('100%')
  }

  @Builder
  BasicCard() {
    Column({ space: 12 }) {
      this.SectionLabel('基本信息', '')
      TextInput({ placeholder: '例如：高温自动开空调', text: this.name })
        .height(42)
        .backgroundColor('#F7F8FB')
        .borderRadius(10)
        .onChange((value: string) => {
          this.name = value;
        })

      Row() {
        Column({ space: 2 }) {
          Text('启用规则')
            .fontSize(13)
            .fontColor(TEXT)
          Text('停用后不参与规则计算')
            .fontSize(10)
            .fontColor(MUTED)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.ruleEnabled })
          .selectedColor(BRAND)
          .onChange((isOn: boolean) => {
            this.ruleEnabled = isOn;
          })
      }
      .width('100%')

      Column({ space: 4 }) {
        Row() {
          Text('冲突优先级')
            .fontSize(13)
            .fontColor(TEXT)
          Blank()
          Text(`P${this.priority}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(BRAND)
        }
        .width('100%')
        Slider({
          value: this.priority,
          min: 0,
          max: 99,
          step: 1,
          style: SliderStyle.OutSet
        })
          .blockColor(BRAND)
          .trackColor('#E8ECF4')
          .selectedColor(BRAND)
          .onChange((value: number) => {
            this.priority = Math.round(value);
          })
        Text('数值越大越优先；同一设备收到不同指令时，高优先级规则获胜。')
          .fontSize(10)
          .fontColor(MUTED)
          .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(CARD)
    .borderRadius(RADIUS)
    .border({ width: 1, color: BORDER })
  }

  @Builder
  ConditionRow(index: number) {
    Column({ space: 7 }) {
      Row({ space: 7 }) {
        Select(this.sensorOptions())
          .selected(index === 1 ? this.sensorIndex1 : this.sensorIndex2)
          .value(sensorLabel(this.sensorKeys[index === 1 ? this.sensorIndex1 : this.sensorIndex2]))
          .font({ size: 12 })
          .layoutWeight(1.1)
          .onSelect((selected: number) => {
            if (index === 1) {
              this.sensorIndex1 = selected;
            } else {
              this.sensorIndex2 = selected;
            }
          })
        Select(this.opOptions())
          .selected(index === 1 ? this.opIndex1 : this.opIndex2)
          .value(COMPARE_OPS[index === 1 ? this.opIndex1 : this.opIndex2] as string)
          .font({ size: 12 })
          .layoutWeight(0.85)
          .onSelect((selected: number) => {
            if (index === 1) {
              this.opIndex1 = selected;
            } else {
              this.opIndex2 = selected;
            }
          })
        TextInput({
          placeholder: '阈值',
          text: index === 1 ? this.value1 : this.value2
        })
          .type(InputType.Number)
          .height(38)
          .backgroundColor('#F7F8FB')
          .borderRadius(8)
          .layoutWeight(0.75)
          .onChange((value: string) => {
            if (index === 1) {
              this.value1 = value;
            } else {
              this.value2 = value;
            }
          })
      }
      .width('100%')

      Text(index === 1 ? '条件 1：当环境满足此比较时进入判断' : '条件 2：与条件 1 按下方逻辑组合')
        .fontSize(9)
        .fontColor(MUTED)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  ConditionCard() {
    Column({ space: 11 }) {
      this.SectionLabel('触发条件', '最多 2 个')
      this.ConditionRow(1)

      if (this.enableCond2) {
        this.ConditionRow(2)
        Row() {
          Text('条件关系')
            .fontSize(12)
            .fontColor(TEXT_SECONDARY)
          Blank()
          Select(this.logicOptions())
            .selected(this.logicIndex)
            .value(this.logicKeys[this.logicIndex] === LogicOp.AND ? '并且（AND）' : '或者（OR）')
            .font({ size: 11 })
            .onSelect((index: number) => {
              this.logicIndex = index;
            })
        }
        .width('100%')
        Row() {
          Text('两个条件同时满足用 AND；任一满足用 OR。')
            .fontSize(10)
            .fontColor(MUTED)
            .layoutWeight(1)
          Text('移除条件 2')
            .fontSize(10)
            .fontColor(DANGER)
            .onClick(() => {
              this.enableCond2 = false;
            })
        }
        .width('100%')
      } else {
        Button('+ 添加第二个条件')
          .height(32)
          .fontSize(11)
          .backgroundColor('#EAF0FF')
          .fontColor(BRAND)
          .type(ButtonType.Capsule)
          .onClick(() => {
            this.enableCond2 = true;
            this.logicIndex = 0;
            if (this.sensorIndex2 === this.sensorIndex1) {
              this.sensorIndex2 = (this.sensorIndex1 + 1) % this.sensorKeys.length;
            }
          })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(CARD)
    .borderRadius(RADIUS)
    .border({ width: 1, color: BORDER })
  }

  @Builder
  ActionCard() {
    Column({ space: 11 }) {
      this.SectionLabel('执行动作',
        this.existingActionCount > 1 ? `保留其余 ${this.existingActionCount - 1} 个动作` : '')
      Row({ space: 7 }) {
        Select(this.deviceOptions())
          .selected(this.targetIndex)
          .value(deviceLabel(this.currentTarget()))
          .font({ size: 12 })
          .layoutWeight(1)
          .onSelect((index: number) => this.onTargetChange(index))
        Select(this.commandOptions())
          .selected(this.commandIndex)
          .value(this.currentCommand() === 'turnOn' ? '打开' :
            (this.currentCommand() === 'turnOff' ? '关闭' : '调到指定档位'))
          .font({ size: 12 })
          .layoutWeight(1)
          .onSelect((index: number) => {
            this.commandIndex = index;
          })
      }
      .width('100%')

      if (this.currentCommand() === 'setLevel') {
        Column({ space: 4 }) {
          Row() {
            Text('目标档位')
              .fontSize(12)
              .fontColor(TEXT_SECONDARY)
            Blank()
            Text(`范围 ${this.levelRange()}`)
              .fontSize(10)
              .fontColor(MUTED)
          }
          .width('100%')
          TextInput({ placeholder: `输入 ${this.levelRange()} 之间的数值`, text: this.levelText })
            .type(InputType.Number)
            .height(38)
            .backgroundColor('#F7F8FB')
            .borderRadius(8)
            .onChange((value: string) => {
              this.levelText = value;
            })
        }
        .width('100%')
      }

      if (this.existingActionCount > 1) {
        Text('该规则包含多个动作。本页编辑第 1 个动作，保存时会保留其余动作，避免误删联动。')
          .fontSize(10)
          .fontColor(MUTED)
          .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(CARD)
    .borderRadius(RADIUS)
    .border({ width: 1, color: BORDER })
  }

  @Builder
  PreviewCard() {
    Column({ space: 7 }) {
      Text('规则预览')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      Text(`当 ${this.previewCondition()}`)
        .fontSize(13)
        .fontColor(TEXT)
        .width('100%')
      Text(`则 ${this.previewAction()}`)
        .fontSize(13)
        .fontColor(BRAND)
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F7F9FF')
    .borderRadius(RADIUS)
    .border({ width: 1, color: '#DCE7FF' })
  }

  build() {
    Column() {
      this.TopBar()

      Scroll() {
        Column({ space: 12 }) {
          this.BasicCard()
          this.ConditionCard()
          this.ActionCard()
          this.PreviewCard()

          if (this.error.length > 0) {
            Text(this.error)
              .fontSize(12)
              .fontColor(DANGER)
              .width('100%')
              .padding(11)
              .backgroundColor(DANGER_BG)
              .borderRadius(9)
          }

          Button('保存规则')
            .width('100%')
            .height(46)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(BRAND)
            .fontColor('#FFFFFF')
            .type(ButtonType.Capsule)
            .onClick(() => void this.save())
        }
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 14, bottom: 30 })
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
