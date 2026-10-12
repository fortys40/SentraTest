import type { PlayerCardExample } from '@/models';

import { PlayerCardView } from './PlayerCard/PlayerCardView';

/** Compatibility wrapper so dashboard callers do not depend on the card's options. */
export function PlayerCardShell({ example }: { example: PlayerCardExample }) {
  return <PlayerCardView example={example} motion="preview" />;
}
