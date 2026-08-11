import { NextRequest } from "next/server";
import { TimetableService } from "../../../../src/services/timetable.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    const timetableService = new TimetableService();
    const data = await timetableService.getEntryDetails(schoolId, id);

    return ApiResponse.success(data, "Timetable entry retrieved successfully");
  } catch (error: any) {
    return ApiResponse.notFound(error.message || "Timetable entry not found");
  }
}

export async function PUT(
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
        "Only administrators can update the timetable",
      );
    }

    const body = await req.json();
    const timetableService = new TimetableService();
    const data = await timetableService.updateEntry(schoolId, id, body);

    return ApiResponse.success(data, "Timetable entry updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to update timetable entry",
    );
  }
}

export async function DELETE(
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
        "Only administrators can delete timetable entries",
      );
    }

    const timetableService = new TimetableService();
    await timetableService.deleteEntry(schoolId, id);

    return ApiResponse.success(null, "Timetable entry deleted successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to delete timetable entry",
    );
  }
}
