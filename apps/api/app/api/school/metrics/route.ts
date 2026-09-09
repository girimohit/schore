import { NextRequest } from "next/server";
import { prisma, UserRole, NoticeAudience } from "@schore/database";
import { ApiResponse } from "../../../../src/utils/response";
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

    // Shared notices audience filter
    const audienceList: NoticeAudience[] = [NoticeAudience.SCHOOL];
    if (role === UserRole.FACULTY) {
      audienceList.push(NoticeAudience.FACULTY);
    } else if (role === UserRole.STUDENT) {
      audienceList.push(NoticeAudience.STUDENTS);
    }

    if (
      role === UserRole.SUPER_ADMIN ||
      role === UserRole.SCHOOL_ADMIN
    ) {
      // 1. ADMIN METRICS (All queries parallelized concurrently)
      const [
        totalStudents,
        totalFaculty,
        totalClasses,
        totalSections,
        sectionsWithAttendanceToday,
        recentNotices,
      ] = await Promise.all([
        prisma.student.count({ where: { schoolId } }),
        prisma.faculty.count({ where: { schoolId } }),
        prisma.class.count({ where: { schoolId } }),
        prisma.section.count({ where: { schoolId } }),
        prisma.attendance.groupBy({
          by: ["sectionId"],
          where: {
            schoolId,
            date: {
              gte: new Date(todayStr + "T00:00:00.000Z"),
              lte: new Date(todayStr + "T23:59:59.999Z"),
            },
          },
        }),
        prisma.notice.findMany({
          where: {
            schoolId,
            audience: { in: audienceList },
          },
          take: 5,
          orderBy: { createdAt: "desc" },
        }),
      ]);

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
      const [faculty, recentNotices] = await Promise.all([
        prisma.faculty.findUnique({
          where: { userId },
        }),
        prisma.notice.findMany({
          where: {
            schoolId,
            audience: { in: audienceList },
          },
          take: 5,
          orderBy: { createdAt: "desc" },
        }),
      ]);

      if (!faculty) {
        return ApiResponse.badRequest("Faculty profile not found");
      }

      // Counts timetable slots for this faculty today
      const jsDay = new Date().getDay();
      const todayDayOfWeek = jsDay === 0 ? 7 : jsDay;

      // Find unique sections this faculty is assigned to
      const assignments = await prisma.facultySubjectAssignment.findMany({
        where: { facultyId: faculty.id },
        select: { sectionId: true },
      });
      const assignedSectionIds = Array.from(
        new Set(assignments.map((a) => a.sectionId).filter(Boolean)),
      ) as string[];

      // Parallelize timetable slot count & attendance submission check
      const [classesToday, submittedSectionsToday] = await Promise.all([
        prisma.timetable.count({
          where: {
            schoolId,
            facultyId: faculty.id,
            dayOfWeek: todayDayOfWeek,
          },
        }),
        assignedSectionIds.length > 0
          ? prisma.attendance.groupBy({
              by: ["sectionId"],
              where: {
                schoolId,
                sectionId: { in: assignedSectionIds },
                date: {
                  gte: new Date(todayStr + "T00:00:00.000Z"),
                  lte: new Date(todayStr + "T23:59:59.999Z"),
                },
              },
            })
          : Promise.resolve([]),
      ]);

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
      const [student, recentNotices] = await Promise.all([
        prisma.student.findUnique({
          where: { userId },
          include: {
            enrollments: {
              include: { class: true, section: true },
            },
          },
        }),
        prisma.notice.findMany({
          where: {
            schoolId,
            audience: { in: audienceList },
          },
          take: 5,
          orderBy: { createdAt: "desc" },
        }),
      ]);

      if (!student) {
        return ApiResponse.badRequest("Student profile not found");
      }

      const activeEnrollment = student.enrollments[0];
      const classId = activeEnrollment?.classId;
      const sectionId = activeEnrollment?.sectionId;

      const jsDay = new Date().getDay();
      const todayDayOfWeek = jsDay === 0 ? 7 : jsDay; // 1 = Monday ... 7 = Sunday
      const attendanceService = new AttendanceService();

      // Parallelize student stats, timetable slots, and pending homework count
      const [attendanceStats, timetable, homeworkCount] = await Promise.all([
        attendanceService.getStudentAttendanceStats(
          schoolId,
          student.id,
        ),
        classId && sectionId
          ? prisma.timetable.findMany({
              where: {
                schoolId,
                classId,
                sectionId,
                dayOfWeek: todayDayOfWeek,
              },
              include: {
                subject: true,
                faculty: true,
              },
              orderBy: { startTime: "asc" },
            })
          : Promise.resolve([]),
        classId && sectionId
          ? prisma.homework.count({
              where: {
                schoolId,
                classId,
                sectionId,
                dueDate: { gte: new Date() },
                submissions: {
                  none: { studentId: student.id },
                },
              },
            })
          : Promise.resolve(0),
      ]);

      return ApiResponse.success({
        role,
        stats: {
          attendanceRate: `${attendanceStats.percentage.toFixed(1)}%`,
          pendingTasks: `${homeworkCount} Task${homeworkCount !== 1 ? "s" : ""}`,
        },
        timetable: timetable.map((t: any) => ({
          time: `${t.startTime} - ${t.endTime}`,
          subject: t.subject?.name ?? "Subject",
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
