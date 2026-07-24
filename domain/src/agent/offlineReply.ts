/**
 * Mode C template explanations (no LLM).
 */

import type { RecommendationSet, Suggestion } from '../models.ts';
import { resolveGroundedSelection, stayPutPlanId, suggestionPlanId } from './grounding.ts';

function modeZh(mode: string): string {
  if (mode === 'walking') return '步行';
  if (mode === 'bicycle') return '骑行';
  if (mode === 'transit') return '公交';
  return mode;
}

function dataSourceZh(source: string): string {
  if (source === 'live') return '实时';
  if (source === 'live_with_fallback') return '实时+估算';
  return '估算';
}

export function buildOfflinePlanReply(rec: RecommendationSet): string {
  const selected = resolveGroundedSelection('', rec);
  const lines: string[] = [];
  lines.push(`已用本地引擎完成会合规划（${dataSourceZh(rec.dataSource)}模式，未调用大模型）。`);
  lines.push('');

  const stay = rec.stayPut;
  lines.push(
    `· 原地等待 [stayPut]：司机约 ${stay.driverEtaMin.toFixed(0)} 分钟到达乘客位置` +
      (stay.recommended ? '  ← 推荐' : ''),
  );

  for (let i = 0; i < rec.suggestions.length; i++) {
    const s: Suggestion = rec.suggestions[i];
    const id = suggestionPlanId(i);
    const mark = s.recommended ? '  ← 推荐' : '';
    lines.push(
      `· ${modeZh(s.mode)} [${id}]：乘客约 ${s.passengerEtaMin.toFixed(0)} 分钟，司机约 ${s.driverEtaMin.toFixed(0)} 分钟，会合约 ${s.completionMin.toFixed(0)} 分钟` +
        (s.driverSavedMin > 0.4 ? `，司机省约 ${s.driverSavedMin.toFixed(0)} 分钟` : '') +
        mark,
    );
  }

  lines.push('');
  if (selected === stayPutPlanId()) {
    lines.push(stay.rationale);
    lines.push(`推荐方案 ID：${selected}`);
  } else {
    const idx = Number(selected.slice('suggestion:'.length));
    const s = rec.suggestions[idx];
    if (s) {
      lines.push(s.rationale);
    }
    lines.push(`推荐方案 ID：${selected}`);
  }

  lines.push('');
  lines.push('可在设置中配置大模型 Key 以启用自然语言约束解析与解释。');
  return lines.join('\n');
}

export function formatShareText(
  rec: RecommendationSet,
  planId: string,
): string {
  const selected = resolveGroundedSelection(planId, rec);
  if (selected === stayPutPlanId()) {
    const stay = rec.stayPut;
    const meet = stay.meetingPoint.name || '乘客当前位置';
    return [
      '【会合助手】会合方案',
      `模式：乘客原地等待`,
      `会合点：${meet}`,
      `坐标：${stay.meetingPoint.lon.toFixed(5)}, ${stay.meetingPoint.lat.toFixed(5)}`,
      `司机 ETA：约 ${stay.driverEtaMin.toFixed(0)} 分钟`,
      `说明：${stay.rationale}`,
      `数据：${dataSourceZh(rec.dataSource)}`,
    ].join('\n');
  }
  const idx = Number(selected.slice('suggestion:'.length));
  const s = rec.suggestions[idx];
  if (!s) {
    return formatShareText(rec, stayPutPlanId());
  }
  const meet = s.meetingPoint.name || '会合点';
  return [
    '【会合助手】会合方案',
    `乘客方式：${modeZh(s.mode)}`,
    `会合点：${meet}`,
    `坐标：${s.meetingPoint.lon.toFixed(5)}, ${s.meetingPoint.lat.toFixed(5)}`,
    `司机 ETA：约 ${s.driverEtaMin.toFixed(0)} 分钟`,
    `乘客 ETA：约 ${s.passengerEtaMin.toFixed(0)} 分钟`,
    `会合完成：约 ${s.completionMin.toFixed(0)} 分钟`,
    `说明：${s.rationale}`,
    `数据：${dataSourceZh(rec.dataSource)}`,
  ].join('\n');
}
