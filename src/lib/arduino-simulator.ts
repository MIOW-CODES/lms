/**
 * Virtual Arduino Simulator Engine
 *
 * Implements a lightweight, browser-side Arduino execution environment:
 * - Digital I/O (Pins 0-13, Built-in LED on Pin 13)
 * - Analog Input (A0-A5 with voltage/slider mapping)
 * - PWM outputs (~3, ~5, ~6, ~9, ~10, ~11)
 * - Serial Monitor communication (Serial.begin, print, println, write)
 * - Time utilities (delay, millis, micros)
 * - Common math & utility helpers (map, constrain, random, min, max, abs)
 * - Tone generation simulation (buzzer on pins)
 */

export interface PinState {
  mode: "INPUT" | "OUTPUT" | "INPUT_PULLUP";
  digitalValue: 0 | 1;
  analogValue: number; // 0-1023 for ADC (inputs), 0-255 for PWM (outputs)
  isPwm?: boolean;
}

export interface ArduinoBoardState {
  digital: Record<number, PinState>;
  analog: Record<number, PinState>; // 0..5
  builtinLed: 0 | 1;
  buzzerTone: number | null; // frequency in Hz or null
  millis: number;
}

export interface SimulatorExecutionResult {
  outputLogs: string[];
  boardState: ArduinoBoardState;
  error?: string;
}

export class ArduinoSimulator {
  private board: ArduinoBoardState;
  private logs: string[] = [];
  private isRunning = false;
  private timerId: ReturnType<typeof setInterval> | null = null;
  private tickIntervalMs = 50;
  private speedFactor = 1.0;
  private startTime = 0;
  private simulatedMillis = 0;
  private onStateChange?: (state: ArduinoBoardState, log?: string) => void;

  constructor() {
    this.board = this.createInitialBoardState();
  }

  private createInitialBoardState(): ArduinoBoardState {
    const digital: Record<number, PinState> = {};
    for (let i = 0; i <= 13; i++) {
      digital[i] = {
        mode: "INPUT",
        digitalValue: 0,
        analogValue: 0,
        isPwm: [3, 5, 6, 9, 10, 11].includes(i),
      };
    }
    const analog: Record<number, PinState> = {};
    for (let i = 0; i <= 5; i++) {
      analog[i] = {
        mode: "INPUT",
        digitalValue: 0,
        analogValue: 0,
      };
    }
    return {
      digital,
      analog,
      builtinLed: 0,
      buzzerTone: null,
      millis: 0,
    };
  }

  public reset() {
    this.stop();
    this.board = this.createInitialBoardState();
    this.logs = [];
    this.simulatedMillis = 0;
    this.emitChange();
  }

  public setAnalogInput(pinIndex: number, value0to1023: number) {
    if (this.board.analog[pinIndex]) {
      this.board.analog[pinIndex].analogValue = Math.max(0, Math.min(1023, Math.round(value0to1023)));
      this.board.analog[pinIndex].digitalValue = value0to1023 > 512 ? 1 : 0;
      this.emitChange();
    }
  }

  public setDigitalInput(pinNumber: number, value: 0 | 1) {
    if (this.board.digital[pinNumber]) {
      this.board.digital[pinNumber].digitalValue = value;
      this.emitChange();
    }
  }

  public setSubscriber(fn: (state: ArduinoBoardState, newLog?: string) => void) {
    this.onStateChange = fn;
  }

  private emitChange(newLog?: string) {
    if (this.onStateChange) {
      this.onStateChange({ ...this.board }, newLog);
    }
  }

  public parseAndCompile(cCode: string): { setupCode: string; loopCode: string; globalCode: string } {
    let clean = cCode
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .replace(/\/\/.*$/gm, "");

    const setupMatch = clean.match(/void\s+setup\s*\(\s*\)\s*\{([\s\S]*?)\}/);
    const loopMatch = clean.match(/void\s+loop\s*\(\s*\)\s*\{([\s\S]*?)\}/);

    const setupBody = setupMatch ? setupMatch[1] : "";
    const loopBody = loopMatch ? loopMatch[1] : "";

    let globals = clean
      .replace(/void\s+setup\s*\(\s*\)\s*\{[\s\S]*?\}/, "")
      .replace(/void\s+loop\s*\(\s*\)\s*\{[\s\S]*?\}/, "");

    return {
      setupCode: setupBody,
      loopCode: loopBody,
      globalCode: globals,
    };
  }

