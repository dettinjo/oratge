import { TrendLine } from '@oratge/ui';

export const LiveWind = () => <TrendLine accent="wind" values={[8, 9, 9, 10, 11, 11, 12, 13, 12, 13, 14, 14]} band={[12, 13, 14, 15, 16, 16, 18, 19, 18, 19, 21, 21]} nowIndex={11} nowLabel="14 kn" caption={['−4 h', 'now']} min={0} max={24} height={64} />;
export const ForecastVsMeasured = () => <TrendLine accent="wind" values={[7, 9, 10, 12, 14, 16]} compare={[6, 7, 8, 10, 12, 14, 16, 18]} nowIndex={5} nowLabel="now 16" caption={['07 h', '14 h']} min={0} max={22} height={96} />;
export const Pressure = () => <TrendLine accent="neutral" values={[1018, 1018, 1017.5, 1017, 1016, 1015, 1014, 1013, 1012, 1011, 1010, 1009.5, 1009]} endLabels={['1018', '1009 hPa']} caption={['−12 h', '+12 h']} height={70} />;
