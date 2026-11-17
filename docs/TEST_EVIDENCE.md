# 测试与构建证据

> 记录时间：2026-11-17
>
> 工程版本：`1.0.0`，API 17（5.0.5）
>
> 构建工具：DevEco Studio 自带 hvigor 5.0.19、ohpm 5.0.19

## 一、构建结果

### 1. 应用 HAP

命令（工程根目录）：

```bash
hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug
```

结果：

```text
BUILD SUCCESSFUL in 6 s 392 ms
APP_EXIT=0

entry-default-unsigned.hap    426537 bytes    2026-11-17 21:49:54
```

### 2. 测试 HAP

```bash
hvigorw assembleHap --mode module -p product=default -p module=entry@ohosTest -p buildMode=debug
```

结果：

```text
BUILD SUCCESSFUL in 6 s 77 ms
TEST_EXIT=0

entry-ohosTest-unsigned.hap    1320478 bytes    2026-11-17 21:50:01
```

说明：

- 两个 HAP 均为未签名产物，用于验证 `CompileArkTS` 与 `PackageHap` 链路；
- 真机/模拟器安装请在 DevEco Studio 中 Run 或配置自动签名；
- 最终构建路径为 `D:\WangQiQimoDazy\DormLink`（ASCII），因为 hvigor 5.0 的项目路径校验不接受中文路径。

## 二、纯逻辑运行验证

为在没有模拟器的情况下实际执行规则逻辑，将纯逻辑文件（`Types/Constants/Labels/Clone/Validation/MockData/RuleEngine`）复制为 `.ts`，使用 TypeScript 编译后由 Node.js 执行等价断言。

```text
PASS  正常：高温触发开空调
PASS  边界：28℃ 时 > 不触发、>= 触发
PASS  双条件 AND：有人且昏暗
PASS  OR：任一条件满足
PASS  异常：禁用/无条件不触发，目标缺失 blocked
PASS  冲突：高优先级获胜并记录拦截
PASS  同级仲裁：创建更早的规则获胜
PASS  重复指令：同动作合并且无冲突
PASS  档位冲突：高优先级 22℃ 生效
PASS  设备快照：记录 before/after
PASS  潜在冲突：同设备不同动作被标记
PASS  校验：完整规则通过
PASS  校验：空名称/空条件/越界优先级被拒绝
PASS  校验：有人条件只接受 0/1
PASS  校验：setLevel 缺失/越界被拒绝
PASS  校验：环境温度/湿度/有人标记越界
PASS  集成：无人高温场景产生空调冲突且 P10 获胜

RESULT: 17 passed, 0 failed, 17 total
```

## 三、Hypium 用例清单

| 编号 | 文件 | 类型 | 用例 |
| --- | --- | --- | --- |
| T01 | RuleEngine.test.ets | 正常 | 高温 30℃ 触发开空调 |
| T02 | RuleEngine.test.ets | 边界 | 28℃ 时 `>` 与 `>=` 的差异 |
| T03 | RuleEngine.test.ets | 正常 | 双条件 AND |
| T04 | RuleEngine.test.ets | 正常 | OR 逻辑 |
| T05 | RuleEngine.test.ets | 异常 | 禁用/无条件/目标设备缺失 |
| T06 | RuleEngine.test.ets | 冲突 | 高优先级开机 vs 低优先级关机 |
| T07 | RuleEngine.test.ets | 边界 | 同级按创建时间仲裁 |
| T08 | RuleEngine.test.ets | 正常 | 重复动作合并 |
| T09 | RuleEngine.test.ets | 冲突 | 不同 `setLevel` 的档位冲突 |
| T10 | RuleEngine.test.ets | 正常 | 多动作与 before/after 快照 |
| T11 | RuleEngine.test.ets | 正常 | 潜在冲突规则标记 |
| T12 | Validation.test.ets | 正常 | 完整规则通过校验 |
| T13 | Validation.test.ets | 异常 | 空名称/空条件/越界优先级 |
| T14 | Validation.test.ets | 边界 | `有人` 条件只接受 0/1 |
| T15 | Validation.test.ets | 异常 | `setLevel` 缺失/越界 |
| T16 | Validation.test.ets | 异常 | 环境数据越界 |
| T17 | RuleEngine.test.ets | 集成 | 默认“无人高温”场景的空调冲突与 P10 获胜 |

统计：正常 6 条、边界 4 条、异常 4 条、冲突 2 条、集成 1 条，共 17 条；覆盖题目要求的正常、边界、异常三类，并额外覆盖冲突仲裁与默认场景集成。

## 四、设备端执行状态

当前构建机没有可用的 HarmonyOS 模拟器/真机（`hdc list targets` 返回空），因此：

- ✅ `entry@ohosTest` 已通过 ArkTS 编译并成功打包测试 HAP；
- ✅ 规则引擎与校验的 17 条等价断言已在 Node.js 中真实执行通过；
- ⏳ Hypium 在设备端的执行结果，需要在 DevEco Studio 连接模拟器/真机后运行 `List.test.ets` 并截图保存。

设备端测试运行步骤：

1. DevEco Studio 打开工程，连接模拟器或真机；
2. 右键 `entry/src/ohosTest/ets/test/List.test.ets` → Run；
3. 在 Test 面板确认 17 条全部通过；
4. 截图保存到 `docs/screenshots/`，建议命名 `test-report.png`；
5. 在个人 Word 报告中附上测试入口、Mock 输入、预期结果和实际结果截图。

## 五、持久化手工验收清单

| 步骤 | 操作 | 预期 |
| --- | --- | --- |
| P1 | 调整温度/湿度/光照/有人，运行一次演练 | 设备状态变化，执行记录新增 |
| P2 | 修改规则优先级并保存 | 规则列表立即更新 |
| P3 | 保存自定义场景 | 场景卡片数量增加 |
| P4 | 从最近任务中彻底杀掉应用，再打开 | 规则、设备、环境、场景、日志均恢复 |
| P5 | 清空执行记录，再重启 | 记录为空，规则/设备不受影响 |
| P6 | 关闭一条规则后演练 | 该规则不再触发 |
