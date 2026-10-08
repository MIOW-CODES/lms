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
  Activity,
  Plus,
  RefreshCw,
  MousePointer2,
  Spline,
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
  value?: number; // state value for input components
  wireColor?: string; // visual jumper wire color
}

// Available jumper wire colors
const WIRE_COLORS = [
  { name: "Green", stroke: "#10b981" },
  { name: "Amber", stroke: "#f59e0b" },
  { name: "Cyan", stroke: "#06b6d4" },
  { name: "Rose", stroke: "#f43f5e" },
  { name: "Purple", stroke: "#a855f7" },
  { name: "Blue", stroke: "#3b82f6" },
];

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
  // Draggable Hardware Components
  const [parts, setParts] = useState<CanvasPart[]>([
    {
      id: "led-13",
      type: "wokwi-led",
      x: 380,
      y: 50,
      label: "LED (D13)",
      connectedPin: 13,
      color: "red",
      wireColor: "#f43f5e",
    },
    {
      id: "led-12",
      type: "wokwi-led",
      x: 480,
      y: 50,
      label: "LED (D12)",
      connectedPin: 12,
      color: "green",
      wireColor: "#10b981",
    },
    {
      id: "btn-2",
      type: "wokwi-pushbutton",
      x: 380,
      y: 200,
      label: "Button (D2)",
      connectedPin: 2,
      color: "blue",
      value: 0,
      wireColor: "#3b82f6",
    },
    {
      id: "pot-a0",
      type: "wokwi-potentiometer",
      x: 520,
      y: 190,
      label: "Pot (A0)",
      connectedPin: 14, // A0
      value: 512,
      wireColor: "#f59e0b",
    },
    {
      id: "buzzer-8",
      type: "wokwi-buzzer",
      x: 660,
      y: 50,
      label: "Buzzer (D8)",
      connectedPin: 8,
      wireColor: "#06b6d4",
    },
    {
      id: "servo-9",
      type: "wokwi-servo",
      x: 440,
      y: 340,
      label: "Servo (D9)",
      connectedPin: 9,
      wireColor: "#a855f7",
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

  /* ---------- Manual wire drawing (Tinkercad-style pin-to-pin) ---------- */
  type UserWire = { id: string; x1: number; y1: number; x2: number; y2: number; color: string };
  const [drawMode, setDrawMode] = useState(false);
  const [drawColor, setDrawColor] = useState<string>(WIRE_COLORS[0]?.stroke ?? "#10b981");
  const [wireStart, setWireStart] = useState<{ x: number; y: number } | null>(null);
  const [cursorPos, setCursorPos] = useState<{ x: number; y: number } | null>(null);
  const [userWires, setUserWires] = useState<UserWire[]>([]);
  const [selectedWireId, setSelectedWireId] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);

  // Escape cancels an in-progress wire (second Esc exits draw mode)
  useEffect(() => {
    if (!drawMode) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        if (wireStart) setWireStart(null);
        else setDrawMode(false);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [drawMode, wireStart]);

  // Component mousedown in draw mode anchors a wire; its click event still
  // bubbles to the canvas — skip that bubbled click to avoid a double anchor.
  const skipNextCanvasClick = useRef(false);

  const localPoint = (e: React.MouseEvent | MouseEvent) => {
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return { x: 0, y: 0 };
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  };

  // Canvas click while in draw mode routes a wire anchor
  const handleCanvasClick = (e: React.MouseEvent) => {
    if (skipNextCanvasClick.current) {
      skipNextCanvasClick.current = false;
      return;
    }
    if (!drawMode) {
      setSelectedId(null);
      setSelectedWireId(null);
      return;
    }
    const pt = localPoint(e);
    if (!wireStart) {
      setWireStart(pt);
    } else {
      setUserWires((prev) => [
        ...prev,
        {
          id: `wire-${Date.now().toString(36)}`,
          x1: wireStart.x,
          y1: wireStart.y,
          x2: pt.x,
          y2: pt.y,
          color: drawColor,
        },
      ]);
      setWireStart(null);
    }
  };

  const removeWire = (id: string) => {
    setUserWires((prev) => prev.filter((w) => w.id !== id));
    setSelectedWireId(null);
  };

  // Position of Arduino Uno Board on the canvas (scaled down to fit workbench)
  const [unoPos, setUnoPos] = useState({ x: 30, y: 50 });

  // Handle Dragging
  const handleMouseDown = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (drawMode) {
      // In draw mode a component click is a wire anchor instead of a drag start
      skipNextCanvasClick.current = true;
      handleCanvasClick(e);
      return;
    }
    setSelectedId(id);
    const item =
      id === "arduino-uno" ? { x: unoPos.x, y: unoPos.y } : parts.find((p) => p.id === id);
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

    const newX = Math.max(10, Math.min(rect.width - 100, elemX + dx));
    const newY = Math.max(10, Math.min(rect.height - 100, elemY + dy));

    if (id === "arduino-uno") {
      setUnoPos({ x: newX, y: newY });
    } else {
      setParts((prev) => prev.map((p) => (p.id === id ? { ...p, x: newX, y: newY } : p)));
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

  // Add Part — optionally at explicit canvas coordinates (drag-and-drop)
  const addPart = (type: WokwiComponentType, at?: { x: number; y: number }) => {
    const id = `${type}-${Date.now().toString(36)}`;
    const randX = at ? at.x : 350 + Math.random() * 200;
    const randY = at ? at.y : 60 + Math.random() * 240;
    const color = WIRE_COLORS[Math.floor(Math.random() * WIRE_COLORS.length)]?.stroke ?? "#10b981";

    let newPart: CanvasPart;
    switch (type) {
      case "wokwi-led":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "LED",
          color: "yellow",
          connectedPin: 11,
          wireColor: color,
        };
        break;
      case "wokwi-pushbutton":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Button",
          color: "red",
          connectedPin: 3,
          value: 0,
          wireColor: color,
        };
        break;
      case "wokwi-potentiometer":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Pot (A1)",
          connectedPin: 15,
          value: 0,
          wireColor: color,
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
          wireColor: color,
        };
        break;
      case "wokwi-servo":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "SG90 Servo",
          connectedPin: 9,
          wireColor: color,
        };
        break;
      case "wokwi-hc-sr04":
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Sonar",
          connectedPin: 7,
          value: 25,
          wireColor: color,
        };
        break;
      default:
        newPart = {
          id,
          type,
          x: randX,
          y: randY,
          label: "Resistor",
          connectedPin: 13,
          wireColor: color,
        };
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
    setParts((prev) => prev.map((p) => (p.id === id ? { ...p, connectedPin: pin } : p)));
  };

  const updateWireColor = (id: string, wireColor: string) => {
    setParts((prev) => prev.map((p) => (p.id === id ? { ...p, wireColor } : p)));
  };

  const handlePushButton = (part: CanvasPart) => {
    const nextVal = part.value === 1 ? 0 : 1;
    setParts((prev) => prev.map((p) => (p.id === part.id ? { ...p, value: nextVal } : p)));
    if (onDigitalPinChange) {
      onDigitalPinChange(part.connectedPin, nextVal);
    }
  };

  const handlePotInput = (part: CanvasPart, val: number) => {
    setParts((prev) => prev.map((p) => (p.id === part.id ? { ...p, value: val } : p)));
    const aPin = part.connectedPin >= 14 ? part.connectedPin - 14 : part.connectedPin;
    if (onAnalogPinChange) {
      onAnalogPinChange(aPin, val);
    }
  };

  // Approximate relative coordinate of Arduino header pins on the Uno board (scaled at 0.75x)
  const getUnoHeaderPinCoord = (pin: number) => {
    const scale = 0.78;
    // Board header coordinates relative to top-left of Uno
    if (pin >= 0 && pin <= 13) {
      // Digital pins header along top of Uno (D0 on right, D13 on left)
      const pinOffset = (13 - pin) * 11;
      return {
        x: unoPos.x + (145 + pinOffset) * scale,
        y: unoPos.y + 18 * scale,
      };
    } else {
      // Analog pins header along bottom right of Uno (A0 to A5)
      const aIndex = pin - 14;
      const pinOffset = aIndex * 11;
      return {
        x: unoPos.x + (195 + pinOffset) * scale,
        y: unoPos.y + 265 * scale,
      };
    }
  };

  const selectedPart = parts.find((p) => p.id === selectedId);

  return (
    <div className="space-y-4">
      {/* Component Palette Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-border/80 bg-card/90 p-3 shadow-sm backdrop-blur-md">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground mr-1">
            Real Hardware Parts:
          </span>
          {/* Tool toggle: Select vs Draw wire */}
          <div className="flex items-center rounded-lg border border-border/70 bg-background p-0.5 mr-1">
            <button
              onClick={() => {
                setDrawMode(false);
                setWireStart(null);
              }}
              aria-pressed={!drawMode}
              title="Select and move components"
              className={cn(
                "inline-flex items-center gap-1 rounded-md px-2 py-1.5 text-xs font-semibold transition",
                !drawMode
                  ? "bg-emerald-500/20 text-emerald-300 shadow-inner"
                  : "text-muted-foreground hover:text-foreground",
              )}
            >
              <MousePointer2 className="h-3.5 w-3.5" /> Select
            </button>
            <button
              onClick={() => {
                setDrawMode((v) => !v);
                setWireStart(null);
                setSelectedWireId(null);
              }}
              aria-pressed={drawMode}
              title="Draw a jumper wire between two points"
              className={cn(
                "inline-flex items-center gap-1 rounded-md px-2 py-1.5 text-xs font-semibold transition",
                drawMode
                  ? "bg-emerald-500/20 text-emerald-300 shadow-inner"
                  : "text-muted-foreground hover:text-foreground",
              )}
            >
              <Spline className="h-3.5 w-3.5" /> Draw wire
            </button>
          </div>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-led");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-led")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <div className="h-2.5 w-2.5 rounded-full bg-red-500 shadow-sm" />+ LED
          </button>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-pushbutton");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-pushbutton")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <div className="h-2.5 w-2.5 rounded-sm bg-blue-500 shadow-sm" />+ Push Button
          </button>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-potentiometer");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-potentiometer")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <Sliders className="h-3.5 w-3.5 text-amber-500" />+ Potentiometer
          </button>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-buzzer");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-buzzer")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <Volume2 className="h-3.5 w-3.5 text-sky-400" />+ Buzzer
          </button>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-servo");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-servo")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <RotateCcw className="h-3.5 w-3.5 text-rose-400" />+ SG90 Servo
          </button>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-hc-sr04");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-hc-sr04")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <Sparkles className="h-3.5 w-3.5 text-teal-400" />+ Sonar
          </button>
          <button
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData("text/miow-part", "wokwi-resistor");
              e.dataTransfer.effectAllowed = "copy";
            }}
            onClick={() => addPart("wokwi-resistor")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border/70 bg-background px-2.5 py-1.5 text-xs font-semibold text-foreground transition hover:bg-muted cursor-grab active:cursor-grabbing"
            title="Click to add, or drag onto the workbench"
          >
            <span className="font-mono text-amber-600 font-bold">220Ω</span>+ Resistor
          </button>
        </div>

        {selectedPart && !drawMode && (
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

        {drawMode && (
          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded-md border border-emerald-500/40 bg-emerald-500/10 px-2 py-1 text-[11px] font-semibold text-emerald-300">
              {wireStart
                ? "Click a second point to finish — Esc to cancel"
                : "Click a point to start the wire"}
            </span>
            <div className="flex items-center gap-1">
              {WIRE_COLORS.map((w) => (
                <button
                  key={w.name}
                  onClick={() => setDrawColor(w.stroke)}
                  className={cn(
                    "h-3.5 w-3.5 rounded-full transition-transform",
                    drawColor === w.stroke
                      ? "scale-125 ring-2 ring-white"
                      : "opacity-80 hover:opacity-100",
                  )}
                  style={{ backgroundColor: w.stroke }}
                  title={`${w.name} wire`}
                />
              ))}
            </div>
          </div>
        )}

        {selectedWireId && !drawMode && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">
              Selected: <strong className="text-foreground">Jumper wire</strong>
            </span>
            <button
              onClick={() => removeWire(selectedWireId)}
              className="inline-flex items-center gap-1 rounded-lg border border-rose-500/30 bg-rose-500/10 px-2.5 py-1.5 text-xs font-semibold text-rose-400 hover:bg-rose-500/20 transition"
              title="Delete wire"
            >
              <Trash2 className="h-3.5 w-3.5" /> Remove wire
            </button>
          </div>
        )}
      </div>

      {/* Main Interactive Circuit Sandbox with Realistic Jumper Wires */}
      <div
        ref={containerRef}
        onClick={handleCanvasClick}
        onMouseMove={(e) => {
          if (drawMode && wireStart) setCursorPos(localPoint(e));
        }}
        onDragOver={(e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = "copy";
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          const type = e.dataTransfer.getData("text/miow-part") as WokwiComponentType;
          if (!type) return;
          const rect = containerRef.current?.getBoundingClientRect();
          const x = rect ? e.clientX - rect.left : 350;
          const y = rect ? e.clientY - rect.top : 60;
          // Clamp so the dropped part stays inside the workbench
          addPart(type, {
            x: Math.max(10, Math.min(x - 35, (rect?.width ?? 800) - 100)),
            y: Math.max(10, Math.min(y - 35, (rect?.height ?? 580) - 100)),
          });
        }}
        className={cn(
          "relative min-h-[580px] w-full select-none overflow-hidden rounded-2xl border-2 shadow-2xl",
          dragOver ? "border-emerald-400 ring-2 ring-emerald-400/40" : "border-emerald-900/60",
          drawMode && "cursor-crosshair",
        )}
        style={{
          backgroundImage: `
            radial-gradient(circle, rgba(148, 163, 184, 0.22) 1.5px, transparent 1.5px),
            radial-gradient(circle, rgba(148, 163, 184, 0.08) 1.5px, transparent 1.5px)
          `,
          backgroundSize: "28px 28px",
          backgroundPosition: "0 0, 14px 14px",
          backgroundColor: "#090d16",
        }}
      >
        {/* Real-time SVG JUMPER WIRES connecting Uno to Components */}
        <svg className="pointer-events-none absolute inset-0 h-full w-full z-10">
          <defs>
            <filter id="wire-glow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="2" result="blur" />
              <feComposite in="SourceGraphic" in2="blur" operator="over" />
            </filter>
          </defs>
          {parts.map((p) => {
            const start = getUnoHeaderPinCoord(p.connectedPin);
            // Component center terminal
            const end = { x: p.x + 35, y: p.y + 35 };

            // Natural curved bezier jumper wire
            const midX = (start.x + end.x) / 2;
            const midY = Math.min(start.y, end.y) - 30;
            const pathData = `M ${start.x} ${start.y} Q ${midX} ${midY} ${end.x} ${end.y}`;

            const wireColor = p.wireColor || "#10b981";

            return (
              <g key={`wire-${p.id}`}>
                {/* Outer shadow / insulated sleeve */}
                <path
                  d={pathData}
                  fill="none"
                  stroke="#000000"
                  strokeWidth="5"
                  strokeOpacity="0.4"
                  strokeLinecap="round"
                />
                {/* Colored Insulated Jumper Wire */}
                <path
                  d={pathData}
                  fill="none"
                  stroke={wireColor}
                  strokeWidth="3.2"
                  strokeLinecap="round"
                  filter="url(#wire-glow)"
                />
                {/* Metal Terminal Pin Ends */}
                <circle
                  cx={start.x}
                  cy={start.y}
                  r="3"
                  fill="#cbd5e1"
                  stroke="#475569"
                  strokeWidth="1"
                />
                <circle
                  cx={end.x}
                  cy={end.y}
                  r="3"
                  fill="#cbd5e1"
                  stroke="#475569"
                  strokeWidth="1"
                />
              </g>
            );
          })}

          {/* User-drawn jumper wires (clickable — deletable) */}
          {userWires.map((w) => {
            const midX = (w.x1 + w.x2) / 2;
            const midY = Math.min(w.y1, w.y2) - 30;
            const pathData = `M ${w.x1} ${w.y1} Q ${midX} ${midY} ${w.x2} ${w.y2}`;
            const isSelected = w.id === selectedWireId;
            return (
              <g
                key={w.id}
                onClick={(e) => {
                  if (drawMode) return;
                  e.stopPropagation();
                  setSelectedWireId(w.id);
                  setSelectedId(null);
                }}
                style={{
                  pointerEvents: drawMode ? "none" : "stroke",
                  cursor: drawMode ? "inherit" : "pointer",
                }}
              >
                <path
                  d={pathData}
                  fill="none"
                  stroke="#000000"
                  strokeWidth={isSelected ? "7" : "5"}
                  strokeOpacity="0.4"
                  strokeLinecap="round"
                />
                <path
                  d={pathData}
                  fill="none"
                  stroke={w.color}
                  strokeWidth={isSelected ? "4.5" : "3.2"}
                  strokeLinecap="round"
                  filter="url(#wire-glow)"
                />
                <circle cx={w.x1} cy={w.y1} r="3" fill="#cbd5e1" stroke="#475569" strokeWidth="1" />
                <circle cx={w.x2} cy={w.y2} r="3" fill="#cbd5e1" stroke="#475569" strokeWidth="1" />
              </g>
            );
          })}

          {/* Live rubber-band preview while routing a wire */}
          {drawMode && wireStart && cursorPos && (
            <g style={{ pointerEvents: "none" }}>
              <path
                d={`M ${wireStart.x} ${wireStart.y} Q ${(wireStart.x + cursorPos.x) / 2} ${Math.min(wireStart.y, cursorPos.y) - 30} ${cursorPos.x} ${cursorPos.y}`}
                fill="none"
                stroke={drawColor}
                strokeWidth="3"
                strokeDasharray="6 4"
                strokeOpacity="0.85"
                strokeLinecap="round"
              />
              <circle cx={wireStart.x} cy={wireStart.y} r="4" fill={drawColor} />
            </g>
          )}
        </svg>

        {/* Workbench Watermark Badge */}
        <div className="pointer-events-none absolute right-4 top-4 flex items-center gap-2 rounded-lg bg-slate-900/90 px-3 py-1 font-mono text-[11px] text-slate-300 border border-slate-700/80 shadow-md z-30">
          <Zap className="h-3.5 w-3.5 text-amber-400" />
          <span>Interactive Jumper Wire &amp; Hardware Workbench</span>
        </div>

        {/* 1. ARDUINO UNO BOARD (Scalable & Draggable) */}
        <div
          onMouseDown={(e) => handleMouseDown(e, "arduino-uno")}
          style={{
            left: unoPos.x,
            top: unoPos.y,
            transform: "scale(0.85)",
            transformOrigin: "top left",
          }}
          className={cn(
            "absolute cursor-grab active:cursor-grabbing select-none transition-shadow z-20 p-1 rounded-xl",
            selectedId === "arduino-uno" && "ring-2 ring-emerald-400 shadow-2xl",
          )}
          title="Draggable Arduino Uno R3"
        >
          {React.createElement("wokwi-arduino-uno", {
            led13: boardState?.builtinLed === 1,
            ledPower: isRunning,
            ledRX: false,
            ledTX: false,
          })}
          <div className="mt-1 flex items-center justify-between px-2 text-[10px] font-mono text-slate-400 bg-slate-900/90 rounded border border-slate-800">
            <span>Arduino Uno R3</span>
            <span className={cn("font-bold", isRunning ? "text-emerald-400" : "text-slate-500")}>
              {isRunning ? "PWR ON" : "STANDBY"}
            </span>
          </div>
        </div>

        {/* 2. REAL PHYSICAL HARDWARE COMPONENTS WITH LIVE JUMPER TERMINALS */}
        {parts.map((p) => {
          const isSelected = p.id === selectedId;
          const isDigital = p.connectedPin <= 13;
          const pinVal = isDigital
            ? (boardState?.digital[p.connectedPin]?.digitalValue ?? 0)
            : (boardState?.analog[p.connectedPin - 14]?.digitalValue ?? 0);
          const isHigh = pinVal === 1;

          const servoPwm = boardState?.digital[p.connectedPin]?.analogValue ?? 0;
          const servoAngle = Math.round((servoPwm / 255) * 180);

          return (
            <div
              key={p.id}
              onMouseDown={(e) => handleMouseDown(e, p.id)}
              style={{ left: p.x, top: p.y }}
              className={cn(
                "absolute cursor-grab active:cursor-grabbing select-none rounded-xl p-2 transition-shadow z-20 group",
                isSelected
                  ? "ring-2 ring-emerald-400 bg-slate-900/80 shadow-2xl border border-emerald-500/50"
                  : "hover:ring-1 hover:ring-slate-500/50 hover:bg-slate-900/40",
              )}
            >
              {/* Wiring Badge & Jumper Pin Connection */}
              <div className="mb-1 flex items-center justify-between gap-2 px-1 text-[10px] font-mono">
                <span className="rounded bg-slate-800/90 px-1.5 py-0.2 text-slate-300 font-semibold border border-slate-700">
                  {p.label}
                </span>
                <span
                  className="rounded px-1.5 py-0.2 font-bold border text-black shadow-sm"
                  style={{
                    backgroundColor: p.wireColor || "#10b981",
                    borderColor: p.wireColor || "#10b981",
                  }}
                >
                  {p.connectedPin >= 14 ? `A${p.connectedPin - 14}` : `D${p.connectedPin}`}
                </span>
              </div>

              {/* Real Wokwi Component Rendering */}
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
                      {p.value ?? 512} ({(((p.value ?? 512) / 1023) * 5.0).toFixed(2)}V)
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

              {/* Wire & Pin Inspector Box */}
              {isSelected && (
                <div
                  onClick={(e) => e.stopPropagation()}
                  className="mt-1 flex flex-col gap-1.5 rounded-lg border border-slate-700 bg-slate-900/95 p-2 text-[11px] backdrop-blur-md shadow-lg"
                >
                  <div className="flex items-center justify-between gap-1.5">
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
                  </div>

                  {/* Wire Color Picker */}
                  <div className="flex items-center justify-between gap-1 pt-1 border-t border-slate-800">
                    <span className="text-[10px] text-slate-400 font-mono">Wire:</span>
                    <div className="flex items-center gap-1">
                      {WIRE_COLORS.map((w) => (
                        <button
                          key={w.name}
                          onClick={() => updateWireColor(p.id, w.stroke)}
                          className={cn(
                            "h-3.5 w-3.5 rounded-full transition-transform",
                            p.wireColor === w.stroke
                              ? "scale-125 ring-2 ring-white"
                              : "opacity-80 hover:opacity-100",
                          )}
                          style={{ backgroundColor: w.stroke }}
                          title={`${w.name} Wire`}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="flex items-center gap-2 text-xs text-muted-foreground">
        <Info className="h-3.5 w-3.5 text-primary" />
        <span>
          Select mode: drag components to route wires, click one to set its Arduino pin (D0–D13 /
          A0–A5) or wire color, and click a wire to remove it. Draw wire mode: click two points to
          route a new jumper wire (Esc cancels). Parts can be dragged from the palette onto the
          workbench.
        </span>
      </div>
    </div>
  );
}
