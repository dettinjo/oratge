import * as React from 'react';

/**
 * DayTabs — from @oratge/ui@0.1.0.
 */
export interface DayTabsProps {
  days: DayTab[];
  /** Index of the selected day. */
  selected: number;
  onSelect?: (index: number) => void;
}

export declare const DayTabs: React.ComponentType<DayTabsProps>;
