import { AppViewModel } from '../viewmodel/AppViewModel';
import { LogEntry, Rule, RuleAction, ExecutedAction, ConflictRecord } from '../model/Types';
import { deviceLabel, actionText } from '../common/Labels';
import { cloneLog, cloneRule } from '../common/Clone';

/** 执行记录面板：展示每次演练的环境快照、触发规则、动作顺序与冲突仲裁结果 */
@Component
export struct LogPanel {
  private vm: AppViewModel = AppViewModel.getInstance();
  @State logs: LogEntry[] = this.vm.logs.map((l: LogEntry) => cloneLog(l));
  @State rules: Rule[] = this.vm.rules.map((r: Rule) => cloneRule(r));

  private sync(): void {
    this.logs = this.vm.logs.map((l: LogEntry) => cloneLog(l));
    this.rules = this.vm.rules.map((r: Rule) => cloneRule(r));
  }

  aboutToAppear(): void {
    this.sync();
  }

  private ruleName(ruleId: string): string {
    const rule = this.rules.find((r: Rule) => r.id === ruleId);
    return rule ? rule.name : ruleId;
  }

  private actionColor(status: string): string {
    switch (status) {
      case 'success':
        return '#2E7D32';
      case 'conflict-won':
        return '#EF6C00';
      case 'blocked':
        return '#C62828';
      default:
        return '#424242';
    }
  }

  private actionDesc(action: ExecutedAction): string {
    const act: RuleAction = {
      target: action.target,
      command: action.command,
      param: action.param
    };
    return `${actionText(act)}（${this.ruleName(action.ruleId)}，${action.status}）`;
  }

  private formatTime(timestamp: number): string {
    return new Date(timestamp).toLocaleString();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('执行记录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Button('清空记录')
          .backgroundColor('#B0BEC5')
          .onClick(() => {
            this.vm.clearLogs();
            this.sync();
          })
      }
      .width('100%')

      if (this.logs.length === 0) {
        Text('暂无演练记录，请到“环境演练”页开始一次模拟')
          .fontSize(14)
          .fontColor('#757575')
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      List({ space: 12 }) {
        ForEach(this.logs, (log: LogEntry) => {
          ListItem() {
            Column({ space: 6 }) {
              Row() {
                Text(log.scenarioName)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                Text(this.formatTime(log.timestamp))
                  .fontSize(12)
                  .fontColor('#757575')
              }
              .width('100%')

              Text(`环境：温度 ${log.env.temperature.toFixed(1)}℃，湿度 ${log.env.humidity.toFixed(0)}%，` +
                `光照 ${log.env.illuminance.toFixed(0)}lux，${log.env.presence === 1 ? '有人' : '无人'}`)
                .fontSize(13)
                .fontColor('#424242')
                .width('100%')

              Text(`触发规则：${log.triggeredRuleIds.map((id: string) => this.ruleName(id)).join('、') || '无'}`)
                .fontSize(13)
                .fontColor('#424242')
                .width('100%')

              ForEach(log.actions, (action: ExecutedAction) => {
                Text(`· ${this.actionDesc(action)}`)
                  .fontSize(12)
                  .fontColor(this.actionColor(action.status))
                  .width('100%')
              }, (action: ExecutedAction) => `${action.ruleId}-${action.target}-${action.command}`)

              ForEach(log.conflicts, (conflict: ConflictRecord) => {
                Text(`冲突[${deviceLabel(conflict.device)}]：${conflict.reason}；` +
                  `获胜规则 ${this.ruleName(conflict.winnerRuleId)}，被拦截 ${this.ruleName(conflict.loserRuleId)}`)
                  .fontSize(12)
                  .fontColor('#C62828')
                  .width('100%')
              }, (conflict: ConflictRecord) => `${conflict.winnerRuleId}-${conflict.loserRuleId}-${conflict.device}`)
            }
            .padding(12)
            .borderRadius(10)
            .backgroundColor('#FFFFFF')
            .width('100%')
          }
        }, (log: LogEntry) => log.id)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .padding(16)
    .width('100%')
  }
}
