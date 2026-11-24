# Build de Chart.js (ADR-0019)

`bin/importmap pin chart.js` no funciona: jspm sirve Chart.js con un *chunk*
compartido (`../_/…js`) que importmap no descarga, y el pin apunta a un fichero
que no existe. Por eso `vendor/javascript/chartjs.js` es un único ESM generado
con esbuild a partir de `entry.js`, con solo lo que se usa ya registrado.

Node solo hace falta al actualizar Chart.js o al añadir un tipo de gráfico, y
fuera del proyecto (en un directorio temporal):

```bash
npm install chart.js@4.6.2 esbuild
npx esbuild /ruta/a/tholos/script/vendor/chartjs/entry.js --bundle --minify --format=esm \
  --outfile=/ruta/a/tholos/vendor/javascript/chartjs.js
```

Después, poner la versión en la cabecera de `vendor/javascript/chartjs.js`.
Dependabot no avisa de las versiones nuevas: revisarlas a mano.

- `entry.js`: línea (saldo de 90 días, US-0102). 56 KB gzip.
- `entry_f3.js`: referencia para F3 (línea, barras, donut y leyenda). 66 KB gzip.

Medidas y comparación con ECharts: SPK-0007.
