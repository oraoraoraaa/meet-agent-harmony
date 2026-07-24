/**
 * Tool registry + handlers for MeetAgent agent loop.
 * Only registered names may execute (prompt-injection safe).
 *
 * ArkTS: no untyped object literals — use DTO interfaces or raw JSON strings.
 */

import {
  Constraints,
  GeoPoint,
  MODE_BICYCLE,
  MODE_TRANSIT,
  MODE_WALKING,
  MobilityMode,
  RecommendationSet,
  Scenario
} from '../../domain/Models';
import { MapProvider, PlanningService } from '../map/MapProvider';
import { AgentSessionState, ToolTraceEntry } from './AgentTypes';
import { formatShareText } from './OfflineReply';
import { isGroundedPlanId } from './Grounding';

export const TOOL_GET_SCENARIO_SNAPSHOT: string = 'get_scenario_snapshot';
export const TOOL_SET_CONSTRAINTS: string = 'set_constraints';
export const TOOL_GET_DRIVING_ROUTE: string = 'get_driving_route';
export const TOOL_GENERATE_AND_SCORE: string = 'generate_and_score_plans';
export const TOOL_REVERSE_GEOCODE: string = 'reverse_geocode';
export const TOOL_SEARCH_POI_NEAR: string = 'search_poi_near';
export const TOOL_FORMAT_SHARE_TEXT: string = 'format_share_text';

/** Prebuilt OpenAI tools array JSON (avoids nested untyped schema literals). */
const OPENAI_TOOLS_JSON: string =
  '[' +
  '{"type":"function","function":{"name":"get_scenario_snapshot","description":"Return current driver/passenger points, city, and constraints from the UI session.","parameters":{"type":"object","properties":{},"additionalProperties":false}}},' +
  '{"type":"function","function":{"name":"set_constraints","description":"Update structured constraints (allowed modes, walk/bike caps, avoidTransit, notes). Re-run generate_and_score_plans after changes.","parameters":{"type":"object","properties":{"allowedModes":{"type":"array","items":{"type":"string","enum":["walking","bicycle","transit"]}},"maxPassengerWalkMin":{"type":"number"},"maxPassengerBikeMin":{"type":"number"},"avoidTransit":{"type":"boolean"},"notes":{"type":"string"}},"additionalProperties":false}}},' +
  '{"type":"function","function":{"name":"get_driving_route","description":"Fetch driver driving route polyline + cumulative times from current driver to passenger.","parameters":{"type":"object","properties":{},"additionalProperties":false}}},' +
  '{"type":"function","function":{"name":"generate_and_score_plans","description":"Run the local interception engine. Authoritative ranking. Returns plan IDs stayPut and suggestion:N with ETAs.","parameters":{"type":"object","properties":{},"additionalProperties":false}}},' +
  '{"type":"function","function":{"name":"reverse_geocode","description":"Best-effort place label for lon/lat.","parameters":{"type":"object","properties":{"lon":{"type":"number"},"lat":{"type":"number"}},"required":["lon","lat"],"additionalProperties":false}}},' +
  '{"type":"function","function":{"name":"search_poi_near","description":"Best-effort nearby POI search for semantic meeting labels.","parameters":{"type":"object","properties":{"lon":{"type":"number"},"lat":{"type":"number"},"keyword":{"type":"string"}},"required":["lon","lat"],"additionalProperties":false}}},' +
  '{"type":"function","function":{"name":"format_share_text","description":"Build clipboard-ready zh-CN share text for a grounded plan id (stayPut or suggestion:N).","parameters":{"type":"object","properties":{"planId":{"type":"string"}},"required":["planId"],"additionalProperties":false}}}' +
  ']';

export function buildOpenAiToolsJsonString(): string {
  return OPENAI_TOOLS_JSON;
}

// ---- DTOs for stringify (explicit interfaces satisfy arkts-no-untyped-obj-literals) ----

interface NamedPointDto {
  lon: number;
  lat: number;
  name: string;
}

