import { NextRequest } from "next/server";
import { ExamService } from "../../../src/services/exam.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole, ExamStatus } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId || !role) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const { searchParams } = new URL(req.url);
    const classId = searchParams.get("classId") || undefined;
    const sectionId = searchParams.get("sectionId") || undefined;
    const academicYearId = searchParams.get("academicYearId") || undefined;
    
    // Students can ONLY query published exams
    const status = role === UserRole.STUDENT 
      ? ExamStatus.PUBLISHED 
      : ((searchParams.get("status") as ExamStatus) || undefined);

    const examService = new ExamService();
    const data = await examService.getExams(schoolId, {
      classId,
      sectionId,
      academicYearId,
      status,
    });

    return ApiResponse.success(data, "Exams list retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load exams");
  }
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    // Admins config exam structures
    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can create exam schedules");
    }

    const body = await req.json();
    const examService = new ExamService();
    const data = await examService.createExam(schoolId, body);

    return ApiResponse.success(data, "Exam term created successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to create exam");
  }
}
