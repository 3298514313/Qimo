import { AppViewModel } from '../viewmodel/AppViewModel';
import {
  LogEntry,
  RuleAction,
  ExecutedAction,
  ConflictRecord,
  DeviceState
} from '../model/Types';
import { cloneLog } from '../common/Clone';
import {
  actionText,
  deviceLabel,
  deviceStateText,
  statusLabel
} from '../common/Labels';
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
  WARNING_BG,
  DANGER,
  DANGER_BG,
  RADIUS,
  PAGE_PADDING
} from '../common/Theme';

interface ChangeRow {
  key: string;
  label: string;
  text: string;
}

/** 执行记录页：展示每次演练的环境、触发条件、动作顺序、设备变化与冲突仲裁 */
@Component
export struct LogPanel {
  private vm: AppViewModel = AppViewModel.getInstance();

  @State logs: LogEntry[] = this.vm.logs.map((log: LogEntry) => cloneLog(log));
  @State expandedId: string = '';

  private sync(): void {
    this.logs = this.vm.logs.map((log: LogEntry) => cloneLog(log));
  }

  aboutToAppear(): void {
    this.sync();
    EventBus.on(AppEvent.LOG_PUSHED, () => this.sync());
  }

  aboutToDisappear(): void {
    EventBus.off(AppEvent.LOG_PUSHED);
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private statusColor(status: string): string {
    if (status === 'blocked') {
      return DANGER;
    }
    if (status === 'conflict-won') {
      return WARNING;
    }
    return SUCCESS;
  }

  private statusBackground(status: string): string {
    if (status === 'blocked') {
      return DANGER_BG;
    }
    if (status === 'conflict-won') {
      return WARNING_BG;
    }
    return SUCCESS_BG;
  }

  private actionLabel(action: ExecutedAction): string {
    const ruleAction: RuleAction = {
      target: action.target,
      command: action.command,
      param: action.param
    };
    return actionText(ruleAction);
  }

  private changeRows(log: LogEntry): ChangeRow[] {
    const rows: ChangeRow[] = [];
    log.deviceBefore.forEach((before: DeviceState) => {
      const after = log.deviceAfter.find((item: DeviceState) => item.key === before.key);
      if (after === undefined) {
        return;
      }
      if (before.powered !== after.powered || before.level !== after.level) {
        rows.push({
          key: before.key,
          label: deviceLabel(before.key),
          text: `${deviceStateText(before.powered, before.level, before.key)} → ` +
            `${deviceStateText(after.powered, after.level, after.key)}`
        });
      }
    });
    return rows;
  }

  private toggleExpand(log: LogEntry): void {
    this.expandedId = this.expandedId === log.id ? '' : log.id;
  }

  private confirmClear(): void {
    AlertDialog.show({
      title: '清空执行记录',
      message: '将删除全部历史演练记录，规则和设备设置不受影响。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: DANGER,
        action: () => {
          void this.clearAll();
        }
      }
    });
  }

  private async clearAll(): Promise<void> {
    await this.vm.clearLogs();
    this.expandedId = '';
    this.sync();
  }

