import { ActivityRow } from '@oratge/ui';

export const TodayForYou = () => (
  <div style={{ width: 350 }}>
    <ActivityRow sport="wing" rating={4} window="13–17 h" reason="side-on SW 16–19 kn" />
    <ActivityRow sport="surf" rating={1} window="—" reason="flat · 0.3 m" />
    <ActivityRow sport="bike" rating={5} window="all day" reason="dry roads · light wind" />
    <ActivityRow sport="run" rating={4} window="before 11 h" reason="UV 6 from noon" />
    <ActivityRow sport="hike" rating={2} window="until 14 h" reason="storms likely after 15 h" />
  </div>
);
export const Single = () => <div style={{ width: 350 }}><ActivityRow sport="wing" rating={5} window="14–16 h" reason="SW 17–20 kn · steady, gust factor 1.2" /></div>;
