import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppLanguage,
  AppSettings,
  LANG_EN,
  LANG_ZH_CN,
  LLM_MODE_OFFLINE,
  LLM_MODE_PROXY,
  LLM_MODE_USER_KEY,
  LlmMode,
  MAP_APP_AMAP,
  MAP_APP_APPLE,
  MAP_APP_BAIDU,
  MAP_APP_BROWSER,
  MapAppChoice
} from '../../common/AppSettings';

const STORE_NAME: string = 'meet_agent_settings';

const KEY_MAP_API: string = 'mapApiKey';
const KEY_MAP_WEB: string = 'mapWebKey';
const KEY_LLM_BASE: string = 'llmBaseUrl';
const KEY_LLM_KEY: string = 'llmApiKey';
const KEY_LLM_MODEL: string = 'llmModel';
const KEY_PROXY: string = 'proxyBaseUrl';
const KEY_LLM_MODE: string = 'llmMode';
const KEY_LANG: string = 'language';
const KEY_FIXTURES: string = 'demoFixtures';
const KEY_TRACE: string = 'verboseAgentTrace';
const KEY_MAP_APP: string = 'mapApp';

function asLlmMode(raw: string): LlmMode {
  if (raw === LLM_MODE_USER_KEY) {
    return LLM_MODE_USER_KEY;
  }
  if (raw === LLM_MODE_PROXY) {
    return LLM_MODE_PROXY;
  }
  return LLM_MODE_OFFLINE;
}

function asLanguage(raw: string): AppLanguage {
  if (raw === LANG_EN) {
    return LANG_EN;
  }
  return LANG_ZH_CN;
}

function asMapApp(raw: string): MapAppChoice {
  if (raw === MAP_APP_AMAP) {
    return MAP_APP_AMAP;
  }
  if (raw === MAP_APP_BAIDU) {
    return MAP_APP_BAIDU;
  }
  if (raw === MAP_APP_APPLE) {
    return MAP_APP_APPLE;
  }
  return MAP_APP_BROWSER;
}

async function readString(
  store: preferences.Preferences,
  key: string,
  fallback: string
): Promise<string> {
  const value: preferences.ValueType = await store.get(key, fallback);
  if (typeof value === 'string') {
    return value;
  }
  return fallback;
}

async function readBool(
  store: preferences.Preferences,
  key: string,
  fallback: boolean
): Promise<boolean> {
  const value: preferences.ValueType = await store.get(key, fallback);
  if (typeof value === 'boolean') {
    return value;
  }
  return fallback;
}

/**
 * Preferences-backed settings store (device-local).
 */
export class SettingsStore {
  static async load(context: common.Context): Promise<AppSettings> {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const settings: AppSettings = new AppSettings();
    settings.mapApiKey = await readString(store, KEY_MAP_API, '');
    settings.mapWebKey = await readString(store, KEY_MAP_WEB, '');
    settings.llmBaseUrl = await readString(store, KEY_LLM_BASE, settings.llmBaseUrl);
    settings.llmApiKey = await readString(store, KEY_LLM_KEY, '');
    settings.llmModel = await readString(store, KEY_LLM_MODEL, settings.llmModel);
    settings.proxyBaseUrl = await readString(store, KEY_PROXY, settings.proxyBaseUrl);
    settings.llmMode = asLlmMode(await readString(store, KEY_LLM_MODE, LLM_MODE_OFFLINE));
    settings.language = asLanguage(await readString(store, KEY_LANG, LANG_ZH_CN));
    settings.demoFixtures = await readBool(store, KEY_FIXTURES, true);
    settings.verboseAgentTrace = await readBool(store, KEY_TRACE, false);
    settings.mapApp = asMapApp(await readString(store, KEY_MAP_APP, MAP_APP_BROWSER));
    return settings;
  }

  static async save(context: common.Context, settings: AppSettings): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(KEY_MAP_API, settings.mapApiKey);
    await store.put(KEY_MAP_WEB, settings.mapWebKey);
    await store.put(KEY_LLM_BASE, settings.llmBaseUrl);
    await store.put(KEY_LLM_KEY, settings.llmApiKey);
    await store.put(KEY_LLM_MODEL, settings.llmModel);
    await store.put(KEY_PROXY, settings.proxyBaseUrl);
    await store.put(KEY_LLM_MODE, settings.llmMode);
    await store.put(KEY_LANG, settings.language);
    await store.put(KEY_FIXTURES, settings.demoFixtures);
    await store.put(KEY_TRACE, settings.verboseAgentTrace);
    await store.put(KEY_MAP_APP, settings.mapApp);
    await store.flush();
  }
}