interface ConstraintsDto {
  allowedModes: string[];
  maxPassengerWalkMin: number;
  maxPassengerBikeMin: number;
  avoidTransit: boolean;
  notes: string;
}

interface SnapshotDto {
  city: string;
  driver: NamedPointDto;
  passenger: NamedPointDto;
  constraints: ConstraintsDto;
}

interface SetConstraintsResultDto {
  ok: boolean;
  constraints: ConstraintsDto;
}

interface RouteVertexDto {
  lon: number;
  lat: number;
  driverSecs: number;
  metersFromStart: number;
}

interface DrivingRouteDto {
  dataSource: string;
  driverEtaMin: number;
  vertexCount: number;
  sampleVertices: RouteVertexDto[];
}

interface SuggestionDto {
  planId: string;
  mode: string;
  recommended: boolean;
  driverEtaMin: number;
  passengerEtaMin: number;
  completionMin: number;
  driverSavedMin: number;
  score: number;
  rationale: string;
  meetingPoint: NamedPointDto;
}

interface StayPutDto {
  planId: string;
  recommended: boolean;
  driverEtaMin: number;
  completionMin: number;
  rationale: string;
  meetingPoint: NamedPointDto;
}

interface GenerateScoreDto {
  generatedAt: string;
  dataSource: string;
  stayPut: StayPutDto;
  suggestions: SuggestionDto[];
}

interface ReverseGeocodeDto {
  lon: number;
  lat: number;
  label: string;
}

interface SearchPoiDto {
  lon: number;
  lat: number;
  keyword: string;
  pois: string[];
}

interface ShareTextDto {
  planId: string;
  shareText: string;
}

interface ErrorDto {
  error: string;
}

export class ToolDispatchResult {
  contentJson: string = '{}';
  trace: ToolTraceEntry = new ToolTraceEntry();
}

/** Parsed tool arguments (class fields — no untyped maps). */
class ToolArgs {
  lon: number = 0;
  lat: number = 0;
  keyword: string = '';
  planId: string = '';
  maxPassengerWalkMin: number = -99999;
  maxPassengerBikeMin: number = -99999;
  avoidTransit: boolean = false;
  hasAvoidTransit: boolean = false;
  notes: string = '';
  hasNotes: boolean = false;
  allowedModes: string[] = [];
  hasAllowedModes: boolean = false;
}

function parseToolArgs(argumentsJson: string): ToolArgs {
  const out: ToolArgs = new ToolArgs();
  if (argumentsJson.length === 0) {
    return out;
  }
  try {
    const raw: Object = JSON.parse(argumentsJson) as Object;
    if (raw === null || typeof raw !== 'object') {
      return out;
    }
    const bag: Record<string, Object> = raw as Record<string, Object>;

    const lonVal: Object | undefined = bag['lon'];
    if (typeof lonVal === 'number') {
      out.lon = lonVal as number;
    } else if (typeof lonVal === 'string') {
      const n: number = Number(lonVal as string);
      if (!isNaN(n)) {
        out.lon = n;
      }
    }

    const latVal: Object | undefined = bag['lat'];
    if (typeof latVal === 'number') {
      out.lat = latVal as number;
    } else if (typeof latVal === 'string') {
      const n: number = Number(latVal as string);
      if (!isNaN(n)) {
        out.lat = n;
      }
    }

    const kw: Object | undefined = bag['keyword'];
    if (typeof kw === 'string') {
      out.keyword = kw as string;
    }

    const pid: Object | undefined = bag['planId'];
    if (typeof pid === 'string') {
      out.planId = pid as string;
    }

    const walk: Object | undefined = bag['maxPassengerWalkMin'];
    if (typeof walk === 'number') {
      out.maxPassengerWalkMin = walk as number;
    }

    const bike: Object | undefined = bag['maxPassengerBikeMin'];
    if (typeof bike === 'number') {
      out.maxPassengerBikeMin = bike as number;
    }

    const avoid: Object | undefined = bag['avoidTransit'];
    if (typeof avoid === 'boolean') {
      out.avoidTransit = avoid as boolean;
      out.hasAvoidTransit = true;
    }

    const notes: Object | undefined = bag['notes'];
    if (typeof notes === 'string') {
      out.notes = notes as string;
      out.hasNotes = true;
    }

    const modesVal: Object | undefined = bag['allowedModes'];
    if (modesVal instanceof Array) {
      const arr: Object[] = modesVal as Object[];
      const modes: string[] = [];
      for (let i = 0; i < arr.length; i++) {
        if (typeof arr[i] === 'string') {
          modes.push(arr[i] as string);
        }
      }
      out.allowedModes = modes;
      out.hasAllowedModes = true;
    }
  } catch (e) {
    const _ignored: Object = e as Object;
  }
  return out;
}

