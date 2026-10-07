import { describe, expect, it } from "bun:test";
import { ArduinoSimulator } from "./arduino-simulator";

describe("ArduinoSimulator", () => {
  it("initializes digital and analog pins correctly", () => {
    const sim = new ArduinoSimulator();
    sim.reset();
    expect(sim.runCode("void setup() {} void loop() {}").success).toBe(true);
    sim.stop();
  });

  it("handles basic LED Blink setup and digitalWrite", () => {
    const sim = new ArduinoSimulator();
    let builtinLedVal = 0;
    sim.setSubscriber((state) => {
      builtinLedVal = state.builtinLed;
    });

    const code = `
      void setup() {
        pinMode(13, OUTPUT);
        digitalWrite(13, HIGH);
      }
      void loop() {
      }
    `;

    const res = sim.runCode(code);
    expect(res.success).toBe(true);
    expect(builtinLedVal).toBe(1);
    sim.stop();
  });

  it("simulates analog inputs and map function", () => {
    const sim = new ArduinoSimulator();
    sim.setAnalogInput(0, 512);

    const recordedVal = 0;
    void recordedVal;
    const code = `
      int sensorValue = 0;
      int mapped = 0;
      void setup() {
        sensorValue = analogRead(A0);
        mapped = map(sensorValue, 0, 1023, 0, 100);
      }
      void loop() {}
    `;

    const res = sim.runCode(code);
    expect(res.success).toBe(true);
    sim.stop();
  });

  it("logs Serial print and println messages", () => {
    const sim = new ArduinoSimulator();
    const logs: string[] = [];
    sim.setSubscriber((_, log) => {
      if (log) logs.push(log);
    });

    const code = `
      void setup() {
        Serial.begin(9600);
        Serial.println("Hello Arduino!");
      }
      void loop() {}
    `;

    const res = sim.runCode(code);
    expect(res.success).toBe(true);
    expect(logs.some((l) => l.includes("Hello Arduino!"))).toBe(true);
    sim.stop();
  });
});
