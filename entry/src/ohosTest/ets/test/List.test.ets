import ruleEngineTest from './RuleEngine.test';
import validationTest from './Validation.test';

/**
 * Hypium 测试入口。
 * 当前共 17 条：规则引擎 12 条 + 校验 5 条，覆盖正常、边界、异常与冲突仲裁。
 */
export default function testsuite(): void {
  ruleEngineTest();
  validationTest();
}