function modeFromString(raw: string): MobilityMode {
  if (raw === MODE_WALKING || raw === 'walking') {
    return MODE_WALKING;
  }
  if (raw === MODE_BICYCLE || raw === 'bicycle') {
    return MODE_BICYCLE;
  }
  if (raw === MODE_TRANSIT || raw === 'transit') {
    return MODE_TRANSIT;
  }
  return '';
}

function errorJson(error: string, name: string = '', hint: string = '', planId: string = ''): string {
  // Build string directly to avoid optional/undefined fields in object literals.
  let s: string = '{"error":"' + escapeJson(error) + '"';
  if (name.length > 0) {
    s += ',"name":"' + escapeJson(name) + '"';
  }
  if (hint.length > 0) {
    s += ',"hint":"' + escapeJson(hint) + '"';
  }
  if (planId.length > 0) {
    s += ',"planId":"' + escapeJson(planId) + '"';
  }
  s += '}';
  return s;
}

function escapeJson(raw: string): string {
  let out: string = '';
  for (let i = 0; i < raw.length; i++) {
    const ch: string = raw.charAt(i);
    if (ch === '\\') {
      out += '\\\\';
    } else if (ch === '"') {
      out += '\\"';
    } else if (ch === '\n') {
      out += '\\n';
    } else if (ch === '\r') {
      out += '\\r';
    } else {
      out += ch;
    }
  }
  return out;
}

export class AgentToolHost {
  private session: AgentSessionState;
  private provider: MapProvider;

  constructor(session: AgentSessionState, provider: MapProvider) {
    this.session = session;
    this.provider = provider;
  }

  getSession(): AgentSessionState {
    return this.session;
  }

  isRegistered(name: string): boolean {
    return name === TOOL_GET_SCENARIO_SNAPSHOT ||
      name === TOOL_SET_CONSTRAINTS ||
      name === TOOL_GET_DRIVING_ROUTE ||
      name === TOOL_GENERATE_AND_SCORE ||
      name === TOOL_REVERSE_GEOCODE ||
      name === TOOL_SEARCH_POI_NEAR ||
      name === TOOL_FORMAT_SHARE_TEXT;
  }

