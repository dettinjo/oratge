import { ChipGroup } from '@oratge/ui';

export const RideLength = () => <div style={{ width: 350 }}><ChipGroup label="Ride length" options={['1 h', '2 h', '3 h', '4 h', '5 h']} selected="3 h" /></div>;
export const MapLayers = () => <div style={{ width: 350 }}><ChipGroup options={['Wind', 'Temp', 'Rain 1 h', '⚡ 60 min']} selected="Wind" /></div>;
