/**
 * Serializable app settings.
 * Secrets live only in preferences / UI — never commit real values.
 */

/** LLM access mode: direct vendor key, demo proxy, or offline engine-only. */
export type LlmMode = string;
export type TextValue = string;

export const LLM_MODE_USER_KEY: LlmMode = 'user_key';
export const LLM_MODE_PROXY: LlmMode = 'proxy';
export const LLM_MODE_OFFLINE: LlmMode = 'offline';


export type MapAppChoice = string;
export const MAP_APP_AMAP: MapAppChoice = 'amap';
export const MAP_APP_BAIDU: MapAppChoice = 'baidu';
export const MAP_APP_APPLE: MapAppChoice = 'apple';
export const MAP_APP_BROWSER: MapAppChoice = 'browser';

export class AppSettings {
  mapWebKey: TextValue = '';
  llmBaseUrl: TextValue = 'https://api.deepseek.com';
  llmApiKey: TextValue = '';
  llmModel: TextValue = 'deepseek-chat';
  proxyBaseUrl: TextValue = 'http://127.0.0.1:8787';
  llmMode: LlmMode = LLM_MODE_OFFLINE;
  /** Preferred map app for open-meeting deep links. */
  mapApp: MapAppChoice = MAP_APP_BROWSER;

  clone(): AppSettings {
    const copy: AppSettings = new AppSettings();
    copy.mapWebKey = this.mapWebKey;
    copy.llmBaseUrl = this.llmBaseUrl;
    copy.llmApiKey = this.llmApiKey;
    copy.llmModel = this.llmModel;
    copy.proxyBaseUrl = this.proxyBaseUrl;
    copy.llmMode = this.llmMode;
    copy.mapApp = this.mapApp;
    return copy;
  }

  /** True when Mode A/B can attempt LLM calls. */
  llmConfigured(): boolean {
    if (this.llmMode === LLM_MODE_OFFLINE) {
      return false;
    }
    if (this.llmMode === LLM_MODE_PROXY) {
      return this.proxyBaseUrl.trim().length > 0;
    }
    return this.llmBaseUrl.trim().length > 0 && this.llmApiKey.trim().length > 0;
  }

}
