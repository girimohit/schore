import { NextRequest } from "next/server";
import { z } from "zod";
import { SchoolService } from "../../../../../src/services/school.service";
import { ApiResponse } from "../../../../../src/utils/response";
import { UserRole } from "@schore/database";

const patchSchema = z.object({
  name: z.string().min(1, "School name is required").optional(),
  email: z.string().email("Invalid email address").optional().nullable(),
  phone: z.string().optional().nullable(),
  address: z.string().optional().nullable(),
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
    const school = await schoolService.getSchoolById(id);

    return ApiResponse.success(school, "School details retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to retrieve school details",
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
    const result = patchSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const updateData = {
      name: result.data.name,
      email: result.data.email ?? undefined,
      phone: result.data.phone ?? undefined,
      address: result.data.address ?? undefined,
    };

    const schoolService = new SchoolService();
    const updated = await schoolService.updateSchoolDetails(id, updateData);

    return ApiResponse.success(updated, "School details updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to update school details",
    );
  }
}
