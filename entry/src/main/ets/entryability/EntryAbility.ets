import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppViewModel } from '../viewmodel/AppViewModel';

const DOMAIN = 0x0000;
const TAG = 'DormLink';

/**
 * 应用入口 Ability。
 * 先初始化 Preferences 并完成 restore，再加载首页，
 * 避免页面首次渲染时读到空数组，确保冷启动恢复可见。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppViewModel.getInstance().init(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    AppViewModel.getInstance().restore()
      .then(() => {
        windowStage.loadContent('pages/Index', (err) => {
          if (err.code) {
            hilog.error(DOMAIN, TAG, '加载页面失败: %{public}s', JSON.stringify(err));
          }
        });
      })
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, '恢复数据失败: %{public}s', error.message);
        windowStage.loadContent('pages/Index');
      });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onWindowStageDestroy');
  }
}
