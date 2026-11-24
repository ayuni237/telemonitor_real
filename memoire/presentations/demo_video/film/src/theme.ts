export const FPS = 30;
export const W = 1920;
export const H = 1080;

/** Palette of the defence deck. */
export const C = {
  navy: '#12355B',
  red: '#B3261E',
  amber: '#B86E00',
  green: '#2E7D32',
  ink: '#161616',
  grey: '#5A636E',
  bg1: '#F7F9FB',
  bg2: '#E3E8EE',
  white: '#FFFFFF',
};

export const F = {
  title: 'Cambria, "Times New Roman", serif',
  ui: '"Segoe UI", Calibri, Arial, sans-serif',
};

/** Seconds to frames. */
export const sec = (s: number) => Math.round(s * FPS);
