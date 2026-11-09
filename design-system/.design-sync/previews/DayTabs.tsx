import { DayTabs } from '@oratge/ui';

const days = [['Mon', 9, 3], ['Tue', 10, 4], ['Wed', 11, 2], ['Thu', 12, 1], ['Fri', 13, 1], ['Sat', 14, 3], ['Sun', 15, 4], ['Mon', 16, 2]].map(([w, d, r], i) => ({ weekday: w as string, date: d as number, rating: r as number, outlook: i > 2 }));
export const WeekTuesday = () => <div style={{ width: 350 }}><DayTabs days={days} selected={1} /></div>;
export const TodaySelected = () => <div style={{ width: 350 }}><DayTabs days={days} selected={0} /></div>;
