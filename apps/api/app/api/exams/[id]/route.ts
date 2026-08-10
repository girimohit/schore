import { NextRequest } from "next/server";
import { ExamService } from "../../../../src/services/exam.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole, ExamStatus } from "@schore/database";

export async function GET(
  req: NextRequest,
  props: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId || !role) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const examService = new ExamService();
    const data = await examService.getExamDetails(schoolId, id);

    // Students can only view published exams
    if (role === UserRole.STUDENT && data.status !== ExamStatus.PUBLISHED) {
      return ApiResponse.forbidden("Exam results are not published yet");
    }

    return ApiResponse.success(data, "Exam details retrieved successfully");
  } catch (error: any) {
    return ApiResponse.notFound(error.message || "Exam not found");
  }
}

export async function PUT(
  req: NextRequest,
  props: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can update exam configurations");
    }

    const body = await req.json();
    const examService = new ExamService();
    const data = await examService.updateExam(schoolId, id, body);

    return ApiResponse.success(data, "Exam updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update exam");
  }
}

export async function DELETE(
  req: NextRequest,
  props: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can delete exam structures");
    }

    const examService = new ExamService();
    await examService.deleteExam(schoolId, id);

    return ApiResponse.success(null, "Exam structure deleted successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to delete exam");
  }
}