  /**
   * Transforms Arduino C++ syntax into browser-executable JavaScript
   */
  public transpileToJS(rawCode: string): string {
    let js = rawCode;

    // Convert type declarations
    js = js.replace(/\b(int|float|double|long|unsigned\s+long|byte|char|bool|boolean|void|String|const\s+\w+)\s+([a-zA-Z0-9_]+)\b/g, "let $2");
    
    // Convert boolean keywords
    js = js.replace(/\bHIGH\b/g, "1");
    js = js.replace(/\bLOW\b/g, "0");
    js = js.replace(/\bOUTPUT\b/g, "'OUTPUT'");
    js = js.replace(/\bINPUT_PULLUP\b/g, "'INPUT_PULLUP'");
    js = js.replace(/\bINPUT\b/g, "'INPUT'");
    js = js.replace(/\bLED_BUILTIN\b/g, "13");

    // Convert Analog pin literals A0..A5
    js = js.replace(/\bA0\b/g, "14");
    js = js.replace(/\bA1\b/g, "15");
    js = js.replace(/\bA2\b/g, "16");
    js = js.replace(/\bA3\b/g, "17");
    js = js.replace(/\bA4\b/g, "18");
    js = js.replace(/\bA5\b/g, "19");

    return js;
  }

  public runCode(code: string): { success: boolean; error?: string } {
    this.reset();
    try {
      const { setupCode, loopCode, globalCode } = this.parseAndCompile(code);
      const transpiledGlobals = this.transpileToJS(globalCode);
      const transpiledSetup = this.transpileToJS(setupCode);
      const transpiledLoop = this.transpileToJS(loopCode);

      const sandboxEnv = this.createRuntimeSandbox();

      const runnerCode = `
        ${transpiledGlobals}

        function setup() {
          ${transpiledSetup}
        }

        function loop() {
          ${transpiledLoop}
        }

        return { setup, loop };
      `;

      const fn = new Function(
        "pinMode",
        "digitalWrite",
        "digitalRead",
        "analogRead",
        "analogWrite",
        "tone",
        "noTone",
        "delay",
        "millis",
        "micros",
        "map",
        "constrain",
        "min",
        "max",
        "abs",
        "random",
        "Serial",
        runnerCode
      );

      const userProgram = fn(
        sandboxEnv.pinMode,
        sandboxEnv.digitalWrite,
        sandboxEnv.digitalRead,
        sandboxEnv.analogRead,
        sandboxEnv.analogWrite,
        sandboxEnv.tone,
        sandboxEnv.noTone,
        sandboxEnv.delay,
        sandboxEnv.millis,
        sandboxEnv.micros,
        sandboxEnv.map,
        sandboxEnv.constrain,
        sandboxEnv.min,
        sandboxEnv.max,
        sandboxEnv.abs,
        sandboxEnv.random,
        sandboxEnv.Serial
      );

      this.isRunning = true;
      this.startTime = Date.now();

      // Run setup
      if (typeof userProgram.setup === "function") {
        userProgram.setup();
        this.emitChange();
      }

      // Start loop loop timer
      this.timerId = setInterval(() => {
        if (!this.isRunning) return;
        try {
          this.simulatedMillis += Math.round(this.tickIntervalMs * this.speedFactor);
          this.board.millis = this.simulatedMillis;
          if (typeof userProgram.loop === "function") {
            userProgram.loop();
          }
          this.emitChange();
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          this.stop();
          this.log(`Runtime Error in loop: ${msg}`);
          this.emitChange(`[Error] ${msg}`);
        }
      }, this.tickIntervalMs);

      return { success: true };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      this.stop();
      this.log(`Compile Error: ${msg}`);
      return { success: false, error: msg };
    }
  }

