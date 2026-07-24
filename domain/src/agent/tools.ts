/** OpenAI-compatible tool catalog for MeetAgent v1. */

import type { ToolDefinition } from './types.ts';

export const TOOL_GET_SCENARIO_SNAPSHOT = 'get_scenario_snapshot';
export const TOOL_SET_CONSTRAINTS = 'set_constraints';
export const TOOL_GET_DRIVING_ROUTE = 'get_driving_route';
export const TOOL_GENERATE_AND_SCORE = 'generate_and_score_plans';
export const TOOL_REVERSE_GEOCODE = 'reverse_geocode';
export const TOOL_SEARCH_POI_NEAR = 'search_poi_near';
export const TOOL_FORMAT_SHARE_TEXT = 'format_share_text';

export const AGENT_TOOL_DEFINITIONS: readonly ToolDefinition[] = [
  {
    name: TOOL_GET_SCENARIO_SNAPSHOT,
    description: 'Return current driver/passenger points, city, and constraints from the UI session.',
    parameters: {
      type: 'object',
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: TOOL_SET_CONSTRAINTS,
    description:
      'Update structured constraints (allowed modes, walk/bike caps, avoidTransit, notes). Re-run generate_and_score_plans after changes.',
    parameters: {
      type: 'object',
      properties: {
        allowedModes: {
          type: 'array',
          items: { type: 'string', enum: ['walking', 'bicycle', 'transit'] },
        },
        maxPassengerWalkMin: { type: 'number' },
        maxPassengerBikeMin: { type: 'number' },
        avoidTransit: { type: 'boolean' },
        notes: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: TOOL_GET_DRIVING_ROUTE,
    description: 'Fetch driver driving route polyline + cumulative times from current driver to passenger.',
    parameters: {
      type: 'object',
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: TOOL_GENERATE_AND_SCORE,
    description:
      'Run the local interception engine. Authoritative ranking for stay-put vs walk/bike/transit suggestions. Returns plan IDs stayPut and suggestion:N.',
    parameters: {
      type: 'object',
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: TOOL_REVERSE_GEOCODE,
    description: 'Best-effort place label for lon/lat.',
    parameters: {
      type: 'object',
      properties: {
        lon: { type: 'number' },
        lat: { type: 'number' },
      },
      required: ['lon', 'lat'],
      additionalProperties: false,
    },
  },
  {
    name: TOOL_SEARCH_POI_NEAR,
    description: 'Best-effort nearby POI search for semantic meeting labels.',
    parameters: {
      type: 'object',
      properties: {
        lon: { type: 'number' },
        lat: { type: 'number' },
        keyword: { type: 'string' },
      },
      required: ['lon', 'lat'],
      additionalProperties: false,
    },
  },
  {
    name: TOOL_FORMAT_SHARE_TEXT,
    description: 'Build clipboard-ready zh-CN share text for a grounded plan id.',
    parameters: {
      type: 'object',
      properties: {
        planId: {
          type: 'string',
          description: 'stayPut or suggestion:N from last generate_and_score_plans',
        },
      },
      required: ['planId'],
      additionalProperties: false,
    },
  },
];

export function openAiToolsPayload(): unknown[] {
  return AGENT_TOOL_DEFINITIONS.map((t) => ({
    type: 'function',
    function: {
      name: t.name,
      description: t.description,
      parameters: t.parameters,
    },
  }));
}