  @Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Text('执行记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
        Text(`保留最近 ${this.logs.length} 次演练，可用于核对规则链路`)
          .fontSize(11)
          .fontColor(MUTED)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('清空')
        .height(34)
        .fontSize(11)
        .backgroundColor(this.logs.length > 0 ? DANGER_BG : '#F2F4F7')
        .fontColor(this.logs.length > 0 ? DANGER : MUTED)
        .type(ButtonType.Capsule)
        .enabled(this.logs.length > 0)
        .onClick(() => this.confirmClear())
    }
    .width('100%')
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Text('志')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(BRAND)
        .width(56)
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EAF0FF')
        .borderRadius(16)
      Text('还没有执行记录')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT)
      Text('到“环境演练”调整数据并运行一次，这里会记录完整链路')
        .fontSize(11)
        .fontColor(MUTED)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 70, bottom: 70 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ActionRow(action: ExecutedAction) {
    Column({ space: 4 }) {
      Row({ space: 7 }) {
        Text(`${action.rulePriority}`)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(24)
          .height(20)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.statusColor(action.status))
          .borderRadius(5)
        Text(action.ruleName)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(statusLabel(action.status))
          .fontSize(9)
          .fontColor(this.statusColor(action.status))
          .backgroundColor(this.statusBackground(action.status))
          .borderRadius(4)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
      }
      .width('100%')

      Text(`条件：${action.conditionSummary}`)
        .fontSize(10)
        .fontColor(MUTED)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`动作：${this.actionLabel(action)} · ${action.note}`)
        .fontSize(10)
        .fontColor(this.statusColor(action.status))
        .width('100%')
        .maxLines(2)
    }
    .width('100%')
    .padding(9)
    .backgroundColor('#FAFBFD')
    .borderRadius(8)
  }

  @Builder
  LogCard(log: LogEntry) {
    Column({ space: 9 }) {
      Row() {
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(log.scenarioName)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(TEXT)
            if (log.conflicts.length > 0) {
              Text('有冲突')
                .fontSize(9)
                .fontColor(DANGER)
                .backgroundColor(DANGER_BG)
                .borderRadius(4)
                .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            }
          }
          Text(this.formatTime(log.timestamp))
            .fontSize(10)
            .fontColor(MUTED)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button(this.expandedId === log.id ? '收起' : '详情')
          .fontSize(10)
          .height(26)
          .backgroundColor('#F2F4F7')
          .fontColor(TEXT_SECONDARY)
          .type(ButtonType.Capsule)
          .onClick(() => this.toggleExpand(log))
      }
      .width('100%')

      Text(`环境 ${log.env.temperature}℃ · ${log.env.humidity}% · ${log.env.illuminance}lx · ` +
        `${log.env.presence === 1 ? '有人' : '无人'}`)
        .fontSize(10)
        .fontColor(TEXT_SECONDARY)
        .width('100%')

      Row({ space: 7 }) {
        Text(`触发 ${log.triggeredRuleIds.length}`)
          .fontSize(10)
          .fontColor(BRAND)
          .backgroundColor('#EAF0FF')
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        Text(`执行 ${log.actions.filter((item: ExecutedAction) => item.status !== 'blocked').length}`)
          .fontSize(10)
          .fontColor(SUCCESS)
          .backgroundColor(SUCCESS_BG)
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        Text(`冲突 ${log.conflicts.length}`)
          .fontSize(10)
          .fontColor(log.conflicts.length > 0 ? DANGER : MUTED)
          .backgroundColor(log.conflicts.length > 0 ? DANGER_BG : '#F2F4F7')
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
      .width('100%')

      if (this.expandedId === log.id) {
        Column({ space: 7 }) {
          Text('动作执行顺序')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT)
            .width('100%')

          ForEach(log.actions, (action: ExecutedAction) => {
            this.ActionRow(action)
          }, (action: ExecutedAction) => `${log.id}-${action.ruleId}-${action.target}-${action.command}`)

          if (log.conflicts.length > 0) {
            Column({ space: 5 }) {
              Text('冲突仲裁')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(DANGER)
                .width('100%')
              ForEach(log.conflicts, (conflict: ConflictRecord) => {
                Text(`${deviceLabel(conflict.device)}：${conflict.reason}`)
                  .fontSize(10)
                  .fontColor('#B42318')
                  .width('100%')
              }, (conflict: ConflictRecord) =>
                `${log.id}-${conflict.winnerRuleId}-${conflict.loserRuleId}-${conflict.device}`)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(DANGER_BG)
            .borderRadius(8)
          }

          Column({ space: 5 }) {
            Text('设备变化')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(TEXT)
              .width('100%')
            if (this.changeRows(log).length === 0) {
              Text('本次没有设备状态变化')
                .fontSize(10)
                .fontColor(MUTED)
                .width('100%')
            } else {
              ForEach(this.changeRows(log), (row: ChangeRow) => {
                Row() {
                  Text(row.label)
                    .fontSize(10)
                    .fontColor(TEXT_SECONDARY)
                    .width(52)
                  Text(row.text)
                    .fontSize(10)
                    .fontColor(TEXT)
                    .layoutWeight(1)
                }
                .width('100%')
              }, (row: ChangeRow) => `${log.id}-${row.key}`)
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F7F8FB')
          .borderRadius(8)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(CARD)
    .borderRadius(RADIUS)
    .border({ width: 1, color: BORDER })
  }

  build() {
    Column({ space: 12 }) {
      this.Header()

      if (this.logs.length === 0) {
        this.EmptyState()
      } else {
        List({ space: 10 }) {
          ForEach(this.logs, (log: LogEntry) => {
            ListItem() {
              this.LogCard(log)
            }
          }, (log: LogEntry) => log.id)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 16, bottom: 16 })
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
