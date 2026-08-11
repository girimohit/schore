import { NextRequest } from "next/server";
import { ExamService } from "../../../../../src/services/exam.service";
import { ApiResponse } from "../../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function POST(
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
        "Only administrators can add subjects to exams",
      );
    }

    const body = await req.json();
    const examService = new ExamService();
    const data = await examService.addSubjectToExam(schoolId, id, body);

    return ApiResponse.success(
      data,
      "Subject assigned to exam successfully",
      201,
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to assign subject to exam",
    );
  }
}
