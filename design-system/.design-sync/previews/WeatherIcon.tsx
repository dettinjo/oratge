import { WeatherIcon, type WeatherKind } from '@oratge/ui';

const all: [WeatherKind, string][] = [['sun', 'Sun'], ['partly', 'Partly'], ['cloud', 'Cloud'], ['fog', 'Fog'], ['rain', 'Rain'], ['storm', 'Storm'], ['bolt', 'Lightning'], ['snow', 'Snow'], ['wind', 'Wind'], ['wave', 'Waves'], ['heat', 'Heat'], ['uv', 'UV'], ['night', 'Clear night']];
export const AllKinds = () => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 64px)', gap: '14px 8px' }}>
    {all.map(([k, n]) => <div key={k} style={{ textAlign: 'center' }}><WeatherIcon kind={k} size={30} /><div style={{ fontSize: 10.5, color: '#7E7468', marginTop: 4 }}>{n}</div></div>)}
  </div>
);
export const Sizes = () => <div style={{ display: 'flex', gap: 16, alignItems: 'end' }}><WeatherIcon kind="partly" size={18} /><WeatherIcon kind="partly" size={30} /><WeatherIcon kind="partly" size={62} /></div>;
