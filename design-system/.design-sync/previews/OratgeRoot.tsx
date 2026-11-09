import { OratgeRoot, CurrentConditions, ActivityRow, SectionLabel } from '@oratge/ui';

export const PhoneScreen = () => (
  <OratgeRoot padded width={390}>
    <CurrentConditions place="Barcelona" source="Meteocat · Zoo station · 8 min ago" sky="partly" temp={18} summary="Mostly sunny" feels={17} min={11} max={21} wind="SW 14 kn · gusts 21" />
    <SectionLabel>Today for you</SectionLabel>
    <ActivityRow sport="wing" rating={4} window="13–17 h" reason="side-on SW 16–19 kn" />
    <ActivityRow sport="bike" rating={5} window="all day" reason="dry roads · light wind" />
  </OratgeRoot>
);
