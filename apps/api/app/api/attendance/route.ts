import { NextRequest } from "next/server";
import { AttendanceService } from "../../../src/services/attendance.service";
import { StudentService } from "../../../src/services/student.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const { searchParams } = new URL(req.url);
    let type = searchParams.get("type"); // "section" or "student"
    let studentId = searchParams.get("studentId");
    const attendanceService = new AttendanceService();

    if (!type && role === UserRole.STUDENT) {
      type = "student";
      const studentService = new StudentService();
      const student = await studentService.getStudentByUserId(schoolId, userId);
      studentId = student.id;
    }

    if (type === "section") {
      const sectionId = searchParams.get("sectionId");
      const dateStr = searchParams.get("date");

      if (!sectionId || !dateStr) {
        return ApiResponse.badRequest("Missing sectionId or date parameter");
      }

      if (role === UserRole.STUDENT) {
        return ApiResponse.forbidden(
          "Students cannot view class attendance logs",
        );
      }

      const date = new Date(dateStr);
      const isFaculty = role === UserRole.FACULTY;
      const data = await attendanceService.getDailySectionAttendance(
        schoolId,
        sectionId,
        date,
        userId,
        isFaculty,
      );
      return ApiResponse.success(
        data,
        "Section attendance retrieved successfully",
      );
    }

    if (type === "student") {
      if (!studentId) {
        return ApiResponse.badRequest("Missing studentId parameter");
      }

      const studentService = new StudentService();
      const student = await studentService.getStudentById(schoolId, studentId);

      // Access checks
      if (role === UserRole.STUDENT) {
        if (student.userId !== userId) {
          return ApiResponse.forbidden(
            "Students can only view their own attendance",
          );
        }
      } else if (role === UserRole.FACULTY) {
        const hasAccess = await studentService.checkFacultyAccess(
          schoolId,
          studentId,
          userId,
        );
        if (!hasAccess) {
          return ApiResponse.forbidden(
            "Faculty can only view attendance for their assigned students",
          );
        }
      }

      const getStatsOnly = searchParams.get("statsOnly") === "true";
      if (getStatsOnly) {
        const stats = await attendanceService.getStudentAttendanceStats(
          schoolId,
          studentId,
        );
        return ApiResponse.success(
          stats,
          "Student attendance stats retrieved successfully",
        );
      }

      const startDateStr = searchParams.get("startDate");
      const endDateStr = searchParams.get("endDate");
      const startDate = startDateStr ? new Date(startDateStr) : undefined;
      const endDate = endDateStr ? new Date(endDateStr) : undefined;

      const history = await attendanceService.getStudentAttendanceHistory(
        schoolId,
        studentId,
        startDate,
        endDate,
      );
      const stats = await attendanceService.getStudentAttendanceStats(
        schoolId,
        studentId,
      );

      return ApiResponse.success(
        { stats, history },
        "Student attendance history retrieved successfully",
      );
    }

    return ApiResponse.badRequest(
      "Invalid query type parameter. Must be 'section' or 'student'",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to fetch attendance details",
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot mark attendance");
    }

    const body = await req.json();
    const attendanceService = new AttendanceService();
    const isFaculty = role === UserRole.FACULTY;

    // Detect if batch marking is requested or single marking
    const isBatch = Array.isArray(body.records);
    let data;

    if (isBatch) {
      data = await attendanceService.markBatch(
        schoolId,
        userId,
        isFaculty,
        body,
      );
    } else {
      data = await attendanceService.markSingle(
        schoolId,
        userId,
        isFaculty,
        body,
      );
    }

    return ApiResponse.success(data, "Attendance marked successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to record attendance",
    );
  }
}
