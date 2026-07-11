/**
 * Chart color helpers backed by the design-system color tokens.
 *
 * Chart.js renders to a <canvas>, so it cannot consume CSS custom properties
 * directly. These helpers read the `--<scale>-<step>` tokens defined in
 * `dashboard/assets/scss/_next-colors.scss` at call time. Resolving lazily
 * (not at module load) keeps charts aligned with the brand palette and lets
 * them follow the active light/dark theme whenever the chart re-renders.
 */

const resolveToken = (token, alpha = 1) => {
  if (typeof window === 'undefined') return '';

  const value = window
    .getComputedStyle(document.documentElement)
    .getPropertyValue(token)
    .trim();

  if (!value) return '';

  return alpha === 1 ? `rgb(${value})` : `rgb(${value} / ${alpha})`;
};

// Series colors for the single-metric report charts (brand blue).
export const getChartSeriesColors = () => ({
  bar: resolveToken('--blue-9'),
  line: resolveToken('--blue-9'),
  point: resolveToken('--blue-9'),
});

// Accessible categorical palette (Radix step 9) for multi-series charts.
export const CHART_CATEGORICAL_TOKENS = [
  '--blue-9',
  '--teal-9',
  '--amber-9',
  '--iris-9',
  '--ruby-9',
];

export const getCategoricalPalette = (alpha = 1) =>
  CHART_CATEGORICAL_TOKENS.map(token => resolveToken(token, alpha));
