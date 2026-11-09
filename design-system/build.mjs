import { build } from 'esbuild';
import { copyFileSync, mkdirSync } from 'node:fs';
mkdirSync('dist', { recursive: true });
await build({ entryPoints: ['src/index.ts'], bundle: true, format: 'esm', outfile: 'dist/index.js', external: ['react', 'react-dom', 'react/jsx-runtime'], jsx: 'automatic', target: 'es2020' });
copyFileSync('src/styles.css', 'dist/styles.css');
console.log('built dist/index.js + dist/styles.css');
