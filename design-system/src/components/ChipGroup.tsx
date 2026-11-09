export interface ChipGroupProps {
  options: string[];
  selected: string;
  /** Optional leading label, e.g. "Ride length". */
  label?: string;
  onSelect?: (option: string) => void;
}

/** Single-select pill chips: layer toggles, ride/run length pickers. */
export function ChipGroup({ options, selected, label, onSelect }: ChipGroupProps) {
  return (
    <div className="og-chips">
      {label && <span className="og-fact-label" style={{ marginRight: 'auto' }}>{label}</span>}
      {options.map(o => <button key={o} type="button" className={'og-chip' + (o === selected ? ' og-on' : '')} onClick={() => onSelect?.(o)}>{o}</button>)}
    </div>
  );
}
