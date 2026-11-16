# DormLink 智能宿舍自动化规则编排 App

> 《鸿蒙高级应用开发工程师认证》期末大作业 · 主题三：联动实验室——智能宿舍自动化规则编排 App
>
> 作者：任树山（学号 20230313214） · GitHub 账号：`待填写` · GitHub 仓库：`待填写`

## 一、项目简介

面向智能宿舍管理，学生自行设计“满足条件时执行设备动作”的自动联动方案，并用模拟环境（Mock 数据）检验联动效果。应用不依赖真实硬件或云平台，全部设备与环境数据均在本地模拟，规则引擎根据实际输入计算触发结果，记录触发条件、设备变化与执行顺序，并对相互冲突的控制按优先级仲裁。

完整体验链路：**创建规则 → 调整 Mock 环境 → 观察设备联动及日志 → 发现冲突并调整优先级 → 退出重启恢复规则与记录**。

## 二、功能与题目要求对照

| 题目要求 | 实现情况 | 对应代码 |
| --- | --- | --- |
| 至少 4 类可控制设备 | 空调、灯光、窗帘、加湿器 4 类 | `model/Types.ets`、`mock/MockData.ets` |
| 至少 3 项可调整模拟环境数据 | 温度、湿度、光照、是否有人 4 项 | `model/Types.ets`、`pages/EnvPanel.ets` |
| 支持新增、修改、启停至少 4 条规则 | 默认 4 条规则，支持新增 / 编辑 / 启停 / 删除 | `pages/RulePanel.ets`、`pages/RuleEdit.ets`、`viewmodel/AppViewModel.ets` |
| 至少 1 条双条件共同决定的规则 | “有人且昏暗自动开灯”（光照 < 200 且 有人 == 1，AND） | `mock/MockData.ets` |
| 规则引擎按实际输入计算触发结果 | 条件比较、AND/OR 逻辑判断 | `engine/RuleEngine.ets` |
| 记录触发条件、设备变化、执行顺序 | 执行日志含触发规则、动作列表、状态、时间戳 | `engine/RuleEngine.ets`、`pages/LogPanel.ets` |
| 冲突控制提供执行顺序 / 优先级处理 | 优先级高者先生效，相反指令被拦截并记录冲突原因 | `engine/RuleEngine.ets` |
| 至少 2 组环境场景模拟演练 | “白天在室”“夜间宿舍”两组场景，可保存新场景 | `mock/MockData.ets`、`pages/EnvPanel.ets` |
| 数据持久化，退出重启可恢复 | 规则、设备、场景、日志均写入 Preferences，启动时恢复 | `store/PreferencesStore.ets`、`viewmodel/AppViewModel.ets` |
| 单元测试覆盖正常 / 边界 / 异常 | 4 条测试：正常触发、边界等值、异常输入、冲突仲裁 | `entry/src/ohosTest/ets/test/RuleEngine.test.ets` |

## 三、技术栈

- HarmonyOS Stage 模型，API 17（compatibleSdkVersion 5.0.5(17)）
- ArkTS + ArkUI（状态管理、Tabs/List/ForEach/Slider/Select/Toggle/TextInput 等组件）
- `@kit.ArkData` Preferences 本地持久化
- `@kit.BasicServicesKit` emitter 事件总线（跨模块通信）
- `@ohos/hypium` 单元测试框架

## 四、目录结构

