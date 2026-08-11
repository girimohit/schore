import { NextRequest } from "next/server";
import { ExamService } from "../../../../../src/services/exam.service";
import { StudentService } from "../../../../../src/services/student.service";
import { ApiResponse } from "../../../../../src/utils/response";
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

    // Access Checks: Students view their own results, Faculty view assigned class students
    if (role === UserRole.STUDENT) {
      if (student.userId !== userId) {
        return ApiResponse.forbidden(
          "Students can only view their own exam results",
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
          "Faculty can only view results of students in their assigned classes",
        );
      }
    }

    const examService = new ExamService();
    const data = await examService.getStudentResults(schoolId, id);

    return ApiResponse.success(data, "Student results retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to load student results",
    );
  }
}
