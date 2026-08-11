import { NextRequest } from "next/server";
import { SchoolService } from "../../../../../../src/services/school.service";
import { ApiResponse } from "../../../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function POST(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    const actorId = req.headers.get("x-user-id");

    if (role !== UserRole.SUPER_ADMIN || !actorId) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const { id } = await props.params;
    const schoolService = new SchoolService();
    const updated = await schoolService.updateSchoolStatus(
      id,
      "SUSPENDED",
      actorId,
    );

    return ApiResponse.success(updated, "School suspended successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to suspend school");
  }
}
