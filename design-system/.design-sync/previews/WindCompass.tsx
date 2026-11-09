import { WindCompass } from '@oratge/ui';

export const SideOnshore = () => <WindCompass from={225} speed={14} shoreFacing={170} caption="live · side-shore" />;
export const Offshore = () => <WindCompass from={330} speed={9} shoreFacing={170} caption="live · offshore — stay ashore" />;
