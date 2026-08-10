import { NextRequest } from "next/server";
import { HomeworkService } from "../../../../../../src/services/homework.service";
import { ApiResponse } from "../../../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function PUT(
  req: NextRequest,
  props: { params: Promise<{ id: string; subId: string }> }
) {
  try {
    const { id, subId } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot review submissions");
    }

    const body = await req.json();
    const homeworkService = new HomeworkService();
    const isFaculty = role === UserRole.FACULTY;

    const data = await homeworkService.reviewSubmission(schoolId, id, subId, userId, isFaculty, body);

    return ApiResponse.success(data, "Submission reviewed successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to review submission");
  }
}
