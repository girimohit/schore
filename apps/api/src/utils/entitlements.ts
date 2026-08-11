import { prisma } from "@schore/database";

export async function enforceEntitlement(
  schoolId: string,
  feature:
    | "attendance"
    | "homework"
    | "exams"
    | "notices"
    | "remarks"
    | "timetable",
): Promise<void> {
  // 1. Global Maintenance Mode Check
  const platformConfig = await prisma.platformConfig.findFirst();
  if (platformConfig?.maintenanceMode) {
    throw new Error(
      "The platform is currently undergoing maintenance. Please try again later.",
    );
  }

  // 2. School Status and Subscription Checks
  const school = await prisma.school.findUnique({
    where: { id: schoolId },
    include: { subscription: true },
  });

  if (!school) {
    throw new Error("School configuration not found.");
  }

  if (school.status === "SUSPENDED") {
    throw new Error(
      "Your school access has been suspended. Please contact support.",
    );
  }

  if (school.status === "INACTIVE" || school.status === "PENDING") {
    throw new Error(
      "Your school account is currently inactive. Please contact support.",
    );
  }

  const sub = school.subscription;
  if (!sub || sub.status !== "ACTIVE" || new Date(sub.endDate) < new Date()) {
    throw new Error(
      "Your school subscription has expired or is inactive. Please contact support.",
    );
  }

  // 3. Feature Gating Check
  const config = await prisma.schoolFeatures.findUnique({
    where: { schoolId },
  });

  if (config && !config[feature]) {
    throw new Error(
      `This module is not enabled for your school. Please contact support.`,
    );
  }
}
