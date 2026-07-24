/**
 * Clipboard share for locked plans.
 */

import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { formatShareText } from '../agent/OfflineReply';
import { RecommendationSet, TripSession } from '../../domain/Models';
import { planIdFromSelected, resolveLockedPlan, LockedPlanSnapshot } from './SessionLogic';

export class ShareService {
  static buildShareTextFromSession(session: TripSession): string {
    const planId: string = planIdFromSelected(session.selected);
    return formatShareText(session.recommendationSet, planId);
  }

  static buildShareTextFromRec(rec: RecommendationSet, planId: string): string {
    return formatShareText(rec, planId);
  }

  static async copyText(text: string, toastOk: string = '已复制分享文案'): Promise<boolean> {
    if (text.length === 0) {
      promptAction.showToast({ message: '无可分享内容', duration: 1800 });
      return false;
    }
    try {
      const sys: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await sys.setData(data);
      promptAction.showToast({ message: toastOk, duration: 1800 });
      return true;
    } catch (e) {
      const _ignored: Object = e as Object;
      promptAction.showToast({ message: '复制失败', duration: 1800 });
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
