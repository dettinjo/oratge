import { SpotCard } from '@oratge/ui';

export const WingSpot = () => <div style={{ width: 350 }}><SpotCard name="Castelldefels" kind="Wing · flatwater" wind={14} gust={21} windFrom={225} today={[0, 1, 3, 4, 4, 3, 0, 0]} window="13–17 h" rating={4} /></div>;
export const SpotList = () => (
  <div style={{ width: 350, display: 'flex', flexDirection: 'column', gap: 10 }}>
    <SpotCard name="Ocata" kind="Surf · beach" wind={6} gust={9} windFrom={330} today={[3, 3, 2, 1, 1, 1, 0, 0]} window="08–11 h" rating={3} />
    <SpotCard name="Collserola loop" kind="Bike · 42 km" wind={7} gust={12} windFrom={240} today={[5, 5, 5, 5, 5, 4, 4, 4]} window="all day" rating={5} />
    <SpotCard name="Montseny · Turó de l'Home" kind="Hike · 1706 m" wind={22} gust={34} windFrom={300} today={[3, 3, 2, 1, 1, 0, 0, 0]} window="until 13 h" rating={2} />
  </div>
);
