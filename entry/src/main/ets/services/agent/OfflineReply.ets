/**
 * Offline template reply + share text (ArkTS mirror of domain offlineReply).
 */

import {
  dataSourceLabelZh,
  modeLabelZh,
  RecommendationSet,
  StayPutSuggestion,
  Suggestion
} from '../../domain/Models';
import { resolveGroundedSelection, stayPutPlanId, suggestionPlanId } from './Grounding';

export function buildOfflinePlanReply(rec: RecommendationSet): string {
  const selected: string = resolveGroundedSelection('', rec);
  const lines: string[] = [];
  lines.push(`已用本地引擎完成会合规划（${dataSourceLabelZh(rec.dataSource)}模式，未调用大模型）。`);
  lines.push('');

  const stay: StayPutSuggestion = rec.stayPut;
  lines.push(
    `· 原地等待 [stayPut]：司机约 ${stay.driverEtaMin.toFixed(0)} 分钟到达乘客位置` +
      (stay.recommended ? '  ← 推荐' : '')
  );

  for (let i = 0; i < rec.suggestions.length; i++) {
    const s: Suggestion = rec.suggestions[i];
    const id: string = suggestionPlanId(i);
    const mark: string = s.recommended ? '  ← 推荐' : '';
    let save: string = '';
    if (s.driverSavedMin > 0.4) {
      save = `，司机省约 ${s.driverSavedMin.toFixed(0)} 分钟`;
    }
    lines.push(
      `· ${modeLabelZh(s.mode)} [${id}]：乘客约 ${s.passengerEtaMin.toFixed(0)} 分钟，` +
        `司机约 ${s.driverEtaMin.toFixed(0)} 分钟，会合约 ${s.completionMin.toFixed(0)} 分钟` +
        save +
        mark
    );
  }

  lines.push('');
  if (selected === stayPutPlanId()) {
    lines.push(stay.rationale);
    lines.push(`推荐方案 ID：${selected}`);
  } else {
    const idx: number = Number(selected.substring('suggestion:'.length));
    if (idx >= 0 && idx < rec.suggestions.length) {
      lines.push(rec.suggestions[idx].rationale);
    }
    lines.push(`推荐方案 ID：${selected}`);
  }

  lines.push('');
  lines.push('可在设置中配置大模型 Key 以启用自然语言约束解析与解释。');
  return lines.join('\n');
}

export function formatShareText(rec: RecommendationSet, planId: string): string {
  const selected: string = resolveGroundedSelection(planId, rec);
  if (selected === stayPutPlanId()) {
    const stay: StayPutSuggestion = rec.stayPut;
    const meet: string = stay.meetingPoint.name.length > 0 ? stay.meetingPoint.name : '乘客当前位置';
    return [
      '【会合助手】会合方案',
      '模式：乘客原地等待',
      `会合点：${meet}`,
      `坐标：${stay.meetingPoint.lon.toFixed(5)}, ${stay.meetingPoint.lat.toFixed(5)}`,
      `司机 ETA：约 ${stay.driverEtaMin.toFixed(0)} 分钟`,
      `说明：${stay.rationale}`,
      `数据：${dataSourceLabelZh(rec.dataSource)}`
    ].join('\n');
  }
  const idx: number = Number(selected.substring('suggestion:'.length));
  if (isNaN(idx) || idx < 0 || idx >= rec.suggestions.length) {
    return formatShareText(rec, stayPutPlanId());
  }
  const s: Suggestion = rec.suggestions[idx];
  const meet: string = s.meetingPoint.name.length > 0 ? s.meetingPoint.name : '会合点';
  return [
    '【会合助手】会合方案',
    `乘客方式：${modeLabelZh(s.mode)}`,
    `会合点：${meet}`,
    `坐标：${s.meetingPoint.lon.toFixed(5)}, ${s.meetingPoint.lat.toFixed(5)}`,
    `司机 ETA：约 ${s.driverEtaMin.toFixed(0)} 分钟`,
    `乘客 ETA：约 ${s.passengerEtaMin.toFixed(0)} 分钟`,
    `会合完成：约 ${s.completionMin.toFixed(0)} 分钟`,
    `说明：${s.rationale}`,
    `数据：${dataSourceLabelZh(rec.dataSource)}`
  ].join('\n');
}
