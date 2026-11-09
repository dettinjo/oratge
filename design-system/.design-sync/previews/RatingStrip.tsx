import { RatingStrip } from '@oratge/ui';

export const WingDay = () => <div style={{ width: 320 }}><RatingStrip values={[0, 1, 3, 4, 5, 5, 4, 2]} caption={['08 h', "today's rating", '22 h']} /></div>;
export const AllDay = () => <div style={{ width: 320 }}><RatingStrip values={[5, 5, 5, 5, 5, 4, 4, 4]} height={12} /></div>;
export const Hourly = () => <div style={{ width: 320 }}><RatingStrip values={[0, 0, 0, 1, 2, 3, 4, 5, 5, 4, 2, 0, 0, 0]} caption={['07 h', 'Tue', '20 h']} /></div>;