  async dispatch(name: string, argumentsJson: string): Promise<ToolDispatchResult> {
    const out: ToolDispatchResult = new ToolDispatchResult();
    out.trace.name = name;
    const t0: number = Date.now();

    if (!this.isRegistered(name)) {
      out.trace.ok = false;
      out.trace.durationMs = Date.now() - t0;
      out.trace.summary = 'unknown tool';
      out.trace.error = 'tool not in registry';
      out.contentJson = errorJson('unknown_tool', name);
      return out;
    }

    try {
      if (name === TOOL_GET_SCENARIO_SNAPSHOT) {
        out.contentJson = this.snapshotJson();
        out.trace.ok = true;
        out.trace.summary = 'scenario snapshot';
      } else if (name === TOOL_SET_CONSTRAINTS) {
        out.contentJson = this.setConstraints(parseToolArgs(argumentsJson));
        out.trace.ok = true;
        out.trace.summary = 'constraints updated';
      } else if (name === TOOL_GET_DRIVING_ROUTE) {
        out.contentJson = await this.getDrivingRoute();
        out.trace.ok = true;
        out.trace.summary = 'driving route';
      } else if (name === TOOL_GENERATE_AND_SCORE) {
        out.contentJson = await this.generateAndScore();
        out.trace.ok = true;
        const rec: RecommendationSet | null = this.session.lastRecommendation;
        const n: number = rec !== null ? rec.suggestions.length : 0;
        out.trace.summary = `plans stayPut+${n}`;
      } else if (name === TOOL_REVERSE_GEOCODE) {
        out.contentJson = await this.reverseGeocode(parseToolArgs(argumentsJson));
        out.trace.ok = true;
        out.trace.summary = 'reverse geocode';
      } else if (name === TOOL_SEARCH_POI_NEAR) {
        out.contentJson = await this.searchPoi(parseToolArgs(argumentsJson));
        out.trace.ok = true;
        out.trace.summary = 'poi search';
      } else if (name === TOOL_FORMAT_SHARE_TEXT) {
        out.contentJson = this.formatShare(parseToolArgs(argumentsJson));
        out.trace.ok = true;
        out.trace.summary = 'share text';
      } else {
        out.contentJson = errorJson('unhandled');
        out.trace.ok = false;
        out.trace.error = 'unhandled';
      }
    } catch (e) {
      const errObj: Object = e as Object;
      out.trace.ok = false;
      out.trace.error = `${errObj}`;
      out.trace.summary = 'tool error';
      out.contentJson = errorJson(`${errObj}`);
    }

    out.trace.durationMs = Date.now() - t0;
    return out;
  }

  private snapshotJson(): string {
    const s: Scenario = this.session.scenario;
    const driver: NamedPointDto = {
      lon: s.driver.lon,
      lat: s.driver.lat,
      name: s.driver.name
    };
    const passenger: NamedPointDto = {
      lon: s.passenger.lon,
      lat: s.passenger.lat,
      name: s.passenger.name
    };
    const constraints: ConstraintsDto = {
      allowedModes: s.constraints.allowedModes,
      maxPassengerWalkMin: s.constraints.maxPassengerWalkMin,
      maxPassengerBikeMin: s.constraints.maxPassengerBikeMin,
      avoidTransit: s.constraints.avoidTransit,
      notes: s.constraints.notes
    };
    const payload: SnapshotDto = {
      city: s.city,
      driver: driver,
      passenger: passenger,
      constraints: constraints
    };
    return JSON.stringify(payload);
  }

  private setConstraints(args: ToolArgs): string {
    const c: Constraints = this.session.scenario.constraints;
    if (args.hasAllowedModes) {
      const modes: MobilityMode[] = [];
      for (let i = 0; i < args.allowedModes.length; i++) {
        const m: MobilityMode = modeFromString(args.allowedModes[i]);
        if (m.length > 0) {
          modes.push(m);
        }
      }
      if (modes.length > 0) {
        c.allowedModes = modes;
      }
    }
    if (args.maxPassengerWalkMin !== -99999) {
      c.maxPassengerWalkMin = args.maxPassengerWalkMin;
    }
    if (args.maxPassengerBikeMin !== -99999) {
      c.maxPassengerBikeMin = args.maxPassengerBikeMin;
    }
    if (args.hasAvoidTransit) {
      c.avoidTransit = args.avoidTransit;
      if (c.avoidTransit) {
        const filtered: MobilityMode[] = [];
        for (let i = 0; i < c.allowedModes.length; i++) {
          if (c.allowedModes[i] !== MODE_TRANSIT) {
            filtered.push(c.allowedModes[i]);
          }
        }
        if (filtered.length > 0) {
          c.allowedModes = filtered;
        }
      }
    }
    if (args.hasNotes) {
      c.notes = args.notes;
    }
    const constraints: ConstraintsDto = {
      allowedModes: c.allowedModes,
      maxPassengerWalkMin: c.maxPassengerWalkMin,
      maxPassengerBikeMin: c.maxPassengerBikeMin,
      avoidTransit: c.avoidTransit,
      notes: c.notes
    };
    const result: SetConstraintsResultDto = {
      ok: true,
      constraints: constraints
    };
    return JSON.stringify(result);
  }

