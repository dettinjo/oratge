import { WarningBanner } from '@oratge/ui';

export const Orange = () => <div style={{ width: 350 }}><WarningBanner level="orange" title="Orange warning · Sea state" detail="Maresme coast · Wed 12–20 h · waves up to 2.5 m" /></div>;
export const Levels = () => (
  <div style={{ width: 350, display: 'flex', flexDirection: 'column', gap: 10 }}>
    <WarningBanner level="yellow" title="Yellow warning · Wind" detail="Barcelona coast · Tue 14–22 h · gusts above 70 km/h" />
    <WarningBanner level="orange" title="Orange warning · Rain" detail="Garrotxa · Thu 06–18 h · 40 mm in 1 h" />
    <WarningBanner level="red" title="Red warning · Snow" detail="Val d'Aran · Fri · 60 cm above 1000 m" />
  </div>
);
export const PreWarning = () => <div style={{ width: 350 }}><WarningBanner level="yellow" kind="pre" title="Pre-warning · Wed" detail="Yellow wind warning likely for the Barcelona coast" /></div>;
