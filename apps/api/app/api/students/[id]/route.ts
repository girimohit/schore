import { NextRequest } from "next/server";
import { StudentService } from "../../../../src/services/student.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const studentService = new StudentService();
    const student = await studentService.getStudentById(schoolId, id);

    // RBAC & Tenant Isolation checks
    if (role === UserRole.STUDENT) {
      if (student.userId !== userId) {
        return ApiResponse.forbidden(
          "Students can only view their own information",
        );
      }
    } else if (role === UserRole.FACULTY) {
      const hasAccess = await studentService.checkFacultyAccess(
        schoolId,
        id,
        userId,
      );
      if (!hasAccess) {
        return ApiResponse.forbidden(
          "Faculty can only access students from their assigned classes/sections",
        );
      }
    }

    return ApiResponse.success(
      student,
      "Student details retrieved successfully",
    );
  } catch (error: any) {
    return ApiResponse.notFound(error.message || "Student not found");
  }
}

export async function PUT(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden(
        "Only administrators can update student profiles",
      );
    }

    const body = await req.json();
    const studentService = new StudentService();
    const data = await studentService.updateStudent(schoolId, id, body);

    return ApiResponse.success(data, "Student updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update student");
  }
}
