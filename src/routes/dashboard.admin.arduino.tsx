import { createFileRoute } from "@tanstack/react-router";
import { ADMIN_NAV, AppShell, useProfile } from "@/components/lms";
import { ArduinoLab } from "@/components/arduino-lab";

export const Route = createFileRoute("/dashboard/admin/arduino")({
  head: () => ({
    meta: [
      { title: "Virtual Arduino Lab | MIOW Admin Console" },
      {
        name: "description",
        content: "Interactive Arduino Uno simulator with real-time pin I/O and serial monitor.",
      },
      {
        property: "og:title",
        content: "Virtual Arduino Lab | MIOW Admin Console",
      },
      {
        property: "og:description",
        content: "Interactive Arduino Uno simulator with real-time pin I/O and serial monitor.",
      },
    ],
  }),
  component: AdminArduinoPage,
});

function AdminArduinoPage() {
  const profile = useProfile(["admin"]);
  if (!profile) return null;

  return (
    <AppShell nav={ADMIN_NAV} profile={profile} subtitle="MIOW Admin Console · STEM Robotics Lab">
      <div className="mb-6">
        <h1 className="font-display text-2xl font-bold sm:text-3xl">
          Virtual Arduino Lab (ongoing)
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Interactive ATmega328P simulation environment for school robotics and microcontrollers
          curriculum.
        </p>
      </div>

      <ArduinoLab />
    </AppShell>
  );
}
