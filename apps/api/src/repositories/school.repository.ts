import { prisma } from "@schore/database";

export class SchoolRepository {
  async findById(id: string) {
    return prisma.school.findUnique({
      where: { id },
      include: {
        branding: true,
        features: true,
      },
    });
  }

  async findBrandingBySchoolId(schoolId: string) {
    return prisma.schoolBranding.findUnique({
      where: { schoolId },
    });
  }

  async findFeaturesBySchoolId(schoolId: string) {
    return prisma.schoolFeatures.findUnique({
      where: { schoolId },
    });
  }
}
