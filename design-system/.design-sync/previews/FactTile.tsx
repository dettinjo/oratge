import { FactTile } from '@oratge/ui';

export const FourUp = () => (
  <div style={{ width: 350, display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>
    <FactTile label="Water" value="18.6°" sub="3/2 suit" /><FactTile label="Sunset" value="17:35" sub="last light 18:03" />
    <FactTile label="Lightning" value="none" sub="50 km · 24 h" /><FactTile label="UV max" value="2" sub="low" />
  </div>
);
export const TwoUp = () => (
  <div style={{ width: 350, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
    <FactTile label="Wing" value="5 m → 4 m" sub="4 m when gusts > 22" /><FactTile label="Roads" value="dry from 09 h" sub="3.2 mm overnight" />
  </div>
);
export const Accented = () => (
  <div style={{ width: 350, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
    <FactTile label="Wave height" value="0.8 m" sub="buoy · 25 min ago" accent="water" /><FactTile label="Gusts" value="21 kn" sub="SW" accent="wind" />
  </div>
);
