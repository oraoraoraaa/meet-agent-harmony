/**
 * Serializable app settings for Phase 0+.
 * Secrets live only in preferences / UI — never commit real values.
 */
export type LlmMode = 'user_key' | 'proxy' | 'offline';

export type AppLanguage = 'zh-CN' | 'en';

export class AppSettings {
  mapApiKey: string = '';
  mapWebKey: string = '';
  llmBaseUrl: string = 'https://api.deepseek.com';
  llmApiKey: string = '';
  llmModel: string = 'deepseek-chat';
  proxyBaseUrl: string = 'http://127.0.0.1:8787';
  llmMode: LlmMode = 'offline';
  language: AppLanguage = 'zh-CN';
  demoFixtures: boolean = true;
  verboseAgentTrace: boolean = false;

  clone(): AppSettings {
    const copy = new AppSettings();
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
    return copy;
  }

  /** True when Mode A/B can attempt LLM calls. */
  llmConfigured(): boolean {
    if (this.llmMode === 'offline') {
      return false;
    }
    if (this.llmMode === 'proxy') {
      return this.proxyBaseUrl.trim().length > 0;
    }
    return this.llmBaseUrl.trim().length > 0 && this.llmApiKey.trim().length > 0;
  }

  modeLabel(): string {
    if (this.llmMode === 'user_key') {
      return 'User key';
    }
    if (this.llmMode === 'proxy') {
      return 'Proxy';
    }
    return 'Offline';
  }
}
