import { VerdictCard } from '@oratge/ui';

export const Wing = () => <div style={{ width: 350 }}><VerdictCard rating={4} best="Best 13–17 h · peak 14–16 h" confidence="High confidence" summary="Side-on SW building to 16–19 kn, gusts ≤ 24. Chop rising to 0.8 m. Morning offshore NW, so stay ashore before 10 h." /></div>;
export const Bike = () => <div style={{ width: 350 }}><VerdictCard rating={5} best="Leave 09:00 → back 12:00" confidence="High confidence" summary="Dry window before the 13 h showers. NW tailwind on the climb, roads dry from 09 h." /></div>;
export const Hike = () => <div style={{ width: 350 }}><VerdictCard rating={2} best="Start 07:30 · turn back by 12:00" confidence="Medium confidence" summary="Clear, cold morning, −1° and NW 22 kn on the summit. 45 % storm risk at 14 h." /></div>;
