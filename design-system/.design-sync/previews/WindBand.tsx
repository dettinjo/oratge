import { WindBand } from '@oratge/ui';

const mean = Array.from({ length: 72 }, (_, i) => { const h = i % 24, base = [9, 11, 15][Math.floor(i / 24)];
  return Math.round(Math.max(3, base + 7 * Math.exp(-(((h - 14.5) / 2.6) ** 2)) + 2 * Math.sin(i / 3.1) - (h < 8 ? 3 : 0)) * 10) / 10; });
const gust = mean.map((m, i) => Math.round((m * 1.28 + 2 + 1.5 * Math.sin(i / 2.3)) * 10) / 10);
const dirs = mean.map((_, i) => { const h = i % 24; return h > 11 && h < 21 ? 225 : h < 9 ? 330 : 280; });

export const ThreeDays = () => <WindBand mean={mean} gust={gust} directions={dirs} range={[14, 24]} days={['Mon', 'Tue', 'Wed']} night={[[0, 7.5], [17.6, 31.5], [41.6, 55.5], [65.6, 71]]} best={[37, 41]} />;
export const OneDayNoRange = () => <WindBand mean={mean.slice(24, 48)} gust={gust.slice(24, 48)} directions={dirs.slice(24, 48)} days={['Tue']} night={[[0, 7.5], [17.6, 23]]} />;
