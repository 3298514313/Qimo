import { AppViewModel } from '../viewmodel/AppViewModel';
import { EnvSnapshot, DeviceState, Scenario } from '../model/Types';
import { cloneDevice, cloneEnv, cloneScenario } from '../common/Clone';
import { deviceLabel } from '../common/Labels';

/** 环境演练面板：调整 Mock 环境数据、载入场景、执行联动演练、保存场景 */
@Component
export struct EnvPanel {
  private vm: AppViewModel = AppViewModel.getInstance();
  @State env: EnvSnapshot = cloneEnv(this.vm.env);
  @State devices: DeviceState[] = this.vm.devices.map((d: DeviceState) => cloneDevice(d));
  @State scenarios: Scenario[] = this.vm.scenarios.map((s: Scenario) => cloneScenario(s));
  @State scenarioName: string = '';
  @State message: string = '';

  private sync(): void {
    this.env = cloneEnv(this.vm.env);
    this.devices = this.vm.devices.map((d: DeviceState) => cloneDevice(d));
    this.scenarios = this.vm.scenarios.map((s: Scenario) => cloneScenario(s));
  }

  aboutToAppear(): void {
    this.sync();
  }

  private scenarioOptions(): SelectOption[] {
    return this.scenarios.map((s: Scenario): SelectOption => ({ value: s.name }));
  }

  private async runSimulation(): Promise<void> {
    const log = await this.vm.runSimulation('手动演练');
    this.sync();
    this.message = `演练完成：触发 ${log.triggeredRuleIds.length} 条规则，执行 ${log.actions.length} 个动作，冲突 ${log.conflicts.length} 处`;
  }

  private async saveScenario(): Promise<void> {
    await this.vm.saveScenario(this.scenarioName);
    this.sync();
    this.scenarioName = '';
    this.message = '当前环境与设备设置已保存为场景';
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('模拟环境数据')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')

        Row() {
          Text('温度').layoutWeight(1)
          Text(`${this.env.temperature.toFixed(1)} ℃`)
        }
        Slider({
          value: this.env.temperature,
          min: 10,
          max: 40,
          step: 0.5,
          style: SliderStyle.OutSet
        })
          .onChange((v: number) => {
            this.vm.adjustEnv({ temperature: v });
            this.sync();
          })

        Row() {
          Text('湿度').layoutWeight(1)
          Text(`${this.env.humidity.toFixed(0)} %`)
        }
        Slider({
          value: this.env.humidity,
          min: 0,
          max: 100,
          step: 1,
          style: SliderStyle.OutSet
        })
          .onChange((v: number) => {
            this.vm.adjustEnv({ humidity: v });
            this.sync();
          })

        Row() {
          Text('光照').layoutWeight(1)
          Text(`${this.env.illuminance.toFixed(0)} lux`)
        }
        Slider({
          value: this.env.illuminance,
          min: 0,
          max: 1000,
          step: 10,
          style: SliderStyle.OutSet
        })
          .onChange((v: number) => {
            this.vm.adjustEnv({ illuminance: v });
            this.sync();
          })

        Row() {
          Text('是否有人').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.env.presence === 1 })
            .onChange((isOn: boolean) => {
              this.vm.adjustEnv({ presence: isOn ? 1 : 0 });
              this.sync();
            })
        }

        Row({ space: 8 }) {
          Text('载入场景').layoutWeight(1)
          Select(this.scenarioOptions())
            .onSelect((index: number) => {
              this.vm.loadScenario(this.scenarios[index].id);
              this.sync();
            })
        }

        Row({ space: 8 }) {
          TextInput({ placeholder: '场景名称（可空）', text: this.scenarioName })
            .layoutWeight(1)
            .onChange((v: string) => { this.scenarioName = v; })
          Button('保存场景')
            .onClick(() => void this.saveScenario())
        }

        Button('开始模拟演练')
          .width('100%')
          .type(ButtonType.Capsule)
          .onClick(() => void this.runSimulation())

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor('#1565C0')
            .width('100%')
        }

        Text('当前设备状态')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        ForEach(this.devices, (d: DeviceState) => {
          Row({ space: 12 }) {
            Text(deviceLabel(d.key))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text(d.powered ? '开机' : '关机')
              .fontSize(14)
              .fontColor(d.powered ? '#2E7D32' : '#757575')
            Text(`档位 ${d.level}`)
              .fontSize(14)
              .fontColor('#424242')
          }
          .padding(12)
          .borderRadius(10)
          .backgroundColor('#F5F7FA')
          .width('100%')
        }, (d: DeviceState) => d.key)
      }
      .padding(16)
      .width('100%')
    }
  }
}
