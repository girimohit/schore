import { NextRequest } from "next/server";
import { ExamService } from "../../../../../src/services/exam.service";
import { ApiResponse } from "../../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(
  req: NextRequest,
  props: { params: Promise<{ id: string }> }
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
      return ApiResponse.forbidden("Students cannot list exam results of other students");
    }

    const examService = new ExamService();
    const isFaculty = role === UserRole.FACULTY;
    const data = await examService.getExamResults(schoolId, id, userId, isFaculty);

    return ApiResponse.success(data, "Exam results retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load exam results");
  }
}

export async function POST(
  req: NextRequest,
  props: { params: Promise<{ id: string }> }
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
      return ApiResponse.forbidden("Students cannot record exam results");
    }

    const body = await req.json();
    const examService = new ExamService();
    const isFaculty = role === UserRole.FACULTY;

    const data = await examService.recordResultsBatch(schoolId, id, userId, isFaculty, body);

    return ApiResponse.success(data, "Exam results recorded successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to record exam results");
  }
}
