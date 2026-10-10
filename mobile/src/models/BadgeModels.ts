import {
  boolean,
  json,
  jsonObject,
  nullable,
  string,
  struct,
  timestamp,
  uuid,
  type CodecType,
} from '@/core/utilities/SentraJSON';

export const BadgeDefinitionCodec = struct({
  id: ['id', uuid],
  code: ['code', string],
  nameEL: ['name_el', string],
  emoji: ['emoji', string],
  descriptionEL: ['description_el', string],
  // The deployed column is `rule_params`, not the specification's `params`.
  ruleParams: ['rule_params', jsonObject],
  active: ['active', boolean],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type BadgeDefinition = CodecType<typeof BadgeDefinitionCodec>;

export const PlayerBadgeCodec = struct({
  id: ['id', uuid],
  userID: ['user_id', uuid],
  groupID: ['group_id', nullable(uuid)],
  badgeCode: ['badge_code', string],
  ruleSnapshot: ['rule_snapshot', json],
  awardedAt: ['awarded_at', timestamp],
});
export type PlayerBadge = CodecType<typeof PlayerBadgeCodec>;
