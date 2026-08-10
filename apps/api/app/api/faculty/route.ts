import { NextRequest } from "next/server";
import { FacultyService } from "../../../src/services/faculty.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole, UserStatus } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId || !role) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    // RBAC: Only administrators can list all faculty profiles
    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can list faculty members");
    }

    const { searchParams } = new URL(req.url);
    const search = searchParams.get("search") || undefined;
    const status = (searchParams.get("status") as UserStatus) || undefined;
    const limit = parseInt(searchParams.get("limit") || "20", 10);
    const offset = parseInt(searchParams.get("offset") || "0", 10);

    const facultyService = new FacultyService();
    const data = await facultyService.searchFaculty(schoolId, {
      search,
      status,
      take: limit,
      skip: offset,
    });

    return ApiResponse.success(data, "Faculty list retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to query faculty");
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
      return ApiResponse.forbidden("Only administrators can create faculty profiles");
    }

    const body = await req.json();
    const facultyService = new FacultyService();
    const data = await facultyService.createFaculty(schoolId, body);

    return ApiResponse.success(data, "Faculty profile created successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to create faculty profile");
  }
}
