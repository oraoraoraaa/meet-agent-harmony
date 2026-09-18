// Exercises real selections rather than production demo fixtures.
import { SettingsStore } from '../../../main/ets/services/settings/SettingsStore';
import { application } from '@kit.AbilityKit';
import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON, MatchPattern } from '@kit.TestKit';

export default function mapSmokeTest(): void {
  describe('Native map smoke', () => {
    it('empty home, map selections, planning, locking and bottom tabs', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const context = await application.createModuleContext(delegator.getAppContext().getApplicationContext(), 'entry');
      const driver: Driver = Driver.create();
      await delegator.startAbility({ bundleName: 'com.rinalic.meetAgentHarmony', abilityName: 'EntryAbility' });
      expect(await driver.waitForComponent(ON.text('在哪里会合？'), 10000)).not().assertNull();
      await driver.delayMs(3000);
      await driver.screenCap(context.filesDir + '/meetagent-home.png');
      await (await driver.findComponent(ON.id('passenger-location'))).click();
      expect(await driver.waitForComponent(ON.text('使用当前位置'), 5000)).not().assertNull();
      await (await driver.waitForComponent(ON.type('TextInput'), 5000)).inputText('吉祥村地铁站');
      await (await driver.findComponent(ON.text('搜索'))).click();
      const firstHit = await driver.waitForComponent(ON.id('location-hit-0'), 20000);
      expect(firstHit).not().assertNull();
      await driver.delayMs(500);
      await driver.screenCap(context.filesDir + '/meetagent-location-search.png');
      await firstHit.click();
      await driver.delayMs(500);
      const map = await driver.findComponent(ON.type('Web'));
      const bounds = await map.getBounds();
      await driver.click(Math.round(bounds.left + (bounds.right - bounds.left) * 0.3),
        Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.55));
      await (await driver.waitForComponent(ON.text('设为司机出发地'), 5000)).click();
      await driver.delayMs(1800);
      await driver.click(Math.round(bounds.left + (bounds.right - bounds.left) * 0.65),
        Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.65));
      await (await driver.waitForComponent(ON.text('设为乘客位置'), 5000)).click();
      await driver.delayMs(1800);
      expect(await driver.findComponent(ON.text('当前位置 · 点此更改'))).assertNull();
      // Search zooms close to a station; use a distant driver origin so transit is meaningful.
      await (await driver.findComponent(ON.id('driver-location'))).click();
      await (await driver.waitForComponent(ON.type('TextInput'), 5000)).inputText('西安北苑地铁站');
      await (await driver.findComponent(ON.text('搜索'))).click();
      await (await driver.waitForComponent(ON.id('location-hit-0'), 20000)).click();
      await driver.delayMs(500);
      await (await driver.waitForComponent(ON.text('规划会合路线'), 5000)).click();
      await driver.delayMs(500);
      expect(await driver.findComponent(ON.text('公共交通'))).not().assertNull();
      await (await driver.waitForComponent(ON.text('地铁优先'), 5000)).click();
      await driver.delayMs(300);
      await driver.screenCap(context.filesDir + '/meetagent-form.png');
      await (await driver.findComponent(ON.type('Scroll'))).scrollToBottom();
      await (await driver.waitForComponent(ON.text('开始路线优化'), 5000)).click();
      expect(await driver.waitForComponent(ON.text('优化结果'), 60000)).not().assertNull();
      await driver.delayMs(2000);
      expect(await driver.screenCap(context.filesDir + '/meetagent-plan.png')).assertTrue();
      const resultScroll = await driver.findComponent(ON.type('Scroll'));
      await resultScroll.scrollToBottom();
      await driver.screenCap(context.filesDir + '/meetagent-plan-detail.png');
      const transitCard = await resultScroll.scrollSearch(ON.id('plan-card-transit'));
      expect(transitCard).not().assertNull();
      await transitCard.click();
      expect(await driver.findComponent(ON.text('关闭'))).assertNull();
      expect(await resultScroll.scrollSearch(ON.text('乘客路线'))).not().assertNull();
      expect(await resultScroll.scrollSearch(ON.text('上车 ·', MatchPattern.STARTS_WITH))).not().assertNull();
      await driver.delayMs(500);
      await driver.screenCap(context.filesDir + '/meetagent-passenger-route.png');
      await resultScroll.scrollToBottom();
      await (await driver.waitForComponent(ON.text('确认并锁定方案'), 5000)).click();
      expect(await driver.waitForComponent(ON.text('我的行程'), 15000)).not().assertNull();
      await driver.delayMs(2000);
      expect(await driver.screenCap(context.filesDir + '/meetagent-locked.png')).assertTrue();
      expect(await driver.findComponent(ON.text('‹'))).assertNull();
      await (await driver.findComponent(ON.text('助手'))).click();
      expect(await driver.waitForComponent(ON.text('智能助手'), 5000)).not().assertNull();
      await driver.delayMs(1000);
      await driver.screenCap(context.filesDir + '/meetagent-chat.png');
      expect(await driver.findComponent(ON.text('‹'))).assertNull();
      await (await driver.findComponent(ON.text('设置').within(ON.type('Column')))).click();
      await driver.delayMs(1000);
      await driver.screenCap(context.filesDir + '/meetagent-settings.png');
      expect(await driver.findComponent(ON.text('‹'))).assertNull();
    });
    it('missing map key shows setup warning and blocks planning', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const context = await application.createModuleContext(delegator.getAppContext().getApplicationContext(), 'entry');
      const mainAbility = await delegator.getCurrentTopAbility();
      const saved = await SettingsStore.load(mainAbility.context);
      const missing = saved.clone();
      missing.mapWebKey = '';
      const driver: Driver = Driver.create();
      try {
        await SettingsStore.save(mainAbility.context, missing);
        await (await driver.waitForComponent(ON.text('地图'), 5000)).click();
        expect(await driver.waitForComponent(ON.text('请先配置地图 Key'), 5000)).not().assertNull();
        await (await driver.findComponent(ON.text('规划会合路线'))).click();
        expect(await driver.waitForComponent(ON.text('请先在设置中配置高德 Web 服务 Key'), 5000)).not().assertNull();
        expect(await driver.findComponent(ON.text('开始路线优化'))).assertNull();
        await driver.screenCap(context.filesDir + '/meetagent-missing-key.png');
      } finally {
        await SettingsStore.save(mainAbility.context, saved);
      }
    });
  });
}
