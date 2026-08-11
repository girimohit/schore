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
  const config = await prisma.schoolFeatures.findUnique({
    where: { schoolId },
  });

  if (config && !config[feature]) {
    throw new Error(
      `This module is not enabled for your school. Please contact support.`,
    );
  }
}
