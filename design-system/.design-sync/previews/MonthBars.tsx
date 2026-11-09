import { MonthBars } from '@oratge/ui';

export const RideableDays = () => <MonthBars values={[6.1, 7.8, 10.2, 12.4, 10.9, 8.3, 7.1, 6.4, 7.0, 8.8, 8.1, 6.6]} highlight={3} current={10} />;
export const RainDays = () => <MonthBars accent="water" values={[5, 4, 6, 7, 6, 4, 2, 4, 6, 8, 6, 5]} highlight={9} current={10} />;
