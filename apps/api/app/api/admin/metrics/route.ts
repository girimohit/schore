import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const [
      totalSchools,
      activeSchools,
      totalStudents,
      totalFaculty,
      activeSubscriptions,
      recentLogs,
      platformConfig,
    ] = await Promise.all([
      prisma.school.count(),
      prisma.school.count({ where: { status: "ACTIVE" } }),
      prisma.student.count(),
      prisma.faculty.count(),
      prisma.schoolSubscription.count({
        where: { status: "ACTIVE", endDate: { gte: new Date() } },
      }),
      prisma.auditLog.findMany({
        take: 10,
        orderBy: { createdAt: "desc" },
        include: {
          user: {
            select: {
              email: true,
              role: true,
            },
          },
          school: {
            select: {
              name: true,
              code: true,
            },
          },
        },
      }),
      prisma.platformConfig.findFirst(),
    ]);

    const metrics = {
      totalSchools,
      activeSchools,
      totalStudents,
      totalFaculty,
      activeSubscriptions,
      maintenanceMode: platformConfig?.maintenanceMode ?? false,
      minAndroidVersion: platformConfig?.minAndroidVersion ?? "1.0.0",
      minIosVersion: platformConfig?.minIosVersion ?? "1.0.0",
      latestAndroidVersion: platformConfig?.latestAndroidVersion ?? "1.0.0",
      latestIosVersion: platformConfig?.latestIosVersion ?? "1.0.0",
      recentLogs,
    };

    return ApiResponse.success(metrics, "Metrics retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to retrieve metrics",
    );
  }
}
