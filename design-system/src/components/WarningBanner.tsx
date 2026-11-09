import { warningColor, type WarningLevel, colors } from '../tokens';

export interface WarningBannerProps {
  /** Meteocat warning level. */
  level: WarningLevel;
  /** e.g. "Orange warning · Sea state" */
  title: string;
  /** Area, time window and threshold, e.g. "Maresme coast · Wed 12–20 h · waves up to 2.5 m". */
  detail?: string;
  /** `pre` renders a lighter pre-warning (preavís) variant. */
  kind?: 'warning' | 'pre';
}

/** Official Meteocat warning. Warning colours are reserved for this component and the map overlay; always shown with the triangle icon and level name. */
export function WarningBanner({ level, title, detail, kind = 'warning' }: WarningBannerProps) {
  const c = warningColor(level);
  const pre = kind === 'pre';
  return (
    <div className="og-warn" role="alert" style={{ background: pre ? colors.surface : `color-mix(in srgb, ${c} 12%, ${colors.surface})`, borderColor: pre ? colors.line : `color-mix(in srgb, ${c} 40%, transparent)` }}>
      <svg width={18} height={18} viewBox="0 0 24 24" style={{ flex: 'none', marginTop: 1 }} aria-hidden>
        <path d="M12 3l10 18H2z" fill={pre ? 'none' : c} stroke={c} strokeWidth={pre ? 1.8 : 0} strokeLinejoin="round" />
        <path d="M12 10v5M12 17.5v.5" stroke={pre ? c : colors.bg} strokeWidth={2} strokeLinecap="round" />
      </svg>
      <div><div className="og-warn-title">{title}</div>{detail && <div className="og-warn-detail">{detail}</div>}</div>
    </div>
  );
}
