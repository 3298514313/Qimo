import { emitter } from '@kit.BasicServicesKit';

/** 应用内事件标识（emitter 事件 ID 为数值） */
export enum AppEvent {
  DATA_READY = 1000,
  RULES_CHANGED = 1001,
  DEVICES_CHANGED = 1002,
  LOG_PUSHED = 1003,
  SCENARIOS_CHANGED = 1004,
  PERSISTED = 1005,
  PERSIST_FAILED = 1006
}

/** 事件载荷（显式接口，满足 ArkTS 严格模式对象字面量要求） */
export interface AppPayload {
  logId?: string;
  message?: string;
}

/**
 * 轻量事件总线：基于 emitter 封装，用于规则、设备、日志之间的跨模块通信。
 * 页面订阅事件后刷新本地状态，规则引擎不直接持有页面引用。
 */
export class EventBus {
  static emit(event: AppEvent, data: AppPayload): void {
    const inner: emitter.InnerEvent = { eventId: event, priority: emitter.EventPriority.HIGH };
    const eventData: emitter.EventData = { data };
    emitter.emit(inner, eventData);
  }

  static on(event: AppEvent, callback: (data: AppPayload) => void): void {
    const inner: emitter.InnerEvent = { eventId: event };
    emitter.on(inner, (eventData: emitter.EventData) => {
      const payload = eventData.data as AppPayload;
      callback(payload);
    });
  }

  static off(event: AppEvent): void {
    emitter.off(event);
  }
}
