import { NextRequest } from "next/server";
import { TimetableService } from "../../../src/services/timetable.service";
import { FacultyService } from "../../../src/services/faculty.service";
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
    let type = searchParams.get("type"); // "class" or "faculty"
    const timetableService = new TimetableService();

    if (!type) {
      if (role === UserRole.STUDENT) {
        type = "class";
      } else if (role === UserRole.FACULTY) {
        type = "faculty";
      } else {
        const data = await timetableService.getAllTimetable(schoolId);
        return ApiResponse.success(
          data,
          "Timetable entries retrieved successfully",
        );
      }
    }

    if (type === "class") {
      let classId = searchParams.get("classId");
      let sectionId = searchParams.get("sectionId");

      // If user is a student, we can auto-resolve their class & section
      if (role === UserRole.STUDENT) {
        const studentService = new StudentService();
        const student = await studentService.getStudentByUserId(
          schoolId,
          userId,
        );
        const activeEnrollment = student.enrollments.find(
          (e) => e.status === "ACTIVE",
        );
        if (!activeEnrollment) {
          return ApiResponse.badRequest(
            "Student has no active class enrollment",
          );
        }
        classId = activeEnrollment.classId;
        sectionId = activeEnrollment.sectionId;
      }

      if (!classId || !sectionId) {
        return ApiResponse.badRequest(
          "Missing classId or sectionId parameters",
        );
      }

      const data = await timetableService.getClassTimetable(
        schoolId,
        classId,
        sectionId,
      );
      return ApiResponse.success(
        data,
        "Class timetable retrieved successfully",
      );
    }

    if (type === "faculty") {
      let facultyId = searchParams.get("facultyId");

      if (role === UserRole.FACULTY) {
        const facultyService = new FacultyService();
        const faculty = await facultyService.getFacultyByUserId(
          schoolId,
          userId,
        );
        facultyId = faculty.id;
      }

      if (!facultyId) {
        return ApiResponse.badRequest("Missing facultyId parameter");
      }

      // Access checks: Only admins or the faculty member themselves can view
      if (role === UserRole.FACULTY) {
        const facultyService = new FacultyService();
        const faculty = await facultyService.getFacultyById(
          schoolId,
          facultyId,
        );
        if (faculty.userId !== userId) {
          return ApiResponse.forbidden(
            "Faculty can only view their own teaching timetable",
          );
        }
      } else if (role === UserRole.STUDENT) {
        return ApiResponse.forbidden(
          "Students cannot access teacher teaching schedules",
        );
      }

      const data = await timetableService.getFacultyTimetable(
        schoolId,
        facultyId,
      );
      return ApiResponse.success(
        data,
        "Faculty timetable retrieved successfully",
      );
    }

    return ApiResponse.badRequest(
      "Invalid query type parameter. Must be 'class' or 'faculty'",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load timetable");
  }
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    // RBAC: Only administrators can schedule timetable slots
    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden(
        "Only administrators can manage the timetable",
      );
    }

    const body = await req.json();
    const timetableService = new TimetableService();
    const data = await timetableService.createEntry(schoolId, body);

    return ApiResponse.success(
      data,
      "Timetable entry created successfully",
      201,
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to create timetable entry",
    );
  }
}
