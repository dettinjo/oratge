import { ForecastDayRow, type WeatherKind } from '@oratge/ui';

const week: [string, WeatherKind, number, number, number][] = [['Today', 'partly', 0, 11, 21], ['Tue', 'storm', 60, 13, 19], ['Wed', 'rain', 80, 12, 16], ['Thu', 'partly', 20, 10, 17], ['Fri', 'sun', 0, 9, 18], ['Sat', 'sun', 0, 10, 19], ['Sun', 'cloud', 10, 11, 18]];
export const SevenDays = () => <div style={{ width: 350 }}>{week.map(([d, s, p, a, b]) => <ForecastDayRow key={d} day={d} sky={s} rainChance={p} min={a} max={b} scale={[8, 22]} />)}</div>;
