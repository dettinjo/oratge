export const linePath = (pts: [number, number][]) => pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
export const bandPath = (upper: [number, number][], lower: [number, number][]) =>
  linePath(upper) + ' ' + lower.slice().reverse().map(([x, y]) => `L${x.toFixed(1)} ${y.toFixed(1)}`).join(' ') + ' Z';
export const polar = (cx: number, cy: number, r: number, deg: number): [number, number] => [cx + r * Math.sin((deg * Math.PI) / 180), cy - r * Math.cos((deg * Math.PI) / 180)];
let n = 0;
export const uid = (p: string) => `${p}-${++n}`;
