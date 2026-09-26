/** What the user has done to individual parts; every change is one undo step. */
export interface PartState {
  hidden: string[];
  faded: string[];
  isolated?: string;
}

export const EMPTY_PART_STATE: PartState = { hidden: [], faded: [] };

export type PartAction = 'hide' | 'fade' | 'isolate';

export function applyAction(state: PartState, action: PartAction, partId: string): PartState {
  switch (action) {
    case 'hide':
      return { ...state, hidden: [...state.hidden, partId] };
    case 'fade':
      return state.faded.includes(partId)
        ? { ...state, faded: state.faded.filter((id) => id !== partId) }
        : { ...state, faded: [...state.faded, partId] };
    case 'isolate':
      return { ...state, isolated: state.isolated === partId ? undefined : partId };
  }
}

export const isVisible = (state: PartState, partId: string) =>
  !state.hidden.includes(partId) && (!state.isolated || state.isolated === partId);

export const changedCount = (state: PartState) => state.hidden.length + state.faded.length + (state.isolated ? 1 : 0);
