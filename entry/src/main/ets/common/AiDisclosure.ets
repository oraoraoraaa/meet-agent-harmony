/** Disclosure belongs to the client, never to model-controlled wording. */
export const AI_CONTENT_LABEL: string = '人工智能生成内容';
export const AI_CONTENT_NOTICE: string = '启用 AI 时，回复含人工智能生成内容，仅供参考，请核实。复制时将保留标识，请勿删除或篡改。';

export function labeledAiCopy(text: string): string {
  return `【${AI_CONTENT_LABEL} · MeetAgent接驾优化】\n${text}\n请核实生成内容，转发时请保留本标识。`;
}
