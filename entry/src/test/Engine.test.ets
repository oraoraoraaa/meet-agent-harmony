import { describe, it, expect } from '@ohos/hypium';
import { reachableModes, scoreOption } from '../main/ets/domain/Engine';
import { MODE_WALKING, MODE_BICYCLE, MODE_TRANSIT } from '../main/ets/domain/Models';

export default function engineTest(): void {
  describe('ArkTS engine port', () => {
    it('longer passenger travel never improves the score', 0, () => {
      expect(scoreOption(10, 12, MODE_WALKING) > scoreOption(10, 5, MODE_WALKING)).assertTrue();
    });
    it('short trips exclude transit and long trips exclude walking', 0, () => {
      expect(reachableModes(500).indexOf(MODE_TRANSIT)).assertEqual(-1);
      expect(reachableModes(2000).indexOf(MODE_WALKING)).assertEqual(-1);
      expect(reachableModes(2000).indexOf(MODE_BICYCLE) >= 0).assertTrue();
    });
  });
}
