import { NextRequest } from "next/server";
import { AcademicService } from "../../../src/services/academic.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    const academicService = new AcademicService();
    const data = await academicService.getClasses(schoolId);
    return ApiResponse.success(data, "Classes retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load classes");
  }
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can manage classes");
    }

    const body = await req.json();
    const academicService = new AcademicService();
    const data = await academicService.createClass(schoolId, body);

    return ApiResponse.success(data, "Class created successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to create class");
  }
}
