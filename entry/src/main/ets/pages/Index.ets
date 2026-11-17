import { EnvPanel } from './EnvPanel';
import { RulePanel } from './RulePanel';
import { LogPanel } from './LogPanel';
import { BRAND, BRAND_DARK, CARD, MUTED, BORDER } from '../common/Theme';

/** 应用主页：顶部品牌区 + 底部三个业务页签 */
@Entry
@Component
struct Index {
  @State currentTab: number = 0;

  @Builder
  TabBarItem(label: string, glyph: string, index: number) {
    Column({ space: 3 }) {
      Text(glyph)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTab === index ? '#FFFFFF' : MUTED)
        .width(30)
        .height(23)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.currentTab === index ? BRAND : Color.Transparent)
        .borderRadius(8)
      Text(label)
        .fontSize(11)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTab === index ? BRAND : MUTED)
    }
    .width('100%')
    .height(58)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  Header() {
    Row() {
      Column({ space: 5 }) {
        Text('联动实验室')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text('智能宿舍 · 自动化规则编排')
          .fontSize(13)
          .fontColor('#D6E2FF')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 4 }) {
        Text('MOCK')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(BRAND_DARK)
          .backgroundColor('#FFFFFF')
          .borderRadius(6)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        Text('本地持久化')
          .fontSize(10)
          .fontColor('#D6E2FF')
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 18 })
    .backgroundColor(BRAND_DARK)
  }

  build() {
    Column() {
      this.Header()

      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          EnvPanel()
        }
        .tabBar(this.TabBarItem('环境演练', '环', 0))

        TabContent() {
          RulePanel()
        }
        .tabBar(this.TabBarItem('规则管理', '规', 1))

        TabContent() {
          LogPanel()
        }
        .tabBar(this.TabBarItem('执行记录', '志', 2))
      }
      .barMode(BarMode.Fixed)
      .barHeight(62)
      .barBackgroundColor(CARD)
      .divider({ strokeWidth: 1, color: BORDER })
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FA')
  }
}