  public stop() {
    this.isRunning = false;
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
    this.board.buzzerTone = null;
    this.emitChange();
  }

  public getLogs(): string[] {
    return [...this.logs];
  }

  private log(message: string) {
    this.logs.push(message);
    if (this.logs.length > 500) this.logs.shift();
    this.emitChange(message);
  }

  private createRuntimeSandbox() {
    const self = this;

    const pinMode = (pin: number, mode: "INPUT" | "OUTPUT" | "INPUT_PULLUP") => {
      const pinNum = Number(pin);
      if (pinNum >= 0 && pinNum <= 13) {
        self.board.digital[pinNum].mode = mode;
      }
    };

    const digitalWrite = (pin: number, val: 0 | 1 | boolean | number) => {
      const pinNum = Number(pin);
      const v: 0 | 1 = val ? 1 : 0;
      if (pinNum >= 0 && pinNum <= 13) {
        self.board.digital[pinNum].digitalValue = v;
        if (pinNum === 13) {
          self.board.builtinLed = v;
        }
      }
    };

    const digitalRead = (pin: number): number => {
      const pinNum = Number(pin);
      if (pinNum >= 0 && pinNum <= 13) {
        return self.board.digital[pinNum].digitalValue;
      }
      if (pinNum >= 14 && pinNum <= 19) {
        return self.board.analog[pinNum - 14].digitalValue;
      }
      return 0;
    };

    const analogRead = (pin: number): number => {
      const pinNum = Number(pin);
      const aPin = pinNum >= 14 ? pinNum - 14 : pinNum;
      if (aPin >= 0 && aPin <= 5) {
        return self.board.analog[aPin].analogValue;
      }
      return 0;
    };

    const analogWrite = (pin: number, val: number) => {
      const pinNum = Number(pin);
      const clamped = Math.max(0, Math.min(255, Math.round(Number(val))));
      if (pinNum >= 0 && pinNum <= 13) {
        self.board.digital[pinNum].analogValue = clamped;
        self.board.digital[pinNum].digitalValue = clamped > 127 ? 1 : 0;
        if (pinNum === 13) {
          self.board.builtinLed = clamped > 127 ? 1 : 0;
        }
      }
    };

    const tone = (pin: number, freq: number) => {
      self.board.buzzerTone = Math.max(20, Math.min(20000, Number(freq)));
    };

    const noTone = () => {
      self.board.buzzerTone = null;
    };

    const delay = (_ms: number) => {
      // In browser cooperative tick loop, delay steps time forward simulated
      self.simulatedMillis += Math.round(Number(_ms) || 0);
    };

    const millis = () => self.simulatedMillis;
    const micros = () => self.simulatedMillis * 1000;

    const map = (x: number, in_min: number, in_max: number, out_min: number, out_max: number) => {
      return ((x - in_min) * (out_max - out_min)) / (in_max - in_min) + out_min;
    };

    const constrain = (amt: number, low: number, high: number) => Math.max(low, Math.min(high, amt));

    const Serial = {
      begin: (baud: number) => {
        self.log(`[Serial opened at ${baud} baud]`);
      },
      print: (val: unknown) => {
        self.log(String(val));
      },
      println: (val: unknown = "") => {
        self.log(String(val) + "\n");
      },
      write: (val: unknown) => {
        self.log(String(val));
      },
    };

    return {
      pinMode,
      digitalWrite,
      digitalRead,
      analogRead,
      analogWrite,
      tone,
      noTone,
      delay,
      millis,
      micros,
      map,
      constrain,
      min: Math.min,
      max: Math.max,
      abs: Math.abs,
      random: (minOrMax: number, maxVal?: number) => {
        if (maxVal === undefined) return Math.floor(Math.random() * minOrMax);
        return Math.floor(Math.random() * (maxVal - minOrMax) + minOrMax);
      },
      Serial,
    };
  }
}
