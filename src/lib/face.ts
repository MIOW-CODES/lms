/**
 * Client-side face recognition pipeline (face-api.js, self-hosted tiny models).
 *
 * Model weights live in `public/models/` and are served from FACE_MODEL_URL.
 * Only the browser-only functions below touch `face-api.js` (via dynamic
 * import), so server-side imports of the pure matching helpers never pull in
 * TF.js.
 */

export const FACE_MATCH_THRESHOLD = 0.6;
export const DESCRIPTOR_LENGTH = 128;
export const FACE_MODEL_URL = "/models";

let modelsPromise: Promise<void> | null = null;

/** Lazily load the 3 tiny nets in the browser; safe to call repeatedly. */
export function ensureFaceModels(): Promise<void> {
  if (typeof window === "undefined") {
    return Promise.reject(new Error("face models require a browser environment"));
  }
  if (!modelsPromise) {
    modelsPromise = (async () => {
      const faceapi = await import("face-api.js");
      // CPU backend: kiosk/test machines often lack a usable GPU, and a
      // WebGL init failure can hang or crash the tab with no error surfaced.
      await faceapi.tf.setBackend("cpu");
      await faceapi.tf.ready();
      await Promise.all([
        faceapi.nets.tinyFaceDetector.loadFromUri(FACE_MODEL_URL),
        faceapi.nets.faceLandmark68TinyNet.loadFromUri(FACE_MODEL_URL),
        faceapi.nets.faceRecognitionNet.loadFromUri(FACE_MODEL_URL),
      ]);
    })().catch((err: unknown) => {
      modelsPromise = null;
      throw err;
    });
  }
  return modelsPromise;
}

/**
 * Detect the single most prominent face in a video frame and return its
 * 128-D descriptor as a JSON string, or null when no face is found or
 * anything fails. Never throws.
 */
export async function videoToDescriptor(video: HTMLVideoElement): Promise<string | null> {
  try {
    // face-api's detector never settles on a video with no stream data
    // (no rejection, no resolution) — bail out before calling it.
    if (video.readyState < 2 || video.videoWidth === 0) return null;
    await ensureFaceModels();
    const faceapi = await import("face-api.js");
    const detection = await faceapi
      .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions())
      .withFaceLandmarks(true)
      .withFaceDescriptor();
    if (!detection) return null;
    const descriptor = Array.from(detection.descriptor);
    if (descriptor.length !== DESCRIPTOR_LENGTH) return null;
    for (const n of descriptor) {
      if (typeof n !== "number" || !Number.isFinite(n)) return null;
    }
    return JSON.stringify(descriptor);
  } catch {
    return null;
  }
}

function toDescriptorArray(value: unknown): number[] | null {
  let candidate: unknown = value;
  if (typeof candidate === "string") {
    try {
      candidate = JSON.parse(candidate) as unknown;
    } catch {
      return null;
    }
  }
  if (
    !Array.isArray(candidate) &&
    !(candidate instanceof Float32Array) &&
    !(candidate instanceof Float64Array)
  ) {
    return null;
  }
  if (candidate.length !== DESCRIPTOR_LENGTH) return null;
  const out: number[] = [];
  for (let i = 0; i < candidate.length; i++) {
    const n = candidate[i];
    if (typeof n !== "number" || !Number.isFinite(n)) return null;
    out.push(n);
  }
  return out;
}

/**
 * Euclidean distance between two 128-D face descriptors (arrays,
 * Float32/64Arrays, or JSON strings). Returns null for malformed input.
 * Never throws.
 */
export function embeddingDistance(a: unknown, b: unknown): number | null {
  try {
    const va = toDescriptorArray(a);
    const vb = toDescriptorArray(b);
    if (!va || !vb) return null;
    let sum = 0;
    for (let i = 0; i < DESCRIPTOR_LENGTH; i++) {
      const x = va[i];
      const y = vb[i];
      if (x === undefined || y === undefined) return null;
      const diff = x - y;
      sum += diff * diff;
    }
    return Math.sqrt(sum);
  } catch {
    return null;
  }
}

/** True when distance(a, b) <= threshold. Malformed input never matches. */
export function isMatch(a: unknown, b: unknown, threshold: number = FACE_MATCH_THRESHOLD): boolean {
  try {
    if (typeof threshold !== "number" || !Number.isFinite(threshold)) {
      return false;
    }
    const distance = embeddingDistance(a, b);
    return distance !== null && distance <= threshold;
  } catch {
    return false;
  }
}