```
DormLink/
├── AppScope/
│   ├── app.json5                          # 应用包名、版本
│   └── resources/base/element/string.json
├── entry/
│   ├── oh-package.json5
│   ├── build-profile.json5
│   └── src/
│       ├── main/
│       │   ├── module.json5
│       │   ├── ets/
│       │   │   ├── entryability/EntryAbility.ets   # 入口 Ability，启动时恢复数据
│       │   │   ├── common/Constants.ets          # 存储键、ID 生成、数字解析
│       │   │   ├── common/Labels.ets             # 中文名称与条件/动作文案
│       │   │   ├── common/Clone.ets              # 显式字段拷贝（替代对象展开）
│       │   │   ├── model/Types.ets               # 数据模型与枚举定义
│       │   │   ├── mock/MockData.ets              # 默认规则、设备、场景
│       │   │   ├── bus/EventBus.ets              # emitter 事件封装
│       │   │   ├── store/PreferencesStore.ets    # Preferences 持久化封装
│       │   │   ├── engine/RuleEngine.ets         # 规则匹配、冲突仲裁、日志生成
│       │   │   ├── viewmodel/AppViewModel.ets    # 全局状态与业务编排
│       │   │   └── pages/
│       │   │       ├── Index.ets                 # 主页 Tabs 容器
│       │   │       ├── EnvPanel.ets              # 环境演练面板
│       │   │       ├── RulePanel.ets             # 规则管理面板
│       │   │       ├── LogPanel.ets              # 执行记录面板
│       │   │       └── RuleEdit.ets              # 规则新增/编辑页
│       │   └── resources/base/...
│       └── ohosTest/ets/test/
│           ├── List.test.ets
│           └── RuleEngine.test.ets
├── build-profile.json5
├── oh-package.json5
└── README.md
```

## 五、开发环境与运行步骤

1. 安装 DevEco Studio 5.0，配置 HarmonyOS SDK（API 17，5.0.5(17)）。
2. 打开 DevEco Studio → `Open` → 选择本目录 `DormLink`，等待 `ohpm install` 同步依赖。
3. 选择手机 / 平板模拟器或真机，点击运行，应用首屏为“环境演练”页签。
4. 演练流程：
   - 在“环境演练”拖动滑块调整温度 / 湿度 / 光照，切换是否有人；
   - 点击“开始模拟演练”，查看设备状态变化；
   - 切换到“执行记录”查看触发规则、动作顺序与冲突记录；
   - 在“规则管理”新增 / 编辑 / 启停 / 删除规则；
   - 完全退出应用后重新打开，规则、设备、场景与历史日志应仍在。

## 六、单元测试清单

| 编号 | 类型 | 用例 | 预期 |
| --- | --- | --- | --- |
| T1 | 正常 | 温度 30℃ 满足 >28 | 规则触发，空调开机，动作为 success |
| T2 | 边界 | 温度恰好 28℃ | `>` 不触发，`>=` 触发 |
| T3 | 异常 | 禁用规则 / 无条件规则 / 动作目标设备不存在 | 不触发；缺失目标动作记为 blocked |
| T4 | 冲突 | 高优先级开机、低优先级关机同时触发 | 高优先级获胜，低优先级被拦截并记录冲突 |

运行方式：DevEco Studio 中打开 `entry/src/ohosTest/ets/test/RuleEngine.test.ets`，右键运行测试用例；或在 Terminal 执行 `hvigorw ohosTest`。

## 七、持久化与异常处理说明

- **保存**：规则、设备状态、场景、执行日志通过 Preferences 以 JSON 字符串写入本地。
- **恢复**：`EntryAbility.onCreate` 初始化 ViewModel 并调用 `restore()`，冷启动后回读；读取为空或 JSON 解析失败时回退到 Mock 默认值，避免应用崩溃。
- **异常分支**：动作目标设备不存在、阈值非数字、规则被禁用、条件为空等情况均有明确处理，不会产生未定义行为。

## 八、待补充交付项（提交前完成）

- [ ] 在 GitHub 新建仓库，推送全部源码，提交记录使用本人账号；
- [ ] 录制完整运行录屏：环境调整 → 规则联动 → 冲突记录 → 退出重启恢复；
- [ ] 按评分标准撰写个人 Word 报告：`鸿蒙高级应用开发工程师认证-20230313214-任树山-期末大作业报告.docx`；
- [ ] 在学习通作业答案处填写 GitHub 仓库链接与本人 GitHub 账号名称（缺一项计 0 分）；
- [ ] 报告中补充架构图、关键代码与 Commit 记录、三类测试证据、新技术认识与自主学习资料。

## 九、截图占位

> 运行后在此处补充：主页环境演练、规则管理、执行记录、规则编辑、重启恢复等截图。
