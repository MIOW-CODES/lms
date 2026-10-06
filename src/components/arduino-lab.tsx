import { useEffect, useRef, useState } from "react";
import {
  Play,
  Square,
  RotateCcw,
  Terminal,
  Cpu,
  Zap,
  Volume2,
  Sliders,
  Code2,
  Sparkles,
  Copy,
  Check,
} from "lucide-react";
import { ArduinoSimulator, type ArduinoBoardState } from "@/lib/arduino-simulator";
import { cn } from "@/lib/utils";

const STARTER_SKETCHES = [
  {
    title: "1. LED Blink (Pin 13)",
    description: "The classic 'Hello World' of hardware: toggle the onboard LED on and off.",
    code: `// Pin 13 has the built-in LED on most Arduino boards
const int ledPin = 13;

void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(9600);
  Serial.println("Blink program initialized!");
}

void loop() {
  digitalWrite(ledPin, HIGH);   // turn the LED on
  Serial.println("LED ON");
  delay(500);                  // wait 500 ms
  
  digitalWrite(ledPin, LOW);    // turn the LED off
  Serial.println("LED OFF");
  delay(500);                  // wait 500 ms
}
`,
  },
  {
    title: "2. Analog Sensor / Potentiometer Reader",
    description: "Read analog values from A0 and map them to a 0-100 percentage range.",
    code: `// Analog Sensor Reading & Mapping
const int sensorPin = A0;
const int ledPin = 13;

void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(9600);
  Serial.println("Analog Reader Ready. Adjust slider A0 below!");
}

void loop() {
  int sensorValue = analogRead(sensorPin);
  int percent = map(sensorValue, 0, 1023, 0, 100);
  
  Serial.print("ADC: ");
  Serial.print(sensorValue);
  Serial.print(" | Level: ");
  Serial.print(percent);
  Serial.println("%");
  
  if (percent > 50) {
    digitalWrite(ledPin, HIGH);
  } else {
    digitalWrite(ledPin, LOW);
  }
  
  delay(300);
}
`,
  },
  {
    title: "3. Piezo Buzzer & Tone Alert",
    description: "Generate audible frequency tones and melodies on the buzzer pin.",
    code: `// Piezo Buzzer Simulation
const int buzzerPin = 8;

void setup() {
  Serial.begin(9600);
  Serial.println("Piezo Buzzer Test ready!");
}

void loop() {
  // Beep 1
  tone(buzzerPin, 880); // A5 note
  Serial.println("Tone: 880Hz");
  delay(200);
  noTone();
  delay(100);

  // Beep 2
  tone(buzzerPin, 1760); // A6 note
  Serial.println("Tone: 1760Hz");
  delay(200);
  noTone();
  delay(600);
}
`,
  },
  {
    title: "4. Multi-Pin Knight Rider Chaser",
    description: "Sequence digital output pins 2 through 7 in a chasing sweep pattern.",
    code: `// Multi-Pin LED Chaser (Pins 2 to 7)
int timer = 100;

void setup() {
  for (int thisPin = 2; thisPin < 8; thisPin++) {
    pinMode(thisPin, OUTPUT);
  }
  Serial.begin(9600);
  Serial.println("Chaser Running!");
}

void loop() {
  for (int thisPin = 2; thisPin < 8; thisPin++) {
    digitalWrite(thisPin, HIGH);
    delay(timer);
    digitalWrite(thisPin, LOW);
  }
  for (int thisPin = 6; thisPin >= 3; thisPin--) {
    digitalWrite(thisPin, HIGH);
    delay(timer);
    digitalWrite(thisPin, LOW);
  }
}
`,
  },
];

