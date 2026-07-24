/**
 * Strip model markdown so chat bubbles stay plain text (no table pipes / **).
 * Engine numbers still live on plan cards.
 */

export function formatReplyForBubble(raw: string): string {
  if (raw.length === 0) {
    return raw;
  }
  const lines: string[] = raw.split('\n');
  const out: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    let line: string = lines[i];
    const trimmed: string = line.trim();

    if (isMarkdownTableLine(trimmed)) {
      continue;
    }
    if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
      continue;
    }

    line = line.replace(/^\s*#{1,6}\s+/, '');
    line = stripAll(line, '**');
    line = stripAll(line, '__');
    line = stripAll(line, '`');
    line = line.replace(/\*([^*\n]+)\*/g, '$1');
    line = line.replace(/[ \t]{2,}/g, ' ');
    out.push(line);
  }

  const collapsed: string[] = [];
  let blankRun: number = 0;
  for (let i = 0; i < out.length; i++) {
    const t: string = out[i].trim();
    if (t.length === 0) {
      blankRun += 1;
      if (blankRun <= 1) {
        collapsed.push('');
      }
    } else {
      blankRun = 0;
      collapsed.push(out[i].trimEnd());
    }
  }

  const cleaned: string[] = [];
  for (let i = 0; i < collapsed.length; i++) {
    const t: string = collapsed[i].trim();
    if (t.indexOf('PLAN_ID:') === 0 || t.indexOf('plan_id:') === 0) {
      continue;
    }
    cleaned.push(softBreakLongTokens(collapsed[i]));
  }
  return cleaned.join('\n').trim();
}

/** Insert soft breaks so long Latin tokens wrap in ArkUI Text. */
function softBreakLongTokens(line: string): string {
  let out: string = '';
  let runLen: number = 0;
  for (let i = 0; i < line.length; i++) {
    const ch: string = line.charAt(i);
    const code: number = line.charCodeAt(i);
    const isCjk: boolean = code >= 0x4E00 && code <= 0x9FFF;
    const isSpace: boolean = ch === ' ' || ch === '\t' || ch === '\n';
    if (isSpace || isCjk) {
      out += ch;
      runLen = 0;
    } else {
      out += ch;
      runLen += 1;
      if (runLen >= 14) {
        out += ' ';
        runLen = 0;
      }
    }
  }
  return out;
}

function isMarkdownTableLine(trimmed: string): boolean {
  if (trimmed.length === 0) {
    return false;
  }
  if (trimmed.charAt(0) === '|') {
    return true;
  }
  // separator like |---|---|
  if (trimmed.indexOf('|') >= 0 && trimmed.indexOf('-') >= 0) {
    let onlyTableChars: boolean = true;
    for (let i = 0; i < trimmed.length; i++) {
      const ch: string = trimmed.charAt(i);
      if (ch !== '|' && ch !== '-' && ch !== ':' && ch !== ' ') {
        onlyTableChars = false;
        break;
      }
    }
    if (onlyTableChars) {
      return true;
    }
  }
  // body row with 2+ pipes
  let pipes: number = 0;
  for (let i = 0; i < trimmed.length; i++) {
    if (trimmed.charAt(i) === '|') {
      pipes += 1;
    }
  }
  return pipes >= 2;
}

function stripAll(s: string, token: string): string {
  let out: string = s;
  let idx: number = out.indexOf(token);
  while (idx >= 0) {
    out = out.substring(0, idx) + out.substring(idx + token.length);
    idx = out.indexOf(token);
  }
  return out;
}
