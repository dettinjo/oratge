import * as React from 'react';

/**
 * ChipGroup — from @oratge/ui@0.1.0.
 */
export interface ChipGroupProps {
  options: string[];
  selected: string;
  /** Optional leading label, e.g. "Ride length". */
  label?: string;
  onSelect?: (option: string) => void;
}

export declare const ChipGroup: React.ComponentType<ChipGroupProps>;