export function ArduinoLab() {
  const [selectedSketch, setSelectedSketch] = useState(0);
  const [code, setCode] = useState(STARTER_SKETCHES[0].code);
  const [logs, setLogs] = useState<string[]>([]);
  const [boardState, setBoardState] = useState<ArduinoBoardState | null>(null);
  const [isRunning, setIsRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  // Sliders for Analog Inputs A0-A5
  const [analogValues, setAnalogValues] = useState<number[]>([512, 0, 0, 0, 0, 0]);

  const simRef = useRef<ArduinoSimulator | null>(null);
  const serialEndRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const sim = new ArduinoSimulator();
    simRef.current = sim;

    sim.setSubscriber((state, newLog) => {
      setBoardState(state);
      if (newLog) {
        setLogs((prev) => [...prev.slice(-300), newLog]);
      }
    });

    return () => {
      sim.stop();
    };
  }, []);

  useEffect(() => {
    serialEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [logs]);

  const handleRun = () => {
    setError(null);
    if (!simRef.current) return;
    const res = simRef.current.runCode(code);
    if (res.success) {
      setIsRunning(true);
      // restore analog inputs
      analogValues.forEach((val, i) => {
        simRef.current?.setAnalogInput(i, val);
      });
    } else {
      setError(res.error || "Execution failed");
      setIsRunning(false);
    }
  };

  const handleStop = () => {
    if (!simRef.current) return;
    simRef.current.stop();
    setIsRunning(false);
  };

  const handleReset = () => {
    if (!simRef.current) return;
    simRef.current.reset();
    setIsRunning(false);
    setLogs([]);
    setError(null);
  };

  const handleAnalogChange = (pinIndex: number, val: number) => {
    const updated = [...analogValues];
    updated[pinIndex] = val;
    setAnalogValues(updated);
    if (simRef.current) {
      simRef.current.setAnalogInput(pinIndex, val);
    }
  };

  const handleDigitalToggle = (pinNumber: number) => {
    if (!boardState || !simRef.current) return;
    const current = boardState.digital[pinNumber]?.digitalValue ?? 0;
    const next = current === 1 ? 0 : 1;
    simRef.current.setDigitalInput(pinNumber, next);
  };

  const handleSelectExample = (index: number) => {
    handleStop();
    setSelectedSketch(index);
    setCode(STARTER_SKETCHES[index].code);
    setLogs([]);
    setError(null);
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-6">
      {/* Header & Controls Bar */}
      <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-border/70 bg-card/60 p-4 shadow-sm backdrop-blur-md">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <Cpu className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-base font-bold text-foreground">Arduino Uno Virtual Lab</h2>
            <p className="text-xs text-muted-foreground">
              ATmega328P Emulated Environment · Real-time Pin I/O &amp; Serial Monitor
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {isRunning ? (
            <button
              onClick={handleStop}
              className="inline-flex items-center gap-1.5 rounded-xl bg-destructive px-4 py-2 text-sm font-semibold text-destructive-foreground shadow transition hover:opacity-90"
            >
              <Square className="h-4 w-4" /> Stop Simulation
            </button>
          ) : (
            <button
              onClick={handleRun}
              className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow transition hover:bg-emerald-500"
            >
              <Play className="h-4 w-4" /> Start Simulation
            </button>
          )}

          <button
            onClick={handleReset}
            className="inline-flex items-center gap-1.5 rounded-xl border border-border bg-card px-3 py-2 text-sm font-medium text-muted-foreground transition hover:bg-muted hover:text-foreground"
            title="Reset Board &amp; Memory"
          >
            <RotateCcw className="h-4 w-4" /> Reset
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 p-4 text-sm text-rose-400">
          <span className="font-semibold">Compiler / Runtime Warning:</span> {error}
        </div>
      )}

      {/* Main Grid: Code Editor on Left, Hardware Simulation on Right */}
      <div className="grid gap-6 lg:grid-cols-12">
        {/* Left Column: Code Editor & Starter Sketches (7 cols) */}
        <div className="space-y-4 lg:col-span-7">
          <div className="rounded-2xl border border-border/80 bg-card/80 p-4 shadow-sm backdrop-blur-md">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2 border-b border-border/60 pb-3">
              <div className="flex items-center gap-2">
                <Code2 className="h-4 w-4 text-primary" />
                <span className="text-sm font-semibold text-foreground">sketch.ino</span>
                <span className="text-xs text-muted-foreground font-mono">(C++ / Arduino)</span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleCopy}
                  className="flex items-center gap-1 rounded-lg px-2 py-1 text-xs text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
                >
                  {copied ? <Check className="h-3.5 w-3.5 text-emerald-500" /> : <Copy className="h-3.5 w-3.5" />}
                  <span>{copied ? "Copied" : "Copy"}</span>
                </button>
              </div>
            </div>

            {/* Sketch selector pills */}
            <div className="mb-3 flex flex-wrap gap-1.5">
              {STARTER_SKETCHES.map((sk, idx) => (
                <button
                  key={sk.title}
                  onClick={() => handleSelectExample(idx)}
                  className={cn(
                    "rounded-lg px-2.5 py-1 text-xs font-medium transition",
                    selectedSketch === idx
                      ? "bg-primary text-primary-foreground font-semibold"
                      : "bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground",
                  )}
                >
                  {sk.title}
                </button>
              ))}
            </div>

            {/* Code text area with mono font */}
            <div className="relative">
              <textarea
                value={code}
                onChange={(e) => setCode(e.target.value)}
                spellCheck={false}
                rows={16}
                className="w-full resize-y rounded-xl border border-input bg-zinc-950 p-3.5 font-mono text-xs text-zinc-100 outline-none transition focus:ring-2 focus:ring-ring leading-relaxed"
                placeholder="// Type or paste your Arduino C++ sketch here..."
              />
            </div>
            <p className="mt-2 text-right text-[11px] text-muted-foreground">
              Tip: Supports digitalRead, digitalWrite, analogRead, analogWrite, pinMode, tone, delay, Serial
            </p>
          </div>

          {/* Serial Monitor */}
          <div className="rounded-2xl border border-border/80 bg-card/80 p-4 shadow-sm backdrop-blur-md">
            <div className="mb-2 flex items-center justify-between border-b border-border/60 pb-2">
              <div className="flex items-center gap-2">
                <Terminal className="h-4 w-4 text-emerald-400" />
                <span className="text-sm font-semibold text-foreground">Serial Monitor</span>
                <span className="text-xs text-muted-foreground font-mono">9600 baud</span>
              </div>
              <button
                onClick={() => setLogs([])}
                className="text-xs text-muted-foreground hover:text-foreground transition"
              >
                Clear
              </button>
            </div>
            <div className="h-36 overflow-y-auto rounded-xl border border-input bg-zinc-950 p-3 font-mono text-xs text-emerald-400 shadow-inner">
              {logs.length === 0 ? (
                <span className="text-zinc-600">// Serial output will appear here when running...</span>
              ) : (
                logs.map((line, i) => (
                  <div key={i} className="whitespace-pre-wrap leading-tight">
                    {line}
                  </div>
                ))
              )}
              <div ref={serialEndRef} />
            </div>
          </div>
        </div>

        {/* Right Column: Interactive Arduino Hardware Board (5 cols) */}
        <div className="space-y-4 lg:col-span-5">
          {/* Virtual Board Card */}
          <div className="rounded-2xl border border-border/80 bg-card/80 p-5 shadow-sm backdrop-blur-md">
            <div className="mb-4 flex items-center justify-between border-b border-border/60 pb-3">
              <div className="flex items-center gap-2">
                <Zap className="h-4 w-4 text-amber-500" />
                <span className="font-bold text-foreground">Arduino Uno Board</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span
                  className={cn(
                    "inline-block h-2 w-2 rounded-full",
                    isRunning ? "bg-emerald-500 animate-pulse" : "bg-zinc-600",
                  )}
                />
                <span className="text-xs font-mono text-muted-foreground">
                  {isRunning ? "POWER ON" : "STANDBY"}
                </span>
              </div>
            </div>

            {/* Board Surface */}
            <div className="relative rounded-2xl border-2 border-teal-700/60 bg-teal-950/70 p-4 text-teal-100 shadow-inner">
              {/* Header Label on PCB */}
              <div className="flex items-center justify-between border-b border-teal-800/80 pb-2 font-mono text-[11px] text-teal-300">
                <span>MADE FOR MIOW-LMS</span>
                <span className="font-bold text-teal-200">UNO R3</span>
              </div>

              {/* Status LEDs Area: Built-in LED (13) and Power LED */}
              <div className="my-4 grid grid-cols-2 gap-3 rounded-xl border border-teal-800/80 bg-teal-900/40 p-3">
                <div className="flex items-center gap-3">
                  <div
                    className={cn(
                      "h-4 w-4 rounded-full border border-amber-300 transition-all duration-75 shadow-md",
                      boardState?.builtinLed === 1
                        ? "bg-amber-400 shadow-amber-400/80 ring-4 ring-amber-400/30"
                        : "bg-amber-950/60 border-amber-900",
                    )}
                  />
                  <div className="text-xs font-mono">
                    <p className="font-bold text-amber-300">PIN 13 (L)</p>
                    <p className="text-[10px] text-teal-400">
                      {boardState?.builtinLed === 1 ? "HIGH (ON)" : "LOW (OFF)"}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div
                    className={cn(
                      "h-4 w-4 rounded-full border border-emerald-300 transition-all shadow-md",
                      isRunning
                        ? "bg-emerald-400 shadow-emerald-400/80 ring-4 ring-emerald-400/30"
                        : "bg-emerald-950/60 border-emerald-900",
                    )}
                  />
                  <div className="text-xs font-mono">
                    <p className="font-bold text-emerald-300">ON (PWR)</p>
                    <p className="text-[10px] text-teal-400">{isRunning ? "5.0V Active" : "No Power"}</p>
                  </div>
                </div>
              </div>

              {/* Buzzer Tone indicator */}
              <div className="mb-4 flex items-center justify-between rounded-xl border border-teal-800/80 bg-teal-900/30 p-2.5 font-mono text-xs">
                <div className="flex items-center gap-2 text-teal-200">
                  <Volume2 className="h-4 w-4 text-sky-400" />
                  <span>Piezo Buzzer</span>
                </div>
                <div className="font-bold text-sky-300">
                  {boardState?.buzzerTone ? (
                    <span className="animate-pulse">{boardState.buzzerTone} Hz</span>
                  ) : (
                    <span className="text-teal-600">Muted</span>
                  )}
                </div>
              </div>

              {/* Digital Pins (0 to 13) */}
              <div className="space-y-1.5">
                <p className="font-mono text-[11px] font-semibold text-teal-300">DIGITAL PINS (0–13)</p>
                <div className="grid grid-cols-7 gap-1.5 text-center font-mono text-[10px]">
                  {[13, 12, 11, 10, 9, 8, 7].map((pin) => {
                    const st = boardState?.digital[pin];
                    const isHigh = st?.digitalValue === 1;
                    return (
                      <button
                        key={pin}
                        onClick={() => handleDigitalToggle(pin)}
                        className={cn(
                          "flex flex-col items-center justify-center rounded-lg border p-1.5 transition",
                          isHigh
                            ? "border-amber-400 bg-amber-500/20 text-amber-200"
                            : "border-teal-800 bg-teal-900/40 text-teal-400 hover:border-teal-700",
                        )}
                        title={`Pin ${pin} (${st?.mode || "INPUT"}): ${isHigh ? "HIGH" : "LOW"}. Click to toggle input.`}
                      >
                        <span className="font-bold">{pin}</span>
                        <span
                          className={cn(
                            "mt-1 h-2 w-2 rounded-full",
                            isHigh ? "bg-amber-400 shadow-sm" : "bg-zinc-700",
                          )}
                        />
                      </button>
                    );
                  })}
                </div>
                <div className="grid grid-cols-7 gap-1.5 text-center font-mono text-[10px]">
                  {[6, 5, 4, 3, 2, 1, 0].map((pin) => {
                    const st = boardState?.digital[pin];
                    const isHigh = st?.digitalValue === 1;
                    return (
                      <button
                        key={pin}
                        onClick={() => handleDigitalToggle(pin)}
                        className={cn(
                          "flex flex-col items-center justify-center rounded-lg border p-1.5 transition",
                          isHigh
                            ? "border-amber-400 bg-amber-500/20 text-amber-200"
                            : "border-teal-800 bg-teal-900/40 text-teal-400 hover:border-teal-700",
                        )}
                        title={`Pin ${pin} (${st?.mode || "INPUT"}): ${isHigh ? "HIGH" : "LOW"}. Click to toggle input.`}
                      >
                        <span className="font-bold">{pin}</span>
                        <span
                          className={cn(
                            "mt-1 h-2 w-2 rounded-full",
                            isHigh ? "bg-amber-400 shadow-sm" : "bg-zinc-700",
                          )}
                        />
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>

          {/* Analog Inputs Control (A0–A5) */}
          <div className="rounded-2xl border border-border/80 bg-card/80 p-5 shadow-sm backdrop-blur-md">
            <div className="mb-3 flex items-center justify-between border-b border-border/60 pb-2">
              <div className="flex items-center gap-2">
                <Sliders className="h-4 w-4 text-primary" />
                <span className="font-semibold text-foreground text-sm">Analog Inputs (A0–A5 Potentiometers)</span>
              </div>
              <span className="text-[11px] font-mono text-muted-foreground">0–1023 ADC</span>
            </div>

            <div className="space-y-3">
              {[0, 1, 2].map((pinIndex) => (
                <div key={pinIndex} className="space-y-1">
                  <div className="flex items-center justify-between text-xs font-mono">
                    <span className="font-bold text-foreground">Pin A{pinIndex}</span>
                    <span className="text-muted-foreground">
                      {analogValues[pinIndex]} / 1023 (
                      {((analogValues[pinIndex] / 1023) * 5.0).toFixed(2)}V)
                    </span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="1023"
                    value={analogValues[pinIndex]}
                    onChange={(e) => handleAnalogChange(pinIndex, Number(e.target.value))}
                    className="h-1.5 w-full cursor-pointer appearance-none rounded-lg bg-muted accent-primary"
                  />
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
