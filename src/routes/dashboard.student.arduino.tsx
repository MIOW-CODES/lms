import { createFileRoute } from "@tanstack/react-router";
import { AppShell, STUDENT_NAV, useProfile } from "@/components/lms";
import { ArduinoLab } from "@/components/arduino-lab";

export const Route = createFileRoute("/dashboard/student/arduino")({
  head: () => ({
    meta: [
      { title: "Virtual Arduino Lab | MIOW - Integrated Developmental School" },
      {
        name: "description",
        content: "Interactive Arduino Uno simulator with real-time pin I/O and serial monitor.",
      },
      {
        property: "og:title",
        content: "Virtual Arduino Lab | MIOW - Integrated Developmental School",
      },
      {
        property: "og:description",
        content: "Interactive Arduino Uno simulator with real-time pin I/O and serial monitor.",
      },
    ],
  }),
  component: StudentArduinoPage,
});

function StudentArduinoPage() {
  const profile = useProfile(["student"]);
  if (!profile) return null;

  return (
    <AppShell
      nav={STUDENT_NAV}
      profile={profile}
      subtitle="Integrated Developmental School · STEM Robotics Lab"
    >
      <div className="mb-6">
        <h1 className="font-display text-2xl font-bold sm:text-3xl">Virtual Arduino Lab</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Write, test, and run Arduino C++ sketches with real-time digital I/O, analog sensors, and serial debugging.
        </p>
      </div>

      <ArduinoLab />
    </AppShell>
  );
}
