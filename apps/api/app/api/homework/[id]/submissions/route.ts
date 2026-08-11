import { NextRequest } from "next/server";
import { HomeworkService } from "../../../../../src/services/homework.service";
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

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot list all submissions");
    }

    const homeworkService = new HomeworkService();
    const isFaculty = role === UserRole.FACULTY;
    const data = await homeworkService.getHomeworkSubmissions(
      schoolId,
      id,
      userId,
      isFaculty,
    );

    return ApiResponse.success(data, "Submissions list retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to load submissions",
    );
  }
}

export async function POST(
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

    if (role !== UserRole.STUDENT) {
      return ApiResponse.forbidden("Only students can submit homework");
    }

    const body = await req.json();
    const homeworkService = new HomeworkService();
    const data = await homeworkService.submitHomework(
      schoolId,
      id,
      userId,
      body,
    );

    return ApiResponse.success(data, "Homework submitted successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to submit homework");
  }
}
