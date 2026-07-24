/**
 * Clipboard share for locked plans.
 *
 * Device API: @kit.BasicServicesKit pasteboard
 *   pasteboard.getSystemPasteboard()
 *   pasteboard.createData(MIMETYPE_TEXT_PLAIN, text)
 *   systemPasteboard.setData(data)
 *
 * This is the official HarmonyOS system clipboard (works on physical phone /
 * emulator). DevEco Preview on Mac often does not mirror guest clipboard to
 * the host Mac pasteboard — toast can succeed while Cmd+V on Mac fails.
 * Verify with Run on device: paste into Notes / Messages inside the phone.
 */

import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { formatShareText } from '../agent/OfflineReply';
import { RecommendationSet, TripSession } from '../../domain/Models';
import { planIdFromSelected, resolveLockedPlan, LockedPlanSnapshot } from './SessionLogic';

export class ShareService {
  /** Last text successfully written (in-process; not a second clipboard). */
  static lastCopiedText: string = '';

  static buildShareTextFromSession(session: TripSession): string {
    const planId: string = planIdFromSelected(session.selected);
    return formatShareText(session.recommendationSet, planId);
  }

  static buildShareTextFromRec(rec: RecommendationSet, planId: string): string {
    return formatShareText(rec, planId);
  }

  /**
   * Write plain text to the device system clipboard via pasteboard.setData.
   */
  static async copyText(text: string, toastOk: string = '已复制到剪贴板'): Promise<boolean> {
    if (text.length === 0) {
      promptAction.showToast({ message: '无可分享内容', duration: 1800 });
      return false;
    }
    try {
      const sys: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      // Device system clipboard (pasteboard kit).
      await sys.setData(data);
      ShareService.lastCopiedText = text;
      promptAction.showToast({
        message: toastOk,
        duration: 1800
      });
      return true;
    } catch (e) {
      const errObj: Object = e as Object;
      promptAction.showToast({
        message: `复制失败：${errObj}`,
        duration: 2200
      });
      return false;
    }
  }

  static async shareLockedSession(session: TripSession): Promise<boolean> {
    const text: string = ShareService.buildShareTextFromSession(session);
    return ShareService.copyText(text);
  }

  static meetingLabel(session: TripSession): string {
    const snap: LockedPlanSnapshot = resolveLockedPlan(session);
    if (snap.meetingPoint.name.length > 0) {
      return snap.meetingPoint.name;
    }
    return '会合点';
  }
}
