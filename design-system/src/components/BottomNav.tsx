export type NavTab = 'Today' | 'Activities' | 'Map' | 'Spots';
const paths: Record<NavTab, string> = {
  Today: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v3M12 19v3M2 12h3M19 12h3',
  Activities: 'M4 18l5-6 4 3 7-9',
  Map: 'M9 4L3 6v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14',
  Spots: 'M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11zM12 7.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z',
};

export interface BottomNavProps {
  active: NavTab;
  onSelect?: (tab: NavTab) => void;
}

/** App navigation with the four top-level sections. Sits at the bottom of every phone screen. */
export function BottomNav({ active, onSelect }: BottomNavProps) {
  return (
    <nav className="og-nav">
      {(Object.keys(paths) as NavTab[]).map(t => (
        <div key={t} className={t === active ? 'og-on' : ''} onClick={() => onSelect?.(t)}>
          <svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round"><path d={paths[t]} /></svg>{t}
        </div>
      ))}
    </nav>
  );
}
