import * as React from 'react';

/**
 * BottomNav — from @oratge/ui@0.1.0.
 */
export interface BottomNavProps {
  active: "Today" | "Activities" | "Map" | "Spots";
  onSelect?: (tab: NavTab) => void;
}

export declare const BottomNav: React.ComponentType<BottomNavProps>;
