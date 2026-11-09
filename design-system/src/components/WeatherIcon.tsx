import { colors } from '../tokens';

export type WeatherKind = 'sun' | 'partly' | 'cloud' | 'rain' | 'storm' | 'bolt' | 'wind' | 'wave' | 'heat' | 'snow' | 'uv' | 'night' | 'fog';

export interface WeatherIconProps {
  kind: WeatherKind;
  /** Pixel size (square). Default 24. */
  size?: number;
}

const sw = { strokeWidth: 1.7, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, fill: 'none' };

function Sun({ cx, cy, r }: { cx: number; cy: number; r: number }) {
  return (<g><circle cx={cx} cy={cy} r={r} fill={colors.sun} />
    {[0, 45, 90, 135, 180, 225, 270, 315].map(a => { const q = (a * Math.PI) / 180;
      return <line key={a} x1={cx + Math.cos(q) * (r + 2.2)} y1={cy + Math.sin(q) * (r + 2.2)} x2={cx + Math.cos(q) * (r + 4)} y2={cy + Math.sin(q) * (r + 4)} stroke={colors.sun} strokeWidth={1.6} strokeLinecap="round" />; })}</g>);
}
const Cloud = ({ dy = 0, fill = 'none' }: { dy?: number; fill?: string }) => (
  <path transform={`translate(0 ${dy})`} d="M7 18h10a4 4 0 0 0 .4-8 5.5 5.5 0 0 0-10.6 1.5A3.3 3.3 0 0 0 7 18z" stroke={colors.cloud} {...sw} fill={fill} />);

/** Weather glyph with the accent colour that matches its meaning (sun = honey, rain/waves = sea blue, storm = lavender, wind = sage-teal, heat = apricot). Use for sky state and activity markers; never recolour. */
export function WeatherIcon({ kind, size = 24 }: WeatherIconProps) {
  let body;
  switch (kind) {
    case 'sun': body = <Sun cx={12} cy={12} r={4.2} />; break;
    case 'partly': body = (<g><Sun cx={9} cy={9} r={3.4} /><path d="M8 20h9.5a3.6 3.6 0 0 0 .3-7.2 5 5 0 0 0-9.6 1.4A3 3 0 0 0 8 20z" fill={colors.bg} stroke={colors.cloud} strokeWidth={1.7} strokeLinejoin="round" /></g>); break;
    case 'cloud': body = <Cloud />; break;
    case 'fog': body = (<g><Cloud dy={-3} />{[17, 20].map(y => <line key={y} x1={5} x2={19} y1={y} y2={y} stroke={colors.cloud} strokeWidth={1.6} strokeLinecap="round" />)}</g>); break;
    case 'rain': body = (<g><Cloud dy={-3} />{[7, 11, 15].map(x => <line key={x} x1={x} y1={18} x2={x - 1.2} y2={21.5} stroke={colors.water} strokeWidth={1.8} strokeLinecap="round" />)}</g>); break;
    case 'storm': body = (<g><Cloud dy={-3} /><path d="M12.5 15l-2.5 4h3l-2 4" stroke={colors.storm} {...sw} strokeWidth={1.8} /></g>); break;
    case 'bolt': body = <path d="M13 2L5 14h6l-1 8 8-12h-6z" fill={colors.storm} />; break;
    case 'wind': body = <path d="M3 9h11a3 3 0 1 0-3-3M3 13h15a3 3 0 1 1-3 3M3 17h7" stroke={colors.wind} {...sw} />; break;
    case 'wave': body = <path d="M2 12c2.5 0 2.5-2.2 5-2.2s2.5 2.2 5 2.2 2.5-2.2 5-2.2 2.5 2.2 5 2.2M2 17c2.5 0 2.5-2.2 5-2.2s2.5 2.2 5 2.2 2.5-2.2 5-2.2 2.5 2.2 5 2.2" stroke={colors.water} {...sw} />; break;
    case 'heat': body = (<g><path d="M12 4v10.5" stroke={colors.heat} strokeWidth={1.7} strokeLinecap="round" /><circle cx={12} cy={17.5} r={3} fill={colors.heat} /><path d="M10 4a2 2 0 0 1 4 0v10.6a4.2 4.2 0 1 1-4 0z" stroke={colors.text2} {...sw} /></g>); break;
    case 'snow': body = (<g>{[0, 60, 120].map(a => <line key={a} x1={12} y1={4} x2={12} y2={20} transform={`rotate(${a} 12 12)`} stroke={colors.snow} strokeWidth={1.7} strokeLinecap="round" />)}</g>); break;
    case 'uv': body = (<g><Sun cx={12} cy={11} r={3.2} /><text x={12} y={23.6} fontSize={5} textAnchor="middle" fill={colors.sun} fontWeight={700}>UV</text></g>); break;
    case 'night': body = <path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z" fill="#CFC6B8" />; break;
  }
  return <svg width={size} height={size} viewBox="0 0 24 24" role="img" aria-label={kind}>{body}</svg>;
}
