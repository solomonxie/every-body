import { useEffect, useRef, useState } from 'react';

import type { Params, Scenario } from './types';

const EASE = 3.5;

/** params as of a step: base values plus every step's targets up to it, so Prev is deterministic */
const targetsAt = (scenario: Scenario, index: number): Params =>
  Object.assign({}, scenario.params, ...scenario.steps.slice(0, index + 1).map((step) => step.set ?? {}));

/** Steps through a scenario, easing params toward each step's targets every frame. */
export function usePlayer(scenario: Scenario) {
  const [stepIndex, setStepIndex] = useState(0);
  const [frame, setFrame] = useState<{ t: number; params: Params }>(() => ({
    t: 0,
    params: targetsAt(scenario, 0),
  }));
  const targets = useRef<Params>(targetsAt(scenario, 0));
  const instant = useRef<Params>({});

  useEffect(() => {
    let raf = 0;
    let last = performance.now();
    const start = last;
    const loop = (now: number) => {
      const k = 1 - Math.exp(-EASE * Math.min(0.1, (now - last) / 1000));
      last = now;
      const goals = targets.current;
      const jumps = instant.current;
      instant.current = {};
      setFrame((prev) => {
        const params: Params = { ...prev.params };
        for (const key of Object.keys(goals)) {
          params[key] = key in jumps ? jumps[key] : params[key] + (goals[key] - params[key]) * k;
        }
        return { t: (now - start) / 1000, params };
      });
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);

  const goTo = (index: number) => {
    const clamped = Math.max(0, Math.min(scenario.steps.length - 1, index));
    targets.current = targetsAt(scenario, clamped);
    setStepIndex(clamped);
  };

  /** jump a param now (drag, taps) */
  const setParams = (values: Params) => {
    Object.assign(targets.current, values);
    Object.assign(instant.current, values);
  };

  /** ease a param toward a value (sliders, "Show me") */
  const easeParams = (values: Params) => {
    Object.assign(targets.current, values);
  };

  /** jump to 1 and ease back to 0 — a press or beat */
  const pulse = (key: string) => {
    instant.current[key] = 1;
    targets.current[key] = 0;
  };

  const step = scenario.steps[stepIndex];
  const solved = step.kind === 'watch' || Boolean(step.try?.success(frame.params));

  return { step, stepIndex, goTo, params: frame.params, t: frame.t, setParams, easeParams, pulse, solved };
}
