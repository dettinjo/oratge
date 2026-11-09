import { NextHours } from '@oratge/ui';

export const Next24 = () => (
  <NextHours startHour={10} temps={[17, 16, 15, 14, 14, 13, 13, 14, 16, 18, 19, 20, 21, 21, 20, 19, 18, 17, 16, 15, 15, 14, 14, 13]}
    rain={[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 20, 45, 60, 40, 20, 10, 5, 0, 0, 0, 0]}
    sky={['partly', 'partly', 'cloud', 'cloud', 'night', 'night', 'night', 'night', 'night', 'night', 'night', 'night', 'partly', 'cloud', 'storm', 'rain', 'rain', 'cloud', 'cloud', 'sun', 'sun', 'sun', 'partly', 'partly']} />
);
