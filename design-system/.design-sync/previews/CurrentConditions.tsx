import { CurrentConditions } from '@oratge/ui';

export const Barcelona = () => <div style={{ width: 350 }}><CurrentConditions place="Barcelona" source="Meteocat · Zoo station · 8 min ago" sky="partly" temp={18} summary="Mostly sunny" feels={17} min={11} max={21} wind="SW 14 kn · gusts 21" /></div>;
export const RainyMountain = () => <div style={{ width: 350 }}><CurrentConditions place="Berga" source="Meteocat · Berga station · 12 min ago" sky="rain" temp={7} summary="Showers" feels={4} min={5} max={11} wind="N 9 kn · gusts 17" /></div>;
