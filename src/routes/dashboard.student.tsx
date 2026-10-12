import { useState } from "react";
import { createFileRoute, Outlet } from "@tanstack/react-router";
import { KeyRound } from "lucide-react";
import { toast } from "sonner";
import { KioskLockdown, LockdownProvider } from "@/components/lockdown";
import { Field, Modal, useProfile } from "@/components/lms";
import { changeOwnPin, refreshSessionProfile } from "@/lib/lms";

// Layout route for the student portal. The dashboard body lives in
// dashboard.student.index.tsx; child pages (grades, assignments, quizzes,
// attendance, settings) mount through <Outlet />.
//
// App-wide kiosk lockdown lives here: LockdownProvider holds the single
// useExamLock activation shared with the exam flow (dashboard.student.quizzes),
// and KioskLockdown applies it to student sessions when the admin setting is on.
//
// Forced PIN-change gate: student PINs default to the student number, which is
// not private. When the session profile carries pin_must_change (set for all
// students by the pin_security migration), a blocking modal covers the portal
// until the student picks a private PIN; the modal keeps the background inert,
// so navigation is blocked until the change succeeds.
//
// NOTE: No beforeLoad auth guard is needed here. useProfile() returns null
// when not authenticated, and all child pages already handle this case by
// rendering nothing or redirecting as appropriate.
export const Route = createFileRoute("/dashboard/student")({
  component: StudentLayout,
  errorComponent: () => (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-xl font-semibold tracking-tight text-foreground">
          Student portal error
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Something went wrong in the student portal. Please try refreshing the page.
        </p>
      </div>
    </div>
  ),
});

function StudentLayout() {
  const profile = useProfile();
  return (
    <LockdownProvider>
      <KioskLockdown />
      {profile?.pin_must_change ? <PinChangeGate /> : null}
      <Outlet />
    </LockdownProvider>
  );
}

/**
 * Blocking forced-PIN-change gate. Same form pattern as the settings
 * "Reset Account PIN" section (Field + plain form), minus the current-PIN
 * field — the signed-in session is the identity proof here. onClose is a
 * no-op: the gate only clears once the change succeeds.
 */
function PinChangeGate() {
  const [newPin, setNewPin] = useState("");
  const [confirmPin, setConfirmPin] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    if (!/^\d{4,8}$/.test(newPin)) {
      toast.error("New PIN must be 4–8 digits");
      return;
    }
    if (newPin !== confirmPin) {
      toast.error("New PINs do not match");
      return;
    }
    setBusy(true);
    try {
      await changeOwnPin(null, newPin);
      // Re-fetch the session profile (pin_must_change cleared server-side) —
      // the gate closes as soon as the refreshed profile lands in the store.
      await refreshSessionProfile();
      toast.success("PIN updated successfully");
    } catch {
      toast.error("Could not update PIN");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal open onClose={() => {}} title="Choose a new PIN">
      <form
        data-testid="pin-gate"
        onSubmit={(e) => {
          e.preventDefault();
          if (!busy) void submit();
        }}
      >
        <p className="mb-4 text-sm text-muted-foreground">
          Choose a new PIN — your old PIN is your student number and is not private.
        </p>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field
            label="New PIN"
            type="password"
            inputMode="numeric"
            autoComplete="new-password"
            value={newPin}
            onChange={(e) => setNewPin(e.target.value)}
            maxLength={8}
            data-testid="pin-gate-new"
          />
          <Field
            label="Confirm new PIN"
            type="password"
            inputMode="numeric"
            autoComplete="new-password"
            value={confirmPin}
            onChange={(e) => setConfirmPin(e.target.value)}
            maxLength={8}
            data-testid="pin-gate-confirm"
          />
        </div>
        <div className="mt-4 flex justify-end">
          <button
            type="submit"
            disabled={busy || !newPin || !confirmPin}
            data-testid="pin-gate-submit"
            className="flex items-center gap-2 rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground shadow-lift transition-opacity hover:opacity-90 disabled:opacity-50"
          >
            <KeyRound className="h-4 w-4" /> {busy ? "Saving…" : "Set PIN"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
