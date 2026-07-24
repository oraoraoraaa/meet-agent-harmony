/**
 * Serializable app settings.
 * Secrets live only in preferences / UI — never commit real values.
 */

/** LLM access mode: direct vendor key, demo proxy, or offline engine-only. */
export type LlmMode = string;
export type AppLanguage = string;
export type TextValue = string;

export const LLM_MODE_USER_KEY: LlmMode = 'user_key';
export const LLM_MODE_PROXY: LlmMode = 'proxy';
export const LLM_MODE_OFFLINE: LlmMode = 'offline';

export const LANG_ZH_CN: AppLanguage = 'zh-CN';
export const LANG_EN: AppLanguage = 'en';

export type MapAppChoice = string;
export const MAP_APP_AMAP: MapAppChoice = 'amap';
export const MAP_APP_BAIDU: MapAppChoice = 'baidu';
export const MAP_APP_APPLE: MapAppChoice = 'apple';
export const MAP_APP_BROWSER: MapAppChoice = 'browser';

export class AppSettings {
  mapApiKey: TextValue = '';
  mapWebKey: TextValue = '';
  llmBaseUrl: TextValue = 'https://api.deepseek.com';
  llmApiKey: TextValue = '';
  llmModel: TextValue = 'deepseek-chat';
  proxyBaseUrl: TextValue = 'http://127.0.0.1:8787';
  llmMode: LlmMode = LLM_MODE_OFFLINE;
  language: AppLanguage = LANG_ZH_CN;
  demoFixtures: boolean = true;
  verboseAgentTrace: boolean = false;
  /** Preferred map app for open-meeting deep links. */
  mapApp: MapAppChoice = MAP_APP_BROWSER;

  clone(): AppSettings {
    const copy: AppSettings = new AppSettings();
    copy.mapApiKey = this.mapApiKey;
    copy.mapWebKey = this.mapWebKey;
    copy.llmBaseUrl = this.llmBaseUrl;
    copy.llmApiKey = this.llmApiKey;
    copy.llmModel = this.llmModel;
    copy.proxyBaseUrl = this.proxyBaseUrl;
    copy.llmMode = this.llmMode;
    copy.language = this.language;
    copy.demoFixtures = this.demoFixtures;
    copy.verboseAgentTrace = this.verboseAgentTrace;
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

  modeLabel(): TextValue {
    if (this.llmMode === LLM_MODE_USER_KEY) {
      return 'User key';
    }
    if (this.llmMode === LLM_MODE_PROXY) {
      return 'Proxy';
    }
    return 'Offline';
  }
}
