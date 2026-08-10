import { NextRequest } from "next/server";
import { RemarkService } from "../../../../src/services/remark.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function PUT(
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

    const body = await req.json();
    const remarkService = new RemarkService();
    const data = await remarkService.updateRemark(schoolId, id, userId, role, body);

    return ApiResponse.success(data, "Student remark updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update remark");
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
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const remarkService = new RemarkService();
    await remarkService.deleteRemark(schoolId, id, userId, role);

    return ApiResponse.success(null, "Student remark deleted successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to delete remark");
  }
}
