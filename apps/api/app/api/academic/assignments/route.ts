import { NextRequest } from "next/server";
import { AcademicService } from "../../../../src/services/academic.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can assign academic resources");
    }

    const body = await req.url ? await req.json() : {};
    const { type, ...payload } = body;
    const academicService = new AcademicService();

    if (type === "class-subject") {
      const data = await academicService.assignSubjectToClass(schoolId, payload);
      return ApiResponse.success(data, "Subject assigned to class successfully", 201);
    } else if (type === "faculty-subject") {
      const data = await academicService.assignFacultySubject(schoolId, payload);
      return ApiResponse.success(data, "Subject assigned to faculty successfully", 201);
    } else {
      return ApiResponse.badRequest("Invalid assignment type. Must be 'class-subject' or 'faculty-subject'");
    }
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to make assignment");
  }
}
