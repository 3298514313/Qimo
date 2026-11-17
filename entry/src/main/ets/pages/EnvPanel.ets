import { AppViewModel } from '../viewmodel/AppViewModel';
import {
  EnvSnapshot,
  DeviceState,
  Scenario,
  LogEntry,
  ExecutedAction
} from '../model/Types';
import { cloneDevice, cloneEnv, cloneLog, cloneScenario } from '../common/Clone';
import {
  deviceColor,
  deviceIconText,
  deviceLabel,
  deviceStateText,
  deviceUnit
} from '../common/Labels';
import { validateEnv } from '../common/Validation';
import { EventBus, AppEvent } from '../bus/EventBus';
import {
  BRAND,
  BG,
  CARD,
  TEXT,
  TEXT_SECONDARY,
  MUTED,
  BORDER,
  SUCCESS,
  SUCCESS_BG,
  WARNING,
  DANGER,
  DANGER_BG,
  RADIUS,
  PAGE_PADDING,
  PURPLE
} from '../common/Theme';

/**
 * 环境演练页：
 * 调整 4 项 Mock 数据 -> 载入/保存场景 -> 运行规则 -> 查看设备变化与冲突摘要。
 */
@Component
export struct EnvPanel {
  private vm: AppViewModel = AppViewModel.getInstance();

  @State env: EnvSnapshot = cloneEnv(this.vm.env);
  @State devices: DeviceState[] = this.vm.devices.map((device: DeviceState) => cloneDevice(device));
  @State scenarios: Scenario[] = this.vm.scenarios.map((item: Scenario) => cloneScenario(item));
  @State scenarioName: string = '';
  @State message: string = '';
  @State messageIsError: boolean = false;
  @State busy: boolean = false;
  @State lastLog: LogEntry | null = null;

  private sync(): void {
    this.env = cloneEnv(this.vm.env);
    this.devices = this.vm.devices.map((device: DeviceState) => cloneDevice(device));
    this.scenarios = this.vm.scenarios.map((item: Scenario) => cloneScenario(item));
    this.lastLog = this.vm.logs.length > 0 ? cloneLog(this.vm.logs[0]) : null;
  }

  aboutToAppear(): void {
    this.sync();
    EventBus.on(AppEvent.DEVICES_CHANGED, () => this.sync());
    EventBus.on(AppEvent.SCENARIOS_CHANGED, () => this.sync());
  }

  aboutToDisappear(): void {
    EventBus.off(AppEvent.DEVICES_CHANGED);
    EventBus.off(AppEvent.SCENARIOS_CHANGED);
  }

  private setMessage(text: string, isError: boolean): void {
    this.message = text;
    this.messageIsError = isError;
  }

  private adjustEnv(field: string, value: number): void {
    if (field === 'temperature') {
      this.vm.adjustEnv({ temperature: value });
    } else if (field === 'humidity') {
      this.vm.adjustEnv({ humidity: value });
    } else if (field === 'illuminance') {
      this.vm.adjustEnv({ illuminance: value });
    }
    this.env = cloneEnv(this.vm.env);
  }

  private async runSimulation(scenarioName: string): Promise<void> {
    if (this.busy) {
      return;
    }
    const errors = validateEnv(this.env);
    if (errors.length > 0) {
      this.setMessage(errors[0], true);
      return;
    }
    this.busy = true;
    try {
      const log = await this.vm.runSimulation(scenarioName);
      this.sync();
      const applied = log.actions.filter((action: ExecutedAction) => action.status !== 'blocked').length;
      let text = `演练完成：命中 ${log.triggeredRuleIds.length} 条规则，执行 ${applied} 个动作`;
      if (log.conflicts.length > 0) {
        text += `，仲裁 ${log.conflicts.length} 处冲突`;
      }
      if (this.vm.lastError.length > 0) {
        text += `；${this.vm.lastError}`;
      }
      this.setMessage(text, this.vm.lastError.length > 0);
    } catch (error) {
      const message = error instanceof Error ? error.message : '演练失败';
      this.setMessage(message, true);
    } finally {
      this.busy = false;
    }
  }

