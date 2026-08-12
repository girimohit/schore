import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";
import { AttendanceService } from "../../../../src/services/attendance.service";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const todayStr = new Date().toISOString().split("T")[0];

    // Shared notices query (common to all roles)
    const recentNotices = await prisma.notice.findMany({
      where: {
        schoolId,
        OR: [
          { audience: "SCHOOL" },
          role === "FACULTY" ? { audience: "FACULTY" } : {},
          role === "STUDENT" ? { audience: "STUDENTS" } : {},
        ].filter((o) => Object.keys(o).length > 0),
      },
      take: 5,
      orderBy: { createdAt: "desc" },
    });

    if (
      role === UserRole.SUPER_ADMIN ||
      role === UserRole.SCHOOL_ADMIN ||
      role === UserRole.ADMIN
    ) {
      // 1. ADMIN METRICS
      const [totalStudents, totalFaculty, totalClasses, totalSections] =
        await Promise.all([
          prisma.student.count({ where: { schoolId } }),
          prisma.faculty.count({ where: { schoolId } }),
          prisma.class.count({ where: { schoolId } }),
          prisma.section.count({ where: { schoolId } }),
        ]);

      // Count sections with attendance submitted today
      const sectionsWithAttendanceToday = await prisma.attendance.groupBy({
        by: ["sectionId"],
        where: {
          schoolId,
          date: {
            gte: new Date(todayStr + "T00:00:00.000Z"),
            lte: new Date(todayStr + "T23:59:59.999Z"),
          },
        },
      });

      const unmarkedAttendance = Math.max(
        0,
        totalSections - sectionsWithAttendanceToday.length,
      );

      return ApiResponse.success({
        role,
        stats: {
          totalStudents,
          totalFaculty,
          totalClasses,
          unmarkedAttendance,
        },
        recentNotices,
      });
    }

    if (role === UserRole.FACULTY) {
      // 2. FACULTY METRICS
      const faculty = await prisma.faculty.findUnique({
        where: { userId },
      });

      if (!faculty) {
        return ApiResponse.badRequest("Faculty profile not found");
      }

      // Counts timetable slots for this faculty today
      const classesToday = await prisma.timetable.count({
        where: {
          schoolId,
          facultyId: faculty.id,
        },
      });

      // Find how many unique sections this faculty is assigned to
      const assignments = await prisma.facultySubjectAssignment.findMany({
        where: { facultyId: faculty.id },
        select: { sectionId: true },
      });
      const assignedSectionIds = Array.from(
        new Set(assignments.map((a) => a.sectionId).filter(Boolean)),
      ) as string[];

      // Check attendance submissions by this faculty today
      const submittedSectionsToday = await prisma.attendance.groupBy({
        by: ["sectionId"],
        where: {
          schoolId,
          sectionId: { in: assignedSectionIds },
          date: {
            gte: new Date(todayStr + "T00:00:00.000Z"),
            lte: new Date(todayStr + "T23:59:59.999Z"),
          },
        },
      });

      const unmarkedAttendance = Math.max(
        0,
        assignedSectionIds.length - submittedSectionsToday.length,
      );

      return ApiResponse.success({
        role,
        stats: {
          classesToday: `${classesToday} Periods`,
          unmarkedAttendance: `${unmarkedAttendance} Class${unmarkedAttendance !== 1 ? "es" : ""}`,
        },
        recentNotices,
      });
    }

    if (role === UserRole.STUDENT) {
      // 3. STUDENT METRICS
      const student = await prisma.student.findUnique({
        where: { userId },
        include: {
          enrollments: {
            include: { class: true, section: true },
          },
        },
      });

      if (!student) {
        return ApiResponse.badRequest("Student profile not found");
      }

      const activeEnrollment = student.enrollments[0];
      const classId = activeEnrollment?.classId;
      const sectionId = activeEnrollment?.sectionId;

      // Get attendance rate percentage
      const attendanceService = new AttendanceService();
      const attendanceStats = await attendanceService.getStudentAttendanceStats(
        schoolId,
        student.id,
      );

      // Timetable today
      const todayDayOfWeek = new Date()
        .toLocaleDateString("en-US", { weekday: "long" })
        .toUpperCase();

      const timetable = await prisma.timetable.findMany({
        where: {
          schoolId,
          classId,
          sectionId,
          dayOfWeek: todayDayOfWeek as any,
        },
        include: {
          subject: true,
          faculty: true,
        },
        orderBy: { startTime: "asc" },
      });

      // Pending homework count
      const homeworkCount = await prisma.homework.count({
        where: {
          schoolId,
          classId,
          sectionId,
          dueDate: { gte: new Date() },
          submissions: {
            none: { studentId: student.id },
          },
        },
      });

      return ApiResponse.success({
        role,
        stats: {
          attendanceRate: `${attendanceStats.percentage.toFixed(1)}%`,
          pendingTasks: `${homeworkCount} Task${homeworkCount !== 1 ? "s" : ""}`,
        },
        timetable: timetable.map((t) => ({
          time: `${t.startTime} - ${t.endTime}`,
          subject: t.subject.name,
          room: t.room || "Room 101",
        })),
        recentNotices,
      });
    }

    return ApiResponse.badRequest("Unsupported user role");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to retrieve metrics",
    );
  }
}
