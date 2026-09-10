/*
 * Anti-cheat: tab-switch detection for assessments.
 *
 * Detects when the student switches tabs/windows during an active assessment
 * using the Page Visibility API and window blur events. Logs each occurrence
 * with a timestamp for the teacher's review.
 *
 * Design decisions:
 * - Uses both `blur` and `visibilitychange` for maximum coverage
 * - Stores timestamps in a ref (not state) to avoid re-renders
 * - Shows a persistent amber banner during assessment
 * - Flashes "Tab switch recorded" for 3s after each event
 * - Non-intrusive: never blocks the student or interrupts their flow
 */
import { useCallback, useEffect, useRef, useState } from "react";

export interface TabSwitch {
  /** Date.now() timestamp */
  at: number;
  /** Which event triggered this */
  type: "blur" | "visibilitychange";
}

export interface AntiCheatState {
  /** All recorded tab switches */
  tabSwitches: TabSwitch[];
  /** Shorthand for tabSwitches.length */
  switchCount: number;
  /** True for 3s after each switch (for the flash banner) */
  showFlash: boolean;
}

/**
 * Hook to detect and log tab switches during an assessment.
 *
 * @param active - Whether the assessment is currently active
 * @returns AntiCheatState with tabSwitches, switchCount, and showFlash
 */
export function useAntiCheat(active: boolean): AntiCheatState {
  const switchesRef = useRef<TabSwitch[]>([]);
  const [switchCount, setSwitchCount] = useState(0);
  const [showFlash, setShowFlash] = useState(false);
  const flashTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastSwitchRef = useRef(0);

  const recordSwitch = useCallback((type: TabSwitch["type"]) => {
    // Deduplicate: blur and visibilitychange fire together for the same switch
    const now = Date.now();
    if (now - lastSwitchRef.current < 500) return;
    lastSwitchRef.current = now;

    const entry: TabSwitch = { at: now, type };
    switchesRef.current.push(entry);
    setSwitchCount(switchesRef.current.length);

    // Show flash for 3 seconds
    setShowFlash(true);
    if (flashTimerRef.current) clearTimeout(flashTimerRef.current);
    flashTimerRef.current = setTimeout(() => setShowFlash(false), 3000);
  }, []);

  useEffect(() => {
    if (!active) return;

    const handleBlur = () => recordSwitch("blur");
    const handleVisibility = () => {
      if (document.visibilityState === "hidden") {
        recordSwitch("visibilitychange");
      }
    };

    window.addEventListener("blur", handleBlur);
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      window.removeEventListener("blur", handleBlur);
      document.removeEventListener("visibilitychange", handleVisibility);
      if (flashTimerRef.current) clearTimeout(flashTimerRef.current);
    };
  }, [active, recordSwitch]);

  // Reset when assessment ends
  useEffect(() => {
    if (!active) {
      switchesRef.current = [];
      setSwitchCount(0);
      setShowFlash(false);
    }
  }, [active]);

  return {
    tabSwitches: switchesRef.current,
    switchCount,
    showFlash,
  };
}

/**
 * Get severity color for a switch count.
 * Returns a Tailwind-compatible class string.
 */
export function switchSeverity(count: number): {
  bg: string;
  text: string;
  label: string;
} {
  if (count === 0)
    return {
      bg: "bg-emerald-500/15",
      text: "text-emerald-600 dark:text-emerald-400",
      label: "No switches",
    };
  if (count <= 2)
    return {
      bg: "bg-amber-500/15",
      text: "text-amber-600 dark:text-amber-400",
      label: `${count} switch${count > 1 ? "es" : ""}`,
    };
  return {
    bg: "bg-rose-500/15",
    text: "text-rose-600 dark:text-rose-400",
    label: `${count} switches`,
  };
}
