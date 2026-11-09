import { WaveBars } from '@oratge/ui';

const n = 24, hs = Array.from({ length: n }, (_, i) => Math.round((0.35 + 0.75 * Math.exp(-(((i - 10.5) / 4) ** 2)) + 0.15 * Math.sin(i / 1.7)) * 100) / 100);
const per = hs.map((h, i) => Math.round(5 + h * 3.6 + (i > 8 && i < 14 ? 1 : 0)));
const wind = Array.from({ length: n }, (_, i) => (i % 8 < 3 ? 290 : i % 8 < 6 ? 110 : 200));
export const ThreeDays = () => <WaveBars heights={hs} periods={per} windFrom={wind} days={['Mon', 'Tue', 'Wed']} best={[8, 9]} />;
export const Flat = () => <WaveBars heights={[0.2, 0.2, 0.3, 0.3, 0.3, 0.2, 0.2, 0.2]} periods={[4, 4, 5, 5, 5, 4, 4, 4]} days={['Thu']} />;
