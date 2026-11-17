import { router } from '@kit.ArkUI';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { Rule } from '../model/Types';
import { cloneRule } from '../common/Clone';
import { actionsText, conditionsText, priorityLabel } from '../common/Labels';
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

interface RouterParams {
  ruleId?: string;
}

/** 规则管理页：列表、启停、新增、编辑、删除与潜在冲突提示 */
@Component
export struct RulePanel {
  private vm: AppViewModel = AppViewModel.getInstance();

  @State rules: Rule[] = this.vm.rules.map((rule: Rule) => cloneRule(rule));
  @State conflictIds: string[] = [];

  private sync(): void {
    this.rules = this.vm.rules.map((rule: Rule) => cloneRule(rule));
    this.conflictIds = this.vm.potentialConflictRuleIds();
  }

  aboutToAppear(): void {
    this.sync();
    EventBus.on(AppEvent.RULES_CHANGED, () => this.sync());
  }

  aboutToDisappear(): void {
    EventBus.off(AppEvent.RULES_CHANGED);
  }

  private enabledCount(): number {
    return this.rules.filter((rule: Rule) => rule.enabled).length;
  }

  private goEdit(ruleId?: string): void {
    const params: RouterParams = {};
    if (ruleId !== undefined) {
      params.ruleId = ruleId;
    }
    router.pushUrl({ url: 'pages/RuleEdit', params: params });
  }

  private async toggle(rule: Rule): Promise<void> {
    await this.vm.toggleRule(rule.id);
    this.sync();
  }

  private confirmDelete(rule: Rule): void {
    AlertDialog.show({
      title: '删除规则',
      message: `确定删除「${rule.name}」？删除后无法恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: DANGER,
        action: () => {
          void this.remove(rule);
        }
      }
    });
  }

  private async remove(rule: Rule): Promise<void> {
    await this.vm.deleteRule(rule.id);
    this.sync();
  }

  private isConflict(rule: Rule): boolean {
    return this.conflictIds.indexOf(rule.id) >= 0;
  }

  @Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Text('自动化规则')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
        Text(`共 ${this.rules.length} 条 · 已启用 ${this.enabledCount()} 条`)
          .fontSize(11)
          .fontColor(MUTED)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('+ 新建规则')
        .height(36)
        .fontSize(12)
        .backgroundColor(BRAND)
        .fontColor('#FFFFFF')
        .type(ButtonType.Capsule)
        .onClick(() => this.goEdit())
    }
    .width('100%')
  }

  @Builder
  ConflictBanner() {
    if (this.conflictIds.length > 0) {
      Row({ space: 9 }) {
        Text('!')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WARNING)
          .width(26)
          .height(26)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
        Column({ space: 2 }) {
          Text(`${this.conflictIds.length} 条规则可能竞争同一设备`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B54708')
          Text('运行时按优先级由高到低执行，低优先级的不同指令会被拦截并写入日志。')
            .fontSize(10)
            .fontColor('#B54708')
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(WARNING_BG)
      .borderRadius(12)
      .border({ width: 1, color: '#FEDF89' })
    }
  }

  @Builder
  RuleCard(rule: Rule) {
    Column({ space: 9 }) {
      Row({ space: 8 }) {
        Text(priorityLabel(rule.priority))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(BRAND)
          .backgroundColor('#EAF0FF')
          .borderRadius(5)
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
        Text(rule.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(rule.enabled ? TEXT : MUTED)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
          .selectedColor(BRAND)
          .onChange((isOn: boolean) => {
            void this.toggle(rule);
          })
      }
      .width('100%')

      Row({ space: 7 }) {
        Text('当')
          .fontSize(10)
          .fontColor(MUTED)
          .width(22)
        Text(conditionsText(rule))
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 7 }) {
        Text('则')
          .fontSize(10)
          .fontColor(MUTED)
          .width(22)
        Text(actionsText(rule))
          .fontSize(12)
          .fontColor(TEXT)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 6 }) {
        if (rule.conditions.length >= 2) {
          Text('双条件')
            .fontSize(9)
            .fontColor('#7A5AF8')
            .backgroundColor('#F4F0FF')
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        }
        if (this.isConflict(rule)) {
          Text('潜在冲突')
            .fontSize(9)
            .fontColor(WARNING)
            .backgroundColor(WARNING_BG)
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        }
        if (rule.enabled) {
          Text('运行中')
            .fontSize(9)
            .fontColor(SUCCESS)
            .backgroundColor(SUCCESS_BG)
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        }
        Blank()
        Button('编辑')
          .fontSize(11)
          .height(27)
          .backgroundColor('#F2F4F7')
          .fontColor(TEXT_SECONDARY)
          .type(ButtonType.Capsule)
          .onClick(() => this.goEdit(rule.id))
        Button('删除')
          .fontSize(11)
          .height(27)
          .backgroundColor(DANGER_BG)
          .fontColor(DANGER)
          .type(ButtonType.Capsule)
          .onClick(() => this.confirmDelete(rule))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(CARD)
    .borderRadius(RADIUS)
    .border({ width: 1, color: BORDER })
    .opacity(rule.enabled ? 1 : 0.72)
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Text('规')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(BRAND)
        .width(56)
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EAF0FF')
        .borderRadius(16)
      Text('还没有规则')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT)
      Text('新建一条“当…则…”规则，让宿舍设备自动联动')
        .fontSize(11)
        .fontColor(MUTED)
        .textAlign(TextAlign.Center)
      Button('新建第一条规则')
        .height(36)
        .fontSize(12)
        .backgroundColor(BRAND)
        .fontColor('#FFFFFF')
        .type(ButtonType.Capsule)
        .onClick(() => this.goEdit())
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column({ space: 12 }) {
      this.Header()
      this.ConflictBanner()

      if (this.rules.length === 0) {
        this.EmptyState()
      } else {
        List({ space: 10 }) {
          ForEach(this.rules, (rule: Rule) => {
            ListItem() {
              this.RuleCard(rule)
            }
          }, (rule: Rule) => rule.id)
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
