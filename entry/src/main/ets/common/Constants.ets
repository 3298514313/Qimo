/** 全局常量与工具函数 */

/** Preferences 存储键名（显式接口，满足 ArkTS 严格模式对象字面量要求） */
export interface StorageKeys {
  RULES: string;
  DEVICES: string;
  SCENARIOS: string;
  LOGS: string;
  ENV: string;
}

/** Preferences 存储键名 */
export const STORAGE_KEYS: StorageKeys = {
  RULES: 'rules',
  DEVICES: 'devices',
  SCENARIOS: 'scenarios',
  LOGS: 'logs',
  ENV: 'env'
};

/** 执行记录最多保留条数 */
export const MAX_LOGS: number = 30;

/** 生成简短唯一 ID */
export function genId(): string {
  const timePart = Date.now().toString(36);
  const randomPart = Math.floor(Math.random() * 1000000).toString(36);
  return `${timePart}-${randomPart}`;
}

/** 数字安全解析，解析失败返回兜底值 */
export function safeNumber(text: string, fallback: number): number {
  const n = Number(text);
  return Number.isNaN(n) ? fallback : n;
}
