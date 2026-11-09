import { CalendarHeatmap } from '@oratge/ui';

let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const weeks = Array.from({ length: 26 }, (_, w) => Array.from({ length: 7 }, () => { const s = 0.5 + 0.5 * Math.sin(((w - 2) / 26) * Math.PI * 1.1); const v = rnd() * s * 1.6; return v < 0.35 ? 0 : Math.min(5, 1 + Math.floor((v - 0.35) * 4)); }));
export const RideableHours = () => <CalendarHeatmap weeks={weeks} months={['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']} legend={['0 h', '6+ h']} />;
