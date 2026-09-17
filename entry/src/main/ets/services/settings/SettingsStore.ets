import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppSettings,
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

const KEY_MAP_WEB: string = 'mapWebKey';
const KEY_LLM_BASE: string = 'llmBaseUrl';
const KEY_LLM_KEY: string = 'llmApiKey';
const KEY_LLM_MODEL: string = 'llmModel';
const KEY_PROXY: string = 'proxyBaseUrl';
const KEY_LLM_MODE: string = 'llmMode';
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


/**
 * Preferences-backed settings store (device-local).
 */
export class SettingsStore {
  static async load(context: common.Context): Promise<AppSettings> {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const settings: AppSettings = new AppSettings();
    settings.mapWebKey = await readString(store, KEY_MAP_WEB, '');
    settings.llmBaseUrl = await readString(store, KEY_LLM_BASE, settings.llmBaseUrl);
    settings.llmApiKey = await readString(store, KEY_LLM_KEY, '');
    settings.llmModel = await readString(store, KEY_LLM_MODEL, settings.llmModel);
    settings.proxyBaseUrl = await readString(store, KEY_PROXY, settings.proxyBaseUrl);
    settings.llmMode = asLlmMode(await readString(store, KEY_LLM_MODE, LLM_MODE_OFFLINE));
    settings.mapApp = asMapApp(await readString(store, KEY_MAP_APP, MAP_APP_BROWSER));
    return settings;
  }

  static async save(context: common.Context, settings: AppSettings): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(KEY_MAP_WEB, settings.mapWebKey);
    await store.put(KEY_LLM_BASE, settings.llmBaseUrl);
    await store.put(KEY_LLM_KEY, settings.llmApiKey);
    await store.put(KEY_LLM_MODEL, settings.llmModel);
    await store.put(KEY_PROXY, settings.proxyBaseUrl);
    await store.put(KEY_LLM_MODE, settings.llmMode);
    await store.put(KEY_MAP_APP, settings.mapApp);
    await store.flush();
  }
}
