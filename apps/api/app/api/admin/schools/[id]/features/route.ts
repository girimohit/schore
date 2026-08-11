import { NextRequest } from "next/server";
import { z } from "zod";
import { SchoolService } from "../../../../../../src/services/school.service";
import { ApiResponse } from "../../../../../../src/utils/response";
import { UserRole } from "@schore/database";

const featuresSchema = z.object({
  attendance: z.boolean().optional(),
  homework: z.boolean().optional(),
  exams: z.boolean().optional(),
  notices: z.boolean().optional(),
  remarks: z.boolean().optional(),
  timetable: z.boolean().optional(),
});

export async function GET(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const { id } = await props.params;
    const schoolService = new SchoolService();
    const features = await schoolService.getFeatures(id);

    return ApiResponse.success(
      features,
      "School features configuration retrieved successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to retrieve features",
    );
  }
}

export async function PATCH(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const { id } = await props.params;
    const body = await req.json();
    const result = featuresSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const schoolService = new SchoolService();
    const updated = await schoolService.updateFeatures(id, result.data);

    return ApiResponse.success(updated, "School features updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update features");
  }
}
