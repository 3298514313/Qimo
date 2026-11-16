import { EnvPanel } from './EnvPanel';
import { RulePanel } from './RulePanel';
import { LogPanel } from './LogPanel';

/** 应用主页：底部三个页签，分别对应环境演练、规则管理、执行记录 */
@Entry
@Component
struct Index {
  @State currentTab: number = 0;

  build() {
    Tabs({ index: this.currentTab }) {
      TabContent() {
        EnvPanel()
      }
      .tabBar('环境演练')

      TabContent() {
        RulePanel()
      }
      .tabBar('规则管理')

      TabContent() {
        LogPanel()
      }
      .tabBar('执行记录')
    }
    .barPosition(BarPosition.End)
    .onChange((index: number) => { this.currentTab = index; })
    .width('100%')
    .height('100%')
  }
}
