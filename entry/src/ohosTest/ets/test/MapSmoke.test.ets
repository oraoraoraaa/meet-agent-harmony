// Exercises real selections rather than production demo fixtures.
import { SettingsStore } from '../../../main/ets/services/settings/SettingsStore';
import { LLM_MODE_OFFLINE } from '../../../main/ets/common/AppSettings';
import { application } from '@kit.AbilityKit';
import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';

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
      expect(await driver.findComponent(ON.text('在地图上选择出发地'))).assertNull();
      expect(await driver.findComponent(ON.text('在地图上选择乘客位置'))).assertNull();
      await (await driver.waitForComponent(ON.text('规划会合路线'), 5000)).click();
      await driver.delayMs(500);
      await driver.screenCap(context.filesDir + '/meetagent-form.png');
      await (await driver.waitForComponent(ON.text('开始路线优化'), 5000)).click();
      expect(await driver.waitForComponent(ON.text('优化结果'), 60000)).not().assertNull();
      await driver.delayMs(2000);
      expect(await driver.screenCap(context.filesDir + '/meetagent-plan.png')).assertTrue();
      const resultScroll = await driver.findComponent(ON.type('Scroll'));
      await resultScroll.scrollToBottom();
      await driver.screenCap(context.filesDir + '/meetagent-plan-detail.png');
      await (await driver.waitForComponent(ON.text('确认并锁定方案'), 5000)).click();
      expect(await driver.waitForComponent(ON.text('我的行程'), 15000)).not().assertNull();
      await driver.delayMs(2000);
      expect(await driver.screenCap(context.filesDir + '/meetagent-locked.png')).assertTrue();
      await (await driver.findComponent(ON.text('助手'))).click();
      expect(await driver.waitForComponent(ON.text('智能助手'), 5000)).not().assertNull();
      await driver.delayMs(1000);
      await driver.screenCap(context.filesDir + '/meetagent-chat.png');
      await (await driver.findComponent(ON.text('设置').within(ON.type('Column')))).click();
      await driver.delayMs(1000);
      await driver.screenCap(context.filesDir + '/meetagent-settings.png');
    });
    it('offline preferences still produce labeled estimates without sample trips', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const context = await application.createModuleContext(delegator.getAppContext().getApplicationContext(), 'entry');
      const mainAbility = await delegator.getCurrentTopAbility();
      const saved = await SettingsStore.load(mainAbility.context);
      const offline = saved.clone();
      offline.mapWebKey = '';
      offline.llmMode = LLM_MODE_OFFLINE;
      const driver: Driver = Driver.create();
      try {
        await SettingsStore.save(mainAbility.context, offline);
        await delegator.startAbility({ bundleName: 'com.rinalic.meetAgentHarmony', abilityName: 'EntryAbility' });
        await (await driver.waitForComponent(ON.text('地图'), 5000)).click();
        await driver.delayMs(1800);
        const bounds = await (await driver.findComponent(ON.type('Web'))).getBounds();
        await driver.click(Math.round(bounds.left + (bounds.right - bounds.left) * 0.35),
          Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.5));
        await (await driver.waitForComponent(ON.text('设为司机出发地'), 5000)).click();
        await driver.delayMs(800);
        await driver.click(Math.round(bounds.left + (bounds.right - bounds.left) * 0.62),
          Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.62));
        await (await driver.waitForComponent(ON.text('设为乘客位置'), 5000)).click();
        await driver.delayMs(800);
        await driver.screenCap(context.filesDir + '/meetagent-offline-home.png');
        await (await driver.findComponent(ON.text('规划会合路线'))).click();
        await (await driver.waitForComponent(ON.text('开始路线优化'), 5000)).click();
        expect(await driver.waitForComponent(ON.text('估算'), 10000)).not().assertNull();
        await driver.delayMs(1000);
        await driver.screenCap(context.filesDir + '/meetagent-offline-plan.png');
        await (await driver.findComponent(ON.text('地图'))).click();
        expect(await driver.waitForComponent(ON.text('在哪里会合？'), 5000)).not().assertNull();
        await (await driver.findComponent(ON.text('助手'))).click();
        expect(await driver.waitForComponent(ON.text('设置偏好并规划'), 5000)).not().assertNull();
        await driver.delayMs(1000);
        await driver.screenCap(context.filesDir + '/meetagent-offline-chat.png');
      } finally {
        await SettingsStore.save(mainAbility.context, saved);
      }
    });
  });
}
