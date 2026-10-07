import { createFileRoute } from "@tanstack/react-router";
import { AppShell, TEACHER_NAV, useProfile } from "@/components/lms";
import { ArduinoLab } from "@/components/arduino-lab";

export const Route = createFileRoute("/dashboard/teacher/arduino")({
  head: () => ({
    meta: [
      { title: "Virtual Arduino Lab | MIOW Teacher Portal" },
      {
        name: "description",
        content: "Interactive Arduino Uno simulator with real-time pin I/O and serial monitor.",
      },
      {
        property: "og:title",
        content: "Virtual Arduino Lab | MIOW Teacher Portal",
      },
      {
        property: "og:description",
        content: "Interactive Arduino Uno simulator with real-time pin I/O and serial monitor.",
      },
    ],
  }),
  component: TeacherArduinoPage,
});

function TeacherArduinoPage() {
  const profile = useProfile(["teacher", "admin"]);
  if (!profile) return null;

  return (
    <AppShell
      nav={TEACHER_NAV}
      profile={profile}
      subtitle="MIOW Teacher Portal · Practical Robotics Lab"
    >
      <div className="mb-6">
        <h1 className="font-display text-2xl font-bold sm:text-3xl">
          Virtual Arduino Lab (ongoing)
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Prepare practical activities, test student code sketches, and demonstrate embedded
          microcontrollers.
        </p>
      </div>

      <ArduinoLab />
    </AppShell>
  );
}
