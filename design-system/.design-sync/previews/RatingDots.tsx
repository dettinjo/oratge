import { RatingDots } from '@oratge/ui';

export const Scale = () => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
    {[1, 2, 3, 4, 5].map(v => <RatingDots key={v} value={v} showWord />)}
  </div>
);
export const Large = () => <RatingDots value={4} size="lg" showWord />;
export const NotPossible = () => <RatingDots value={0} showWord />;
