import React from 'react';
import { Composition } from 'remotion';
import { Film } from './Film';
import { FPS, H, W, sec } from './theme';
import { DURATION } from './timeline';

export const RemotionRoot: React.FC = () => (
  <Composition id="Film" component={Film} durationInFrames={sec(DURATION)} fps={FPS} width={W} height={H} />
);
