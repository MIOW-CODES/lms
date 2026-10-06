import React, { useState, useRef, useEffect, useCallback } from "react";
import {
  Sparkles,
  Trash2,
  Volume2,
  Sliders,
  RotateCcw,
  Zap,
  Info,
  Maximize2,
  Settings2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { ArduinoBoardState } from "@/lib/arduino-simulator";

// Ensure @wokwi/elements custom elements are registered in browser
if (typeof window !== "undefined") {
  import("@wokwi/elements").catch(console.error);
}

export type WokwiComponentType =
  | "wokwi-led"
  | "wokwi-pushbutton"
  | "wokwi-potentiometer"
  | "wokwi-buzzer"
  | "wokwi-servo"
  | "wokwi-hc-sr04"
  | "wokwi-resistor";

export interface CanvasPart {
  id: string;
  type: WokwiComponentType;
  x: number;
  y: number;
  label: string;
  connectedPin: number; // 0-13 for digital, 14-19 for A0-A5
  color?: string; // for LED: 'red', 'green', 'blue', 'yellow'
  value?: number; // state value for input components (button: 0|1, pot: 0-1023, etc.)
  customAngle?: number; // for servo
}

interface InteractiveBreadboardCanvasProps {
  boardState: ArduinoBoardState | null;
  isRunning: boolean;
  onDigitalPinChange?: (pin: number, val: 0 | 1) => void;
  onAnalogPinChange?: (pinIndex: number, val: number) => void;
}

export function InteractiveBreadboardCanvas({
  boardState,
  isRunning,
  onDigitalPinChange,
  onAnalogPinChange,
}: InteractiveBreadboardCanvasProps) {
  // Realistic physical hardware parts on the canvas
  const [parts, setParts] = useState<CanvasPart[]>([
    {
      id: "led-red-1",
      type: "wokwi-led",
      x: 320,
      y: 60,
      label: "LED 13",
      connectedPin: 13,
      color: "red",
    },
    {
      id: "led-green-1",
      type: "wokwi-led",
      x: 390,
      y: 60,
      label: "LED 12",
      connectedPin: 12,
      color: "green",
    },
    {
      id: "btn-1",
      type: "wokwi-pushbutton",
      x: 320,
      y: 200,
      label: "Pushbutton (D2)",
      connectedPin: 2,
      value: 0,
      color: "blue",
    },
    {
      id: "pot-1",
      type: "wokwi-potentiometer",
      x: 440,
      y: 190,
      label: "Pot (A0)",
      connectedPin: 14, // A0
      value: 512,
    },
    {
      id: "buzzer-1",
      type: "wokwi-buzzer",
      x: 460,
      y: 50,
      label: "Piezo Buzzer (D8)",
      connectedPin: 8,
    },
    {
      id: "servo-1",
      type: "wokwi-servo",
      x: 320,
      y: 320,
      label: "SG90 Servo (D9)",
      connectedPin: 9,
      customAngle: 0,
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

  // Position of Arduino Uno Board on the canvas
  const [unoPos, setUnoPos] = useState({ x: 20, y: 30 });

  // Handle Dragging Components or Uno board
  const handleMouseDown = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    setSelectedId(id);
    const item = id === "arduino-uno" ? { x: unoPos.x, y: unoPos.y } : parts.find((p) => p.id === id);
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

    const newX = Math.max(10, Math.min(rect.width - 120, elemX + dx));
    const newY = Math.max(10, Math.min(rect.height - 100, elemY + dy));

    if (id === "arduino-uno") {
      setUnoPos({ x: newX, y: newY });
    } else {
      setParts((prev) =>
        prev.map((p) => (p.id === id ? { ...p, x: newX, y: newY } : p)),
      );
    }
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

  // Add Part Palette Action
  const addPart = (type: WokwiComponentType) => {
    const id = `${type}-${Date.now().toString(36)}`;
    let newPart: CanvasPart;

    const randX = 300 + Math.random() * 150;
    const randY = 80 + Math.random() * 200;

    switch (type) {
      case "wokwi-led":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "LED",
          color: "red",
          connectedPin: 11,
        };
        break;
      case "wokwi-pushbutton":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Pushbutton",
          color: "red",
          connectedPin: 3,
          value: 0,
        };
        break;
      case "wokwi-potentiometer":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Potentiometer",
          connectedPin: 15, // A1
          value: 0,
        };
        break;
      case "wokwi-buzzer":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Buzzer",
          connectedPin: 8,
        };
        break;
      case "wokwi-servo":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Servo",
          connectedPin: 9,
          customAngle: 0,
        };
        break;
      case "wokwi-hc-sr04":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "HC-SR04 Sonar",
          connectedPin: 7,
          value: 20,
        };
        break;
      case "wokwi-resistor":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "220Ω Resistor",
          connectedPin: 13,
        };
        break;
    }

    setParts((prev) => [...prev, newPart]);
    setSelectedId(id);
  };

  const removeSelected = () => {
    if (!selectedId || selectedId === "arduino-uno") return;
    setParts((prev) => prev.filter((p) => p.id !== selectedId));
    setSelectedId(null);
  };

  const updatePin = (id: string, pin: number) => {
    setParts((prev) =>
      prev.map((p) => (p.id === id ? { ...p, connectedPin: pin } : p)),
    );
  };

  const updateColor = (id: string, color: string) => {
    setParts((prev) =>
      prev.map((p) => (p.id === id ? { ...p, color } : p)),
    );
  };

  // Button Click Trigger on Physical Pushbutton
  const handlePushButton = (part: CanvasPart) => {
    const nextVal = part.value === 1 ? 0 : 1;
    setParts((prev) =>
      prev.map((p) => (p.id === part.id ? { ...p, value: nextVal } : p)),
    );
    if (onDigitalPinChange) {
      onDigitalPinChange(part.connectedPin, nextVal);
    }
  };

  // Potentiometer input change
  const handlePotInput = (part: CanvasPart, val: number) => {
    setParts((prev) =>
      prev.map((p) => (p.id === part.id ? { ...p, value: val } : p)),
    );
    const aPin = part.connectedPin >= 14 ? part.connectedPin - 14 : part.connectedPin;
    if (onAnalogPinChange) {
      onAnalogPinChange(aPin, val);
    }
  };

  const selectedPart = parts.find((p) => p.id === selectedId);

  return (
    <div className="space-y-4">
      {/* Real Hardware Component Palette */}
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-border/80 bg-card/90 p-3 shadow-sm backdrop-blur-md">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground mr-1">
            Real Hardware Parts:
          </span>
          <button
            onClick={() => addPart("wokwi-led")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <div className="h-2.5 w-2.5 rounded-full bg-red-500 shadow-sm" />
            + LED
          </button>
          <button
            onClick={() => addPart("wokwi-pushbutton")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <div className="h-2.5 w-2.5 rounded-sm bg-blue-500 shadow-sm" />
            + Push Button
          </button>
          <button
            onClick={() => addPart("wokwi-potentiometer")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <Sliders className="h-3.5 w-3.5 text-amber-500" />
            + Potentiometer
          </button>
          <button
            onClick={() => addPart("wokwi-buzzer")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <Volume2 className="h-3.5 w-3.5 text-sky-400" />
            + Buzzer
          </button>
          <button
            onClick={() => addPart("wokwi-servo")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <RotateCcw className="h-3.5 w-3.5 text-rose-400" />
            + SG90 Servo
          </button>
          <button
            onClick={() => addPart("wokwi-hc-sr04")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <Sparkles className="h-3.5 w-3.5 text-teal-400" />
            + HC-SR04 Sonar
          </button>
          <button
            onClick={() => addPart("wokwi-resistor")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted"
          >
            <span className="font-mono text-amber-600 font-bold">220Ω</span>
            + Resistor
          </button>
        </div>

        {selectedPart && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">
              Selected: <strong className="text-foreground">{selectedPart.label}</strong>
            </span>
            <button
              onClick={removeSelected}
              className="inline-flex items-center gap-1 rounded-lg border border-rose-500/30 bg-rose-500/10 px-2.5 py-1.5 text-xs font-semibold text-rose-400 hover:bg-rose-500/20 transition"
              title="Delete component"
            >
              <Trash2 className="h-3.5 w-3.5" /> Remove
            </button>
          </div>
        )}
      </div>

      {/* Main Interactive Breadboard / Circuit Sandbox with REAL SVG HW Components */}
      <div
        ref={containerRef}
        onClick={() => setSelectedId(null)}
        className="relative min-h-[520px] w-full select-none overflow-hidden rounded-2xl border-2 border-emerald-900/60 bg-[#090d16] shadow-2xl"
        style={{
          backgroundImage: `
            radial-gradient(circle, rgba(148, 163, 184, 0.18) 1.5px, transparent 1.5px),
            radial-gradient(circle, rgba(148, 163, 184, 0.08) 1.5px, transparent 1.5px)
          `,
          backgroundSize: "26px 26px",
          backgroundPosition: "0 0, 13px 13px",
        }}
      >
        {/* Real Circuit Board Watermark */}
        <div className="pointer-events-none absolute right-4 top-4 flex items-center gap-2 rounded-lg bg-slate-900/90 px-3 py-1 font-mono text-[11px] text-slate-300 border border-slate-700/80 shadow-md">
          <Zap className="h-3.5 w-3.5 text-amber-400" />
          <span>Wokwi Hardware Engine · Drag & Drop Components</span>
        </div>

        {/* 1. REAL WOKWI ARDUINO UNO BOARD */}
        <div
          onMouseDown={(e) => handleMouseDown(e, "arduino-uno")}
          style={{ left: unoPos.x, top: unoPos.y }}
          className={cn(
            "absolute cursor-grab active:cursor-grabbing select-none transition-shadow z-20 group p-1 rounded-xl",
            selectedId === "arduino-uno" && "ring-2 ring-emerald-400 shadow-2xl",
          )}
          title="Draggable Arduino Uno R3 Board"
        >
          {React.createElement("wokwi-arduino-uno", {
            led13: boardState?.builtinLed === 1,
            ledPower: isRunning,
            ledRX: false,
            ledTX: false,
          })}
          <div className="mt-1 flex items-center justify-between px-2 text-[10px] font-mono text-slate-400 bg-slate-900/80 rounded border border-slate-800">
            <span>Arduino Uno R3</span>
            <span className={cn("font-bold", isRunning ? "text-emerald-400" : "text-slate-500")}>
              {isRunning ? "POWER ON" : "STANDBY"}
            </span>
          </div>
        </div>

        {/* 2. REAL PHYSICAL HARDWARE COMPONENTS (Wokwi Elements) */}
        {parts.map((p) => {
          const isSelected = p.id === selectedId;
          const isDigital = p.connectedPin <= 13;
          const pinVal = isDigital
            ? boardState?.digital[p.connectedPin]?.digitalValue ?? 0
            : boardState?.analog[p.connectedPin - 14]?.digitalValue ?? 0;
          const isHigh = pinVal === 1;

          // Compute PWM / angle for servo
          const servoPwm = boardState?.digital[p.connectedPin]?.analogValue ?? 0;
          const servoAngle = Math.round((servoPwm / 255) * 180);

          return (
            <div
              key={p.id}
              onMouseDown={(e) => handleMouseDown(e, p.id)}
              style={{ left: p.x, top: p.y }}
              className={cn(
                "absolute cursor-grab active:cursor-grabbing select-none rounded-xl p-2 transition-shadow z-30 group",
                isSelected
                  ? "ring-2 ring-emerald-400 bg-slate-900/70 shadow-2xl border border-emerald-500/50"
                  : "hover:ring-1 hover:ring-slate-500/50 hover:bg-slate-900/40",
              )}
            >
              {/* Wiring Pin Badge on Component */}
              <div className="mb-1 flex items-center justify-between gap-2 px-1 text-[10px] font-mono">
                <span className="rounded bg-slate-800/90 px-1.5 py-0.2 text-slate-300 font-semibold border border-slate-700">
                  {p.label}
                </span>
                <span className="rounded bg-emerald-950 px-1.5 py-0.2 text-emerald-400 font-bold border border-emerald-800">
                  {p.connectedPin >= 14 ? `A${p.connectedPin - 14}` : `D${p.connectedPin}`}
                </span>
              </div>

              {/* REAL WOKWI ELEMENT RENDERING */}
              <div className="flex items-center justify-center p-1">
                {p.type === "wokwi-led" &&
                  React.createElement("wokwi-led", {
                    color: p.color || "red",
                    value: isHigh,
                    lightColor: p.color || "red",
                  })}

                {p.type === "wokwi-pushbutton" && (
                  <div
                    onClick={(e) => {
                      e.stopPropagation();
                      handlePushButton(p);
                    }}
                    className="cursor-pointer active:scale-95 transition"
                    title="Click to press pushbutton"
                  >
                    {React.createElement("wokwi-pushbutton", {
                      color: p.color || "red",
                      pressed: p.value === 1,
                    })}
                  </div>
                )}

                {p.type === "wokwi-potentiometer" && (
                  <div className="flex flex-col items-center gap-1">
                    {React.createElement("wokwi-potentiometer", {
                      min: 0,
                      max: 1023,
                      value: p.value ?? 512,
                    })}
                    <input
                      type="range"
                      min="0"
                      max="1023"
                      value={p.value ?? 512}
                      onChange={(e) => {
                        const val = Number(e.target.value);
                        handlePotInput(p, val);
                      }}
                      onClick={(e) => e.stopPropagation()}
                      className="h-1.5 w-24 cursor-pointer appearance-none rounded-lg bg-slate-700 accent-emerald-400"
                    />
                    <span className="font-mono text-[9px] text-slate-400">
                      {p.value ?? 512} (
                      {((((p.value ?? 512) / 1023) * 5.0)).toFixed(2)}V)
                    </span>
                  </div>
                )}

                {p.type === "wokwi-buzzer" &&
                  React.createElement("wokwi-buzzer", {
                    hasSignal: Boolean(boardState?.buzzerTone),
                  })}

                {p.type === "wokwi-servo" &&
                  React.createElement("wokwi-servo", {
                    angle: servoAngle,
                  })}

                {p.type === "wokwi-hc-sr04" && (
                  <div className="flex flex-col items-center gap-1">
                    {React.createElement("wokwi-hc-sr04", {})}
                    <input
                      type="range"
                      min="2"
                      max="400"
                      value={p.value ?? 20}
                      onChange={(e) => {
                        const val = Number(e.target.value);
                        setParts((prev) =>
                          prev.map((item) => (item.id === p.id ? { ...item, value: val } : item)),
                        );
                        const aPin = p.connectedPin >= 14 ? p.connectedPin - 14 : p.connectedPin;
                        if (onAnalogPinChange && aPin <= 5) {
                          onAnalogPinChange(aPin, Math.round((val / 400) * 1023));
                        }
                      }}
                      onClick={(e) => e.stopPropagation()}
                      className="h-1.5 w-24 cursor-pointer appearance-none rounded-lg bg-slate-700 accent-teal-400"
                    />
                    <span className="font-mono text-[9px] text-teal-400">
                      Dist: {p.value ?? 20} cm
                    </span>
                  </div>
                )}

                {p.type === "wokwi-resistor" &&
                  React.createElement("wokwi-resistor", {
                    value: "220",
                  })}
              </div>

              {/* Pin / Property Selector Popover when selected */}
              {isSelected && (
                <div
                  onClick={(e) => e.stopPropagation()}
                  className="mt-1 flex items-center justify-between gap-1.5 rounded-lg border border-slate-700 bg-slate-900/90 p-1.5 text-[11px] backdrop-blur-md shadow"
                >
                  <label className="text-slate-400 font-mono text-[10px]">Pin:</label>
                  <select
                    value={p.connectedPin}
                    onChange={(e) => updatePin(p.id, Number(e.target.value))}
                    className="rounded bg-slate-800 px-1.5 py-0.5 text-xs text-emerald-300 outline-none border border-slate-700 font-mono"
                  >
                    {p.type === "wokwi-potentiometer" ? (
                      <>
                        <option value={14}>A0</option>
                        <option value={15}>A1</option>
                        <option value={16}>A2</option>
                        <option value={17}>A3</option>
                        <option value={18}>A4</option>
                        <option value={19}>A5</option>
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

                  {p.type === "wokwi-led" && (
                    <select
                      value={p.color || "red"}
                      onChange={(e) => updateColor(p.id, e.target.value)}
                      className="rounded bg-slate-800 px-1 py-0.5 text-xs text-slate-200 outline-none border border-slate-700 capitalize font-mono"
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
          Real Wokwi physical hardware: Drag both the Arduino Uno board and external parts to build your test circuit. Click components to re-wire their pins or interact with them.
        </span>
      </div>
    </div>
  );
}
