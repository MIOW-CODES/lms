import React, { useState, useRef, useEffect, useCallback } from "react";
import {
  Sparkles,
  Trash2,
  Plus,
  Play,
  Square,
  Volume2,
  Sliders,
  ToggleLeft,
  ToggleRight,
  Info,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { ArduinoBoardState } from "@/lib/arduino-simulator";

export type ComponentType = "led" | "pushbutton" | "potentiometer" | "buzzer";

export interface CanvasComponent {
  id: string;
  type: ComponentType;
  x: number;
  y: number;
  label: string;
  color?: string; // for LED: 'red' | 'green' | 'blue' | 'yellow'
  connectedPin: number; // Digital 0-13 or Analog 14-19 (A0-A5)
  // Component runtime values
  inputValue?: number; // for pushbutton (0 or 1), potentiometer (0-1023)
}

interface InteractiveBreadboardCanvasProps {
  boardState: ArduinoBoardState | null;
  isRunning: boolean;
  onDigitalPinChange?: (pin: number, val: 0 | 1) => void;
  onAnalogPinChange?: (pinIndex: number, val: number) => void;
}

// Preset color options for LEDs
const LED_COLORS: Record<string, { bg: string; glow: string; text: string }> = {
  red: {
    bg: "bg-red-500",
    glow: "shadow-red-500/80 ring-4 ring-red-500/40",
    text: "text-red-400",
  },
  green: {
    bg: "bg-emerald-500",
    glow: "shadow-emerald-500/80 ring-4 ring-emerald-500/40",
    text: "text-emerald-400",
  },
  blue: {
    bg: "bg-sky-500",
    glow: "shadow-sky-500/80 ring-4 ring-sky-500/40",
    text: "text-sky-400",
  },
  yellow: {
    bg: "bg-amber-400",
    glow: "shadow-amber-400/80 ring-4 ring-amber-400/40",
    text: "text-amber-400",
  },
};

export function InteractiveBreadboardCanvas({
  boardState,
  isRunning,
  onDigitalPinChange,
  onAnalogPinChange,
}: InteractiveBreadboardCanvasProps) {
  // Default circuit items
  const [components, setComponents] = useState<CanvasComponent[]>([
    {
      id: "led-1",
      type: "led",
      x: 80,
      y: 90,
      label: "Red LED",
      color: "red",
      connectedPin: 13,
    },
    {
      id: "led-2",
      type: "led",
      x: 180,
      y: 90,
      label: "Green LED",
      color: "green",
      connectedPin: 12,
    },
    {
      id: "btn-1",
      type: "pushbutton",
      x: 80,
      y: 220,
      label: "Tactile Button",
      connectedPin: 2,
      inputValue: 0,
    },
    {
      id: "pot-1",
      type: "potentiometer",
      x: 230,
      y: 210,
      label: "Potentiometer (A0)",
      connectedPin: 14, // A0
      inputValue: 512,
    },
    {
      id: "buzzer-1",
      type: "buzzer",
      x: 380,
      y: 90,
      label: "Piezo Buzzer",
      connectedPin: 8,
    },
  ]);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<{
    id: string;
    startX: number;
    startY: number;
    elemX: number;
    elemY: number;
  } | null>(null);

  // Drag-and-drop handling on canvas
  const handleMouseDown = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    setSelectedId(id);
    const item = components.find((c) => c.id === id);
    if (!item) return;

    dragRef.current = {
      id,
      startX: e.clientX,
      startY: e.clientY,
      elemX: item.x,
      elemY: item.y,
    };
  };

  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (!dragRef.current || !containerRef.current) return;
    const { id, startX, startY, elemX, elemY } = dragRef.current;
    const rect = containerRef.current.getBoundingClientRect();

    const dx = e.clientX - startX;
    const dy = e.clientY - startY;

    const newX = Math.max(10, Math.min(rect.width - 150, elemX + dx));
    const newY = Math.max(10, Math.min(rect.height - 120, elemY + dy));

    setComponents((prev) =>
      prev.map((c) => (c.id === id ? { ...c, x: newX, y: newY } : c)),
    );
  }, []);

  const handleMouseUp = useCallback(() => {
    dragRef.current = null;
  }, []);

  useEffect(() => {
    window.addEventListener("mousemove", handleMouseMove);
    window.addEventListener("mouseup", handleMouseUp);
    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("mouseup", handleMouseUp);
    };
  }, [handleMouseMove, handleMouseUp]);

  // Component management
  const addComponent = (type: ComponentType) => {
    const id = `${type}-${Date.now().toString(36)}`;
    let newComp: CanvasComponent;

    if (type === "led") {
      newComp = {
        id,
        type: "led",
        x: 100 + Math.random() * 200,
        y: 60 + Math.random() * 150,
        label: "LED",
        color: "yellow",
        connectedPin: 11,
      };
    } else if (type === "pushbutton") {
      newComp = {
        id,
        type: "pushbutton",
        x: 100 + Math.random() * 200,
        y: 60 + Math.random() * 150,
        label: "Button",
        connectedPin: 3,
        inputValue: 0,
      };
    } else if (type === "potentiometer") {
      newComp = {
        id,
        type: "potentiometer",
        x: 100 + Math.random() * 200,
        y: 60 + Math.random() * 150,
        label: "Rotary Pot (A1)",
        connectedPin: 15, // A1
        inputValue: 0,
      };
    } else {
      newComp = {
        id,
        type: "buzzer",
        x: 100 + Math.random() * 200,
        y: 60 + Math.random() * 150,
        label: "Piezo Buzzer",
        connectedPin: 8,
      };
    }

    setComponents((prev) => [...prev, newComp]);
    setSelectedId(id);
  };

  const removeSelected = () => {
    if (!selectedId) return;
    setComponents((prev) => prev.filter((c) => c.id !== selectedId));
    setSelectedId(null);
  };

  const updatePin = (id: string, pin: number) => {
    setComponents((prev) =>
      prev.map((c) => (c.id === id ? { ...c, connectedPin: pin } : c)),
    );
  };

  const updateColor = (id: string, color: string) => {
    setComponents((prev) =>
      prev.map((c) => (c.id === id ? { ...c, color } : c)),
    );
  };

  // Button toggle or hold
  const handleButtonClick = (c: CanvasComponent) => {
    const nextVal = c.inputValue === 1 ? 0 : 1;
    setComponents((prev) =>
      prev.map((item) => (item.id === c.id ? { ...item, inputValue: nextVal } : item)),
    );
    if (onDigitalPinChange) {
      onDigitalPinChange(c.connectedPin, nextVal);
    }
  };

  // Potentiometer slide
  const handlePotChange = (c: CanvasComponent, val: number) => {
    setComponents((prev) =>
      prev.map((item) => (item.id === c.id ? { ...item, inputValue: val } : item)),
    );
    const aPin = c.connectedPin >= 14 ? c.connectedPin - 14 : c.connectedPin;
    if (onAnalogPinChange) {
      onAnalogPinChange(aPin, val);
    }
  };

  const selectedItem = components.find((c) => c.id === selectedId);

  return (
    <div className="space-y-4">
      {/* Mini Palette Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-border/80 bg-card/90 p-3 shadow-sm backdrop-blur-md">
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground mr-1">
            Add Parts:
          </span>
          <button
            onClick={() => addComponent("led")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background/80 px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <div className="h-2 w-2 rounded-full bg-red-500 shadow-sm" />
            + LED
          </button>
          <button
            onClick={() => addComponent("pushbutton")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background/80 px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <ToggleRight className="h-3.5 w-3.5 text-indigo-400" />
            + Push Button
          </button>
          <button
            onClick={() => addComponent("potentiometer")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background/80 px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <Sliders className="h-3.5 w-3.5 text-amber-400" />
            + Potentiometer
          </button>
          <button
            onClick={() => addComponent("buzzer")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background/80 px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <Volume2 className="h-3.5 w-3.5 text-sky-400" />
            + Buzzer
          </button>
        </div>

        {selectedItem && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">
              Editing: <strong className="text-foreground">{selectedItem.label}</strong>
            </span>
            <button
              onClick={removeSelected}
              className="inline-flex items-center gap-1 rounded-lg border border-rose-500/30 bg-rose-500/10 px-2.5 py-1.5 text-xs font-semibold text-rose-400 hover:bg-rose-500/20 transition"
              title="Delete component"
            >
              <Trash2 className="h-3.5 w-3.5" /> Delete
            </button>
          </div>
        )}
      </div>

      {/* Main Interactive Breadboard / Workspace */}
      <div
        ref={containerRef}
        onClick={() => setSelectedId(null)}
        className="relative min-h-[380px] w-full select-none overflow-hidden rounded-2xl border-2 border-emerald-900/50 bg-[#0f172a] shadow-inner"
        style={{
          backgroundImage: `
            radial-gradient(circle, rgba(148, 163, 184, 0.15) 1.5px, transparent 1.5px),
            radial-gradient(circle, rgba(148, 163, 184, 0.08) 1.5px, transparent 1.5px)
          `,
          backgroundSize: "24px 24px",
          backgroundPosition: "0 0, 12px 12px",
        }}
      >
        {/* Breadboard Header Watermark */}
        <div className="pointer-events-none absolute right-4 top-4 flex items-center gap-2 rounded-lg bg-slate-900/80 px-3 py-1 font-mono text-[11px] text-slate-400 border border-slate-800">
          <Sparkles className="h-3.5 w-3.5 text-emerald-400" />
          <span>Interactive Breadboard Canvas (Wokwi Style)</span>
        </div>

        {/* Render Components */}
        {components.map((c) => {
          const isSelected = c.id === selectedId;
          const isDigital = c.connectedPin <= 13;
          const pinVal = isDigital
            ? boardState?.digital[c.connectedPin]?.digitalValue ?? 0
            : boardState?.analog[c.connectedPin - 14]?.digitalValue ?? 0;
          const isHigh = pinVal === 1;

          return (
            <div
              key={c.id}
              onMouseDown={(e) => handleMouseDown(e, c.id)}
              style={{ left: c.x, top: c.y }}
              className={cn(
                "absolute cursor-grab active:cursor-grabbing rounded-xl border bg-slate-900/90 p-3 shadow-xl backdrop-blur-md transition-shadow",
                isSelected
                  ? "border-emerald-400 ring-2 ring-emerald-400/40 z-30"
                  : "border-slate-700/80 hover:border-slate-500 z-10",
              )}
            >
              {/* Wire indicator pill */}
              <div className="mb-2 flex items-center justify-between gap-3 text-[10px] font-mono text-slate-400 border-b border-slate-800 pb-1.5">
                <span className="font-semibold text-slate-200">{c.label}</span>
                <span className="rounded bg-slate-800 px-1.5 py-0.5 text-emerald-400 font-bold">
                  {c.connectedPin >= 14 ? `A${c.connectedPin - 14}` : `D${c.connectedPin}`}
                </span>
              </div>

              {/* Component specific visual controls */}
              {c.type === "led" && (
                <div className="flex items-center gap-3 py-1">
                  <div
                    className={cn(
                      "h-7 w-7 rounded-full border border-slate-600 transition-all duration-75 flex items-center justify-center",
                      isHigh
                        ? cn(LED_COLORS[c.color || "red"]?.bg, LED_COLORS[c.color || "red"]?.glow)
                        : "bg-slate-800/80",
                    )}
                  >
                    <div
                      className={cn(
                        "h-2 w-2 rounded-full",
                        isHigh ? "bg-white/90" : "bg-slate-700",
                      )}
                    />
                  </div>
                  <div className="font-mono text-xs">
                    <p className="font-bold text-slate-200">
                      {isHigh ? "HIGH (ON)" : "LOW (OFF)"}
                    </p>
                    <p className="text-[10px] text-slate-400">
                      {isHigh ? "20mA Active" : "0.0V"}
                    </p>
                  </div>
                </div>
              )}

              {c.type === "pushbutton" && (
                <div className="space-y-1.5 py-1">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleButtonClick(c);
                    }}
                    className={cn(
                      "flex w-full items-center justify-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold shadow transition active:scale-95",
                      c.inputValue === 1
                        ? "border-emerald-400 bg-emerald-600 text-white"
                        : "border-slate-600 bg-slate-800 text-slate-300 hover:bg-slate-700",
                    )}
                  >
                    {c.inputValue === 1 ? (
                      <>
                        <ToggleRight className="h-4 w-4" /> Pressed (HIGH)
                      </>
                    ) : (
                      <>
                        <ToggleLeft className="h-4 w-4" /> Released (LOW)
                      </>
                    )}
                  </button>
                  <p className="text-[10px] text-center text-slate-400 font-mono">
                    Click to toggle state
                  </p>
                </div>
              )}

              {c.type === "potentiometer" && (
                <div className="w-40 space-y-1 py-1">
                  <div className="flex justify-between text-[10px] font-mono text-slate-300">
                    <span>Val: {c.inputValue ?? 0}</span>
                    <span>{((((c.inputValue ?? 0) / 1023) * 5)).toFixed(2)}V</span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="1023"
                    value={c.inputValue ?? 0}
                    onChange={(e) => handlePotChange(c, Number(e.target.value))}
                    onClick={(e) => e.stopPropagation()}
                    className="h-1.5 w-full cursor-pointer appearance-none rounded-lg bg-slate-700 accent-emerald-400"
                  />
                </div>
              )}

              {c.type === "buzzer" && (
                <div className="flex items-center gap-2.5 py-1 font-mono text-xs">
                  <div
                    className={cn(
                      "flex h-8 w-8 items-center justify-center rounded-full border border-slate-700",
                      boardState?.buzzerTone
                        ? "bg-sky-500/30 text-sky-400 animate-pulse ring-4 ring-sky-500/20"
                        : "bg-slate-800 text-slate-500",
                    )}
                  >
                    <Volume2 className="h-4 w-4" />
                  </div>
                  <div>
                    <p className="font-bold text-slate-200">
                      {boardState?.buzzerTone ? `${boardState.buzzerTone} Hz` : "Silent"}
                    </p>
                    <p className="text-[10px] text-slate-400">
                      {boardState?.buzzerTone ? "Tone Output" : "Muted"}
                    </p>
                  </div>
                </div>
              )}

              {/* Quick pin selector when selected */}
              {isSelected && (
                <div
                  onClick={(e) => e.stopPropagation()}
                  className="mt-2.5 flex items-center justify-between gap-2 border-t border-slate-800 pt-2 text-[11px]"
                >
                  <label className="text-slate-400">Pin:</label>
                  <select
                    value={c.connectedPin}
                    onChange={(e) => updatePin(c.id, Number(e.target.value))}
                    className="rounded bg-slate-800 px-2 py-0.5 text-xs text-emerald-300 outline-none border border-slate-700 font-mono"
                  >
                    {c.type === "potentiometer" ? (
                      <>
                        <option value={14}>A0 (Pin 14)</option>
                        <option value={15}>A1 (Pin 15)</option>
                        <option value={16}>A2 (Pin 16)</option>
                        <option value={17}>A3 (Pin 17)</option>
                        <option value={18}>A4 (Pin 18)</option>
                        <option value={19}>A5 (Pin 19)</option>
                      </>
                    ) : (
                      <>
                        {[13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0].map((pin) => (
                          <option key={pin} value={pin}>
                            Pin {pin}
                          </option>
                        ))}
                      </>
                    )}
                  </select>

                  {c.type === "led" && (
                    <select
                      value={c.color || "red"}
                      onChange={(e) => updateColor(c.id, e.target.value)}
                      className="rounded bg-slate-800 px-1.5 py-0.5 text-xs text-slate-200 outline-none border border-slate-700 capitalize font-mono"
                    >
                      <option value="red">Red</option>
                      <option value="green">Green</option>
                      <option value="blue">Blue</option>
                      <option value="yellow">Yellow</option>
                    </select>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="flex items-center gap-2 text-xs text-muted-foreground">
        <Info className="h-3.5 w-3.5 text-primary" />
        <span>
          Drag components around to organize your test circuit. Click any component to change its pin or properties.
        </span>
      </div>
    </div>
  );
}