  private async getDrivingRoute(): Promise<string> {
    const s: Scenario = this.session.scenario;
    const from: GeoPoint = s.driver.toGeo();
    const to: GeoPoint = s.passenger.toGeo();
    const route = await this.provider.getDrivingRoute(from, to);
    const verts: RouteVertexDto[] = [];
    const maxPts: number = Math.min(route.route.length, 12);
    for (let i = 0; i < maxPts; i++) {
      const v: RouteVertexDto = {
        lon: route.route[i].point.lon,
        lat: route.route[i].point.lat,
        driverSecs: route.route[i].driverSecs,
        metersFromStart: route.route[i].metersFromStart
      };
      verts.push(v);
    }
    let totalMin: number = 0;
    if (route.route.length > 0) {
      totalMin = route.route[route.route.length - 1].driverSecs / 60;
    }
    const dto: DrivingRouteDto = {
      dataSource: route.dataSource,
      driverEtaMin: totalMin,
      vertexCount: route.route.length,
      sampleVertices: verts
    };
    return JSON.stringify(dto);
  }

  private async generateAndScore(): Promise<string> {
    const rec: RecommendationSet = await PlanningService.plan(this.session.scenario, this.provider);
    this.session.lastRecommendation = rec;
    const suggestions: SuggestionDto[] = [];
    for (let i = 0; i < rec.suggestions.length; i++) {
      const s = rec.suggestions[i];
      const meet: NamedPointDto = {
        lon: s.meetingPoint.lon,
        lat: s.meetingPoint.lat,
        name: s.meetingPoint.name
      };
      const item: SuggestionDto = {
        planId: `suggestion:${i}`,
        mode: s.mode,
        recommended: s.recommended,
        driverEtaMin: s.driverEtaMin,
        passengerEtaMin: s.passengerEtaMin,
        completionMin: s.completionMin,
        driverSavedMin: s.driverSavedMin,
        score: s.score,
        rationale: s.rationale,
        meetingPoint: meet
      };
      suggestions.push(item);
    }
    const stayMeet: NamedPointDto = {
      lon: rec.stayPut.meetingPoint.lon,
      lat: rec.stayPut.meetingPoint.lat,
      name: rec.stayPut.meetingPoint.name
    };
    const stay: StayPutDto = {
      planId: 'stayPut',
      recommended: rec.stayPut.recommended,
      driverEtaMin: rec.stayPut.driverEtaMin,
      completionMin: rec.stayPut.completionMin,
      rationale: rec.stayPut.rationale,
      meetingPoint: stayMeet
    };
    const dto: GenerateScoreDto = {
      generatedAt: rec.generatedAt,
      dataSource: rec.dataSource,
      stayPut: stay,
      suggestions: suggestions
    };
    return JSON.stringify(dto);
  }

  private async reverseGeocode(args: ToolArgs): Promise<string> {
    const label: string = await this.provider.reverseGeocode(new GeoPoint(args.lon, args.lat));
    const dto: ReverseGeocodeDto = {
      lon: args.lon,
      lat: args.lat,
      label: label
    };
    return JSON.stringify(dto);
  }

  private async searchPoi(args: ToolArgs): Promise<string> {
    const list: string[] = await this.provider.searchPoi(args.keyword, args.lon, args.lat, true);
    const dto: SearchPoiDto = {
      lon: args.lon,
      lat: args.lat,
      keyword: args.keyword,
      pois: list
    };
    return JSON.stringify(dto);
  }

  private formatShare(args: ToolArgs): string {
    const planId: string = args.planId.length > 0 ? args.planId : 'stayPut';
    const rec: RecommendationSet | null = this.session.lastRecommendation;
    if (rec === null) {
      return errorJson('no_recommendation', '', 'call generate_and_score_plans first');
    }
    if (!isGroundedPlanId(planId, rec)) {
      return errorJson('ungrounded_plan_id', '', '', planId);
    }
    const text: string = formatShareText(rec, planId);
    const dto: ShareTextDto = {
      planId: planId,
      shareText: text
    };
    return JSON.stringify(dto);
  }
}
