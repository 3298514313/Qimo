import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppViewModel } from '../viewmodel/AppViewModel';

const DOMAIN = 0x0000;

/**
 * 应用入口 Ability。
 * 在 onCreate 中初始化全局 ViewModel 并从本地持久化恢复数据，
 * 保证冷启动后规则、设备、场景与日志均可恢复。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const viewModel = AppViewModel.getInstance();
    viewModel.init(this.context);
    void viewModel.restore();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', '加载页面失败: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', '%{public}s', '页面加载成功');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onWindowStageDestroy');
  }
}
