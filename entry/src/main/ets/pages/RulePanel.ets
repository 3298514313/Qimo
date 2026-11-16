import { router } from '@kit.ArkUI';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { Rule } from '../model/Types';
import { cloneRule } from '../common/Clone';
import { conditionText, actionText } from '../common/Labels';

/** 路由跳转参数（显式接口） */
interface RouterParams {
  ruleId?: string;
}

/** 规则管理面板：规则列表、启停、新增、编辑、删除 */
@Component
export struct RulePanel {
  private vm: AppViewModel = AppViewModel.getInstance();
  @State rules: Rule[] = this.vm.rules.map((r: Rule) => cloneRule(r));

  private sync(): void {
    this.rules = this.vm.rules.map((r: Rule) => cloneRule(r));
  }

  aboutToAppear(): void {
    this.sync();
  }

  private goEdit(ruleId?: string): void {
    const params: RouterParams = {};
    if (ruleId !== undefined) {
      params.ruleId = ruleId;
    }
    router.pushUrl({ url: 'pages/RuleEdit', params });
  }

  private conditionSummary(rule: Rule): string {
    const joinOp = rule.logic === 'OR' ? ' 或 ' : ' 且 ';
    return rule.conditions.map((c) => conditionText(c)).join(joinOp);
  }

  private actionSummary(rule: Rule): string {
    return rule.actions.map((a) => actionText(a)).join('、');
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('规则管理')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Button('新增规则')
          .onClick(() => this.goEdit())
      }
      .width('100%')

      List({ space: 12 }) {
        ForEach(this.rules, (rule: Rule) => {
          ListItem() {
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text(rule.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
                  .onChange(() => {
                    this.vm.toggleRule(rule.id);
                    this.sync();
                  })
              }
              Text(`条件：${this.conditionSummary(rule)}`)
                .fontSize(13)
                .fontColor('#424242')
                .width('100%')
              Text(`动作：${this.actionSummary(rule)}`)
                .fontSize(13)
                .fontColor('#424242')
                .width('100%')
              Row({ space: 8 }) {
                Text(`优先级 ${rule.priority}`)
                  .fontSize(12)
                  .fontColor('#757575')
                  .layoutWeight(1)
                Button('编辑')
                  .fontSize(12)
                  .height(28)
                  .onClick(() => this.goEdit(rule.id))
                Button('删除')
                  .fontSize(12)
                  .height(28)
                  .backgroundColor('#B0BEC5')
                  .onClick(() => {
                    this.vm.deleteRule(rule.id);
                    this.sync();
                  })
              }
            }
            .padding(12)
            .borderRadius(10)
            .backgroundColor('#FFFFFF')
            .width('100%')
          }
        }, (rule: Rule) => rule.id)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .padding(16)
    .width('100%')
  }
}
