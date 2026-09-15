// Uses the device's current map settings; enable fixture mode for a network-free run.
import { application } from '@kit.AbilityKit';
import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';

export default function mapSmokeTest(): void {
  describe('Native map smoke', () => {
    it('home and planning maps load and a plan can be locked', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const context = await application.createModuleContext(delegator.getAppContext().getApplicationContext(), 'entry');
      const driver: Driver = Driver.create();
      await delegator.startAbility({ bundleName: 'com.rinalic.meetAgentHarmony', abilityName: 'EntryAbility' });
      await driver.delayMs(1500);
      await driver.screenCap(context.filesDir + '/meetagent-home.png');
      expect(await driver.waitForComponent(ON.text('接驾会合规划'), 10000)).not().assertNull();
      const homeScroll = await driver.findComponent(ON.type('Scroll'));
      await homeScroll.scrollToBottom();
      const planButton = await driver.waitForComponent(ON.text('普通规划'), 5000);
      await planButton.click();
      await driver.delayMs(1000);
      await driver.screenCap(context.filesDir + '/meetagent-form.png');
      const start = await driver.waitForComponent(ON.text('开始路线优化'), 5000);
      await start.click();
      expect(await driver.waitForComponent(ON.text('推荐方案'), 30000)).not().assertNull();
      await driver.delayMs(500);
      expect(await driver.screenCap(context.filesDir + '/meetagent-plan.png')).assertTrue();
      const resultScroll = await driver.findComponent(ON.type('Scroll'));
      await resultScroll.scrollToBottom();
      const confirm = await driver.waitForComponent(ON.text('确认并锁定方案'), 5000);
      await confirm.click();
      expect(await driver.waitForComponent(ON.text('已锁定方案'), 15000)).not().assertNull();
      await driver.delayMs(500);
      expect(await driver.screenCap(context.filesDir + '/meetagent-locked.png')).assertTrue();
    });
  });
}
