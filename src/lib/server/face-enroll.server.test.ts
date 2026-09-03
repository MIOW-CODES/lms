import { describe, it, expect, mock, beforeEach } from "bun:test";

process.env["SUPABASE_URL"] ??= "https://test.supabase.co";
process.env["SUPABASE_SERVICE_ROLE_KEY"] ??= "test-service-role-key-1234567890abcdef";
process.env["SUPABASE_PUBLISHABLE_KEY"] ??= "test-publishable-key";

import { DESCRIPTOR_LENGTH } from "../face";

/* ---------- In-memory fake for the db backend ---------- */

type Row = Record<string, unknown>;

// The row returned by SELECT … maybeSingle(); null = no profile row.
let storedRow: Row | null = null;
// Every payload passed to UPDATE, in call order.
let updates: Row[] = [];
// Columns constrained by .eq() per query, to prove 1:1 scoping.
let eqCalls: { col: string; val: unknown }[][] = [];

function makeChain(): Record<string, unknown> {
  const chain: Record<string, unknown> = {};
  chain["update"] = (row: Row) => {
    updates.push(row);
    if (storedRow) Object.assign(storedRow, row);
    return chain;
  };
  chain["select"] = (_cols?: string) => chain;
  chain["eq"] = (col: string, val: unknown) => {
    eqCalls[eqCalls.length - 1]?.push({ col, val });
    return chain;
  };
  chain["is"] = (_col: string, _val: unknown) => chain;
  chain["maybeSingle"] = async () => ({ data: storedRow, error: null });
  chain["single"] = async () => ({ data: storedRow, error: null });
  chain["then"] = (resolve: (v: unknown) => void) => resolve({ data: storedRow, error: null });
  return chain;
}

const fakeDb = {
  from: (_table: string) => {
    eqCalls.push([]);
    return makeChain();
  },
};

mock.module("@/integrations/db/client.server", () => ({
  db: fakeDb,
  supabaseAdmin: {},
}));

import { enrollFace, verifyFaceMatch } from "./profiles.server";

const TEST_ID = "123e4567-e89b-12d3-a456-426614174000";
const zeros = () => new Array<number>(DESCRIPTOR_LENGTH).fill(0);
const ones = () => new Array<number>(DESCRIPTOR_LENGTH).fill(1);
const ZEROS_EMB = JSON.stringify(zeros());
const ONES_EMB = JSON.stringify(ones());

function fakeProfile(overrides: Row = {}): Row {
  return {
    id: TEST_ID,
    student_id: "S-001",
    email: "face@test.local",
    full_name: "Face Test",
    role: "student",
    avatar_url: null,
    grade_level: 7,
    section: null,
    created_at: new Date().toISOString(),
    employee_id: null,
    prefix: null,
    department: null,
    biometric_enrolled_at: null,
    face_embedding: null,
    pin_hash: null,
    pin: null,
    rfid_uid: null,
    ...overrides,
  };
}

beforeEach(() => {
  storedRow = null;
  updates = [];
  eqCalls = [];
});

describe("enrollFace", () => {
  it("persists the embedding with an enrolment timestamp", async () => {
    storedRow = fakeProfile();
    const result = await enrollFace(TEST_ID, ZEROS_EMB);

    expect(updates.length).toBe(1);
    expect(updates[0]?.["face_embedding"]).toBe(ZEROS_EMB);
    expect(typeof updates[0]?.["biometric_enrolled_at"]).toBe("string");
    expect(result.is_face_enrolled).toBe(true);
  });

  it("clears the enrolment when null is passed", async () => {
    storedRow = fakeProfile({
      face_embedding: ZEROS_EMB,
      biometric_enrolled_at: new Date().toISOString(),
    });
    const result = await enrollFace(TEST_ID, null);

    expect(updates.length).toBe(1);
    expect(updates[0]?.["face_embedding"]).toBeNull();
    expect(updates[0]?.["biometric_enrolled_at"]).toBeNull();
    expect(result.is_face_enrolled).toBe(false);
  });
});

describe("verifyFaceMatch", () => {
  it("returns true for an identical embedding", async () => {
    storedRow = fakeProfile({ face_embedding: ZEROS_EMB });
    await expect(verifyFaceMatch(TEST_ID, ZEROS_EMB)).resolves.toBe(true);
  });

  it("returns false for a distant embedding", async () => {
    storedRow = fakeProfile({ face_embedding: ZEROS_EMB });
    await expect(verifyFaceMatch(TEST_ID, ONES_EMB)).resolves.toBe(false);
  });

  it("returns false when nothing is stored", async () => {
    storedRow = fakeProfile({ face_embedding: null });
    await expect(verifyFaceMatch(TEST_ID, ZEROS_EMB)).resolves.toBe(false);

    storedRow = null;
    await expect(verifyFaceMatch(TEST_ID, ZEROS_EMB)).resolves.toBe(false);
  });

  it("scopes every lookup to the given id (no 1:N search)", async () => {
    storedRow = fakeProfile({ face_embedding: ZEROS_EMB });
    await verifyFaceMatch(TEST_ID, ZEROS_EMB);
    expect(eqCalls.length).toBeGreaterThan(0);
    for (const call of eqCalls) {
      expect(call).toContainEqual({ col: "id", val: TEST_ID });
    }
  });
});
