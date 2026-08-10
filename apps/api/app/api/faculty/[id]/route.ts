import { NextRequest } from "next/server";
import { FacultyService } from "../../../../src/services/faculty.service";
import { ApiResponse } from "../../../../src/utils/response";
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

    const facultyService = new FacultyService();
    const faculty = await facultyService.getFacultyById(schoolId, id);

    // RBAC: Faculty can only read their own profile; students are forbidden
    if (role === UserRole.FACULTY) {
      if (faculty.userId !== userId) {
        return ApiResponse.forbidden("Faculty members can only view their own profiles");
      }
    } else if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot view faculty profile details");
    }

    return ApiResponse.success(faculty, "Faculty details retrieved successfully");
  } catch (error: any) {
    return ApiResponse.notFound(error.message || "Faculty profile not found");
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
      return ApiResponse.forbidden("Only administrators can update faculty profiles");
    }

    const body = await req.json();
    const facultyService = new FacultyService();
    const data = await facultyService.updateFaculty(schoolId, id, body);

    return ApiResponse.success(data, "Faculty profile updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update faculty profile");
  }
}
