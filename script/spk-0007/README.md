# SPK-0007: builds parciales de gráficos

`bin/importmap pin echarts` y `bin/importmap pin chart.js` no funcionan: jspm
sirve las dos como módulos sueltos (`./lib/...`, `../_/chunk.js`) que importmap
no descarga. Estas entradas generan un único ESM por librería con esbuild,
fuera del proyecto (Node solo hace falta al actualizar la librería):

```bash
npm install echarts@6.1.0 chart.js@4.6.2 esbuild
npx esbuild echarts_line.js --bundle --minify --format=esm --outfile=vendor/javascript/echarts.js
npx esbuild chartjs_line.js --bundle --minify --format=esm --outfile=vendor/javascript/chartjs.js
```

Pesos medidos (minificado / gzip / brotli):

| Build | min | gzip | brotli |
|---|---|---|---|
| ECharts línea (US-0102) | 506 KB | 173 KB | 147 KB |
| ECharts línea + barras + donut (F3) | 565 KB | 193 KB | 164 KB |
| ECharts completo (`dist/echarts.esm.min.mjs`) | 1095 KB | 359 KB | 292 KB |
| Chart.js línea | 161 KB | 56 KB | 49 KB |
| Chart.js línea + barras + donut (F3) | 190 KB | 66 KB | 58 KB |
