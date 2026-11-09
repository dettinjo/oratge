import { ratingColor } from '../tokens';

export interface DayTab {
  /** Short weekday, e.g. "Tue". */
  weekday: string;
  /** Day of month, e.g. 10. */
  date: number | string;
  /** Best rating that day for the current sport (colours the tick). */
  rating: number;
  /** Daily-only outlook day (beyond the 3 hourly days) — shown faded. */
  outlook?: boolean;
}

export interface DayTabsProps {
  days: DayTab[];
  /** Index of the selected day. */
  selected: number;
  onSelect?: (index: number) => void;
}

/** Day picker for daily planners. Each tab carries a rating tick so the best day is visible at a glance. */
export function DayTabs({ days, selected, onSelect }: DayTabsProps) {
  return (
    <div className="og-tabs" role="tablist">
      {days.map((d, i) => (
        <div key={i} role="tab" aria-selected={i === selected} onClick={() => onSelect?.(i)}
          className={'og-tab' + (i === selected ? ' og-on' : '') + (d.outlook ? ' og-outlook' : '')}>
          <span>{d.weekday}</span><b>{d.date}</b><i style={{ background: ratingColor(d.rating) }} />
        </div>
      ))}
    </div>
  );
}
