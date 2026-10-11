/**
 * Seeded lab tasks with ghost wiring guides (Tinkercad-style).
 *
 * Selecting a task places the needed PARTS (unwired) and shows a dashed
 * "ghost" overlay of the expected circuit. Students still place every
 * jumper wire manually — there are never any pre-placed solid wires.
 */
import type { CircuitPartType, WireEndpoint } from "./arduino-simulator";

export interface TaskSeedPart {
  key: string;
  type: CircuitPartType;
  label: string;
  x: number;
  y: number;
  color?: string;
}

export interface TaskGuide {
  from: WireEndpoint;
  to: WireEndpoint;
}

export interface ArduinoTask {
  id: string;
  chip: string;
  title: string;
  hint: string;
  parts: TaskSeedPart[];
  guides: TaskGuide[];
}

const taskTerm = (key: string, terminal: string): WireEndpoint => ({
  kind: "part",
  partId: `task-${key}`,
  terminal,
});
const uno = (pin: number | "5V" | "3V3" | "GND"): WireEndpoint => ({ kind: "uno", pin });

export const ARDUINO_TASKS: ArduinoTask[] = [
  {
    id: "traffic-light",
    chip: "Task A · Traffic light (D8/D9/D10)",
    title: "Simulation Task A — Traffic Light",
    hint:
      "Red LED → D8, yellow LED → D9, green LED → D10 — each cathode through its own 220Ω resistor to GND. " +
      "The dashed guide shows where each jumper wire goes; click a terminal, then its destination, to place the wire yourself.",
    parts: [
      { key: "led-r", type: "wokwi-led", label: "LED1", x: 470, y: 70, color: "red" },
      { key: "led-y", type: "wokwi-led", label: "LED2", x: 610, y: 70, color: "yellow" },
      { key: "led-g", type: "wokwi-led", label: "LED3", x: 750, y: 70, color: "green" },
      { key: "res-r", type: "wokwi-resistor", label: "resistor1", x: 460, y: 250 },
      { key: "res-y", type: "wokwi-resistor", label: "resistor2", x: 600, y: 250 },
      { key: "res-g", type: "wokwi-resistor", label: "resistor3", x: 740, y: 250 },
    ],
    guides: [
      { from: taskTerm("led-r", "A"), to: uno(8) },
      { from: taskTerm("led-r", "K"), to: taskTerm("res-r", "leg1") },
      { from: taskTerm("res-r", "leg2"), to: uno("GND") },
      { from: taskTerm("led-y", "A"), to: uno(9) },
      { from: taskTerm("led-y", "K"), to: taskTerm("res-y", "leg1") },
      { from: taskTerm("res-y", "leg2"), to: uno("GND") },
      { from: taskTerm("led-g", "A"), to: uno(10) },
      { from: taskTerm("led-g", "K"), to: taskTerm("res-g", "leg1") },
      { from: taskTerm("res-g", "leg2"), to: uno("GND") },
    ],
  },
  {
    id: "button-led",
    chip: "Task B · Button D2 + LED D13 + Serial",
    title: "Simulation Task B — Button-Controlled LED",
    hint:
      "Pushbutton between D2 and GND (INPUT_PULLUP), LED anode → D13 with a 220Ω resistor from the cathode to GND. " +
      "Place each jumper wire manually following the dashed guide, then print the button state over Serial.",
    parts: [
      { key: "btn", type: "wokwi-pushbutton", label: "button1", x: 470, y: 90, color: "blue" },
      { key: "led", type: "wokwi-led", label: "LED1", x: 660, y: 90, color: "red" },
      { key: "res", type: "wokwi-resistor", label: "resistor1", x: 650, y: 260 },
    ],
    guides: [
      { from: taskTerm("btn", "leg1"), to: uno(2) },
      { from: taskTerm("btn", "leg2"), to: uno("GND") },
      { from: taskTerm("led", "A"), to: uno(13) },
      { from: taskTerm("led", "K"), to: taskTerm("res", "leg1") },
      { from: taskTerm("res", "leg2"), to: uno("GND") },
    ],
  },
];