  private async runScenario(scenario: Scenario): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      await this.vm.loadScenario(scenario.id);
      this.sync();
      this.busy = false;
      await this.runSimulation(scenario.name);
    } catch (error) {
      this.busy = false;
      const message = error instanceof Error ? error.message : '载入场景失败';
      this.setMessage(message, true);
    }
  }

  private async saveScenario(): Promise<void> {
    const saved = await this.vm.saveScenario(this.scenarioName);
    this.sync();
    this.scenarioName = '';
    this.setMessage(saved ? '当前环境与设备设置已保存为场景' : this.vm.lastError, !saved);
  }

  private async togglePower(device: DeviceState, isOn: boolean): Promise<void> {
    const saved = await this.vm.setDevicePower(device.key, isOn);
    this.sync();
    if (!saved) {
      this.setMessage(this.vm.lastError, true);
    }
  }

  private appliedCount(log: LogEntry): number {
    return log.actions.filter((action: ExecutedAction) => action.status !== 'blocked').length;
  }

  private lastScenarioName(): string {
    return this.lastLog === null ? '' : this.lastLog.scenarioName;
  }

  private lastTriggeredCount(): number {
    return this.lastLog === null ? 0 : this.lastLog.triggeredRuleIds.length;
  }

  private lastAppliedCount(): number {
    return this.lastLog === null ? 0 : this.appliedCount(this.lastLog);
  }

  private lastConflictCount(): number {
    return this.lastLog === null ? 0 : this.lastLog.conflicts.length;
  }

  private lastConflictReason(): string {
    if (this.lastLog === null || this.lastLog.conflicts.length === 0) {
      return '';
    }
    return this.lastLog.conflicts[0].reason;
  }

  @Builder
  SectionTitle(title: string, hint: string) {
    Row() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT)
      Blank()
      Text(hint)
        .fontSize(11)
        .fontColor(MUTED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  @Builder
  TemperatureSlider() {
    Column({ space: 1 }) {
      Row() {
        Row({ space: 7 }) {
          Circle({ width: 8, height: 8 }).fill('#F79009')
          Text('室内温度').fontSize(13).fontColor(TEXT_SECONDARY)
        }
        Blank()
        Text(`${this.env.temperature}℃`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
      }
      .width('100%')

      Slider({
        value: this.env.temperature,
        min: 10,
        max: 40,
        step: 0.5,
        style: SliderStyle.OutSet
      })
        .blockColor('#F79009')
        .trackColor('#E8ECF4')
        .selectedColor('#F79009')
        .onChange((next: number, mode: SliderChangeMode) => {
          this.adjustEnv('temperature', next);
          if (mode === SliderChangeMode.End) {
            void this.vm.saveEnvironment();
          }
        })
    }
    .width('100%')
  }

  @Builder
  HumiditySlider() {
    Column({ space: 1 }) {
      Row() {
        Row({ space: 7 }) {
          Circle({ width: 8, height: 8 }).fill(BRAND)
          Text('空气湿度').fontSize(13).fontColor(TEXT_SECONDARY)
        }
        Blank()
        Text(`${this.env.humidity}%`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
      }
      .width('100%')

      Slider({
        value: this.env.humidity,
        min: 0,
        max: 100,
        step: 1,
        style: SliderStyle.OutSet
      })
        .blockColor(BRAND)
        .trackColor('#E8ECF4')
        .selectedColor(BRAND)
        .onChange((next: number, mode: SliderChangeMode) => {
          this.adjustEnv('humidity', next);
          if (mode === SliderChangeMode.End) {
            void this.vm.saveEnvironment();
          }
        })
    }
    .width('100%')
  }

  @Builder
  IlluminanceSlider() {
    Column({ space: 1 }) {
      Row() {
        Row({ space: 7 }) {
          Circle({ width: 8, height: 8 }).fill(PURPLE)
          Text('环境光照').fontSize(13).fontColor(TEXT_SECONDARY)
        }
        Blank()
        Text(`${this.env.illuminance}lx`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
      }
      .width('100%')

      Slider({
        value: this.env.illuminance,
        min: 0,
        max: 1000,
        step: 10,
        style: SliderStyle.OutSet
      })
        .blockColor(PURPLE)
        .trackColor('#E8ECF4')
        .selectedColor(PURPLE)
        .onChange((next: number, mode: SliderChangeMode) => {
          this.adjustEnv('illuminance', next);
          if (mode === SliderChangeMode.End) {
            void this.vm.saveEnvironment();
          }
        })
    }
    .width('100%')
  }
  @Builder
  EnvCard() {
    Column({ space: 13 }) {
      Row() {
        Text('模拟环境')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
        Blank()
        Text('4 项可调')
          .fontSize(10)
          .fontColor(BRAND)
          .backgroundColor('#EAF0FF')
          .borderRadius(6)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
      }
      .width('100%')

      this.TemperatureSlider()
      this.HumiditySlider()
      this.IlluminanceSlider()

      Row() {
        Column({ space: 2 }) {
          Text('是否有人')
            .fontSize(13)
            .fontColor(TEXT_SECONDARY)
          Text(this.env.presence === 1 ? '检测到活动，适合居住联动' : '无人场景，可验证节能规则')
            .fontSize(11)
            .fontColor(MUTED)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.env.presence === 1 })
          .selectedColor(BRAND)
          .onChange((isOn: boolean) => {
            this.vm.adjustEnv({ presence: isOn ? 1 : 0 });
            this.env = cloneEnv(this.vm.env);
            void this.vm.saveEnvironment();
          })
      }
      .width('100%')
      .padding({ top: 2 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(CARD)
    .borderRadius(RADIUS)
    .shadow({ radius: 18, color: '#0A1A3A12', offsetX: 0, offsetY: 5 })
  }

  @Builder
  ScenarioCard(scenario: Scenario) {
    Column({ space: 6 }) {
      Row() {
        Text(scenario.name)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
        Blank()
        Text(`${scenario.env.temperature}℃`)
          .fontSize(11)
          .fontColor(MUTED)
      }
      .width('100%')

      Text(scenario.description)
        .fontSize(11)
        .fontColor(TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Button('载入并演练')
        .fontSize(11)
        .height(26)
        .backgroundColor('#EAF0FF')
        .fontColor(BRAND)
        .type(ButtonType.Capsule)
        .onClick(() => void this.runScenario(scenario))
    }
    .width(210)
    .padding(12)
    .backgroundColor(CARD)
    .borderRadius(14)
    .border({ width: 1, color: BORDER })
  }

  @Builder
  DeviceCard(device: DeviceState) {
    Column({ space: 8 }) {
      Row() {
        Text(deviceIconText(device.key))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor(deviceColor(device.key))
          .borderRadius(9)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: device.powered })
          .selectedColor(deviceColor(device.key))
          .onChange((isOn: boolean) => void this.togglePower(device, isOn))
      }
      .width('100%')

      Column({ space: 2 }) {
        Text(deviceLabel(device.key))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT)
          .width('100%')
        Text(deviceStateText(device.powered, device.level, device.key))
          .fontSize(12)
          .fontColor(device.powered ? deviceColor(device.key) : MUTED)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(device.powered ? '运行中' : '待机')
          .fontSize(10)
          .fontColor(device.powered ? SUCCESS : MUTED)
          .backgroundColor(device.powered ? SUCCESS_BG : '#F2F4F7')
          .borderRadius(5)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        Blank()
        Text(`${device.level}${deviceUnit(device.key)}`)
          .fontSize(11)
          .fontColor(MUTED)
      }
      .width('100%')
    }
    .width('100%')
    .height(140)
    .padding(12)
    .backgroundColor(CARD)
    .borderRadius(15)
    .border({ width: 1, color: BORDER })
  }

  @Builder
  ResultCard() {
    if (this.lastLog !== null) {
      Column({ space: 8 }) {
        Row() {
          Text('最近一次演练')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_SECONDARY)
          Blank()
          Text(this.lastScenarioName())
            .fontSize(11)
            .fontColor(MUTED)
        }
        .width('100%')

        Row({ space: 8 }) {
          Text(`触发 ${this.lastTriggeredCount()}`)
            .fontSize(11)
            .fontColor(BRAND)
            .backgroundColor('#EAF0FF')
            .borderRadius(5)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          Text(`执行 ${this.lastAppliedCount()}`)
            .fontSize(11)
            .fontColor(SUCCESS)
            .backgroundColor(SUCCESS_BG)
            .borderRadius(5)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          Text(`冲突 ${this.lastConflictCount()}`)
            .fontSize(11)
            .fontColor(this.lastConflictCount() > 0 ? DANGER : MUTED)
            .backgroundColor(this.lastConflictCount() > 0 ? DANGER_BG : '#F2F4F7')
            .borderRadius(5)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        }
        .width('100%')

        if (this.lastConflictCount() > 0) {
          Text(this.lastConflictReason())
            .fontSize(11)
            .fontColor(WARNING)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(CARD)
      .borderRadius(RADIUS)
      .border({ width: 1, color: BORDER })
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.SectionTitle('环境演练', '调整 Mock 数据，观察规则如何改变设备')
        this.EnvCard()

        Row() {
          Text('场景速演')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT)
          Blank()
          Text(`${this.scenarios.length} 组场景`)
            .fontSize(11)
            .fontColor(MUTED)
        }
        .width('100%')

        List({ space: 10 }) {
          ForEach(this.scenarios, (scenario: Scenario) => {
            ListItem() {
              this.ScenarioCard(scenario)
            }
          }, (scenario: Scenario) => scenario.id)
        }
        .listDirection(Axis.Horizontal)
        .height(132)
        .width('100%')
        .scrollBar(BarState.Off)

        Button(this.busy ? '规则计算中…' : '开始模拟演练')
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.busy ? '#AFC4F5' : BRAND)
          .fontColor('#FFFFFF')
          .type(ButtonType.Capsule)
          .enabled(!this.busy)
          .onClick(() => void this.runSimulation('手动演练'))

        if (this.message.length > 0) {
          Row({ space: 7 }) {
            Text(this.messageIsError ? '!' : '✓')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.messageIsError ? DANGER : SUCCESS)
            Text(this.message)
              .fontSize(12)
              .fontColor(this.messageIsError ? DANGER : TEXT_SECONDARY)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.messageIsError ? DANGER_BG : SUCCESS_BG)
          .borderRadius(10)
        }

        this.ResultCard()

        Row() {
          Text('设备状态')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT)
          Blank()
          Text('可手动开关，状态会保存')
            .fontSize(10)
            .fontColor(MUTED)
        }
        .width('100%')

        Grid() {
          ForEach(this.devices, (device: DeviceState) => {
            GridItem() {
              this.DeviceCard(device)
            }
          }, (device: DeviceState) => device.key)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .height(290)
        .width('100%')

        Column({ space: 8 }) {
          Text('保存当前场景')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT)
            .width('100%')
          Row({ space: 8 }) {
            TextInput({ placeholder: '场景名称，例如“周末午后”', text: this.scenarioName })
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#F7F8FB')
              .borderRadius(10)
              .onChange((value: string) => {
                this.scenarioName = value;
              })
            Button('保存')
              .height(40)
              .backgroundColor('#EAF0FF')
              .fontColor(BRAND)
              .type(ButtonType.Capsule)
              .onClick(() => void this.saveScenario())
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor(CARD)
        .borderRadius(RADIUS)
        .border({ width: 1, color: BORDER })
      }
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 16, bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
    .scrollBar(BarState.Off)
  }
}
