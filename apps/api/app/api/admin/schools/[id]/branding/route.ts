import { NextRequest } from "next/server";
import { z } from "zod";
import { SchoolService } from "../../../../../../src/services/school.service";
import { ApiResponse } from "../../../../../../src/utils/response";
import { UserRole } from "@schore/database";

const brandingSchema = z.object({
  appName: z.string().optional(),
  logoUrl: z
    .string()
    .url()
    .optional()
    .nullable()
    .or(z.literal(""))
    .transform((v) => v ?? undefined),
  splashImageUrl: z
    .string()
    .url()
    .optional()
    .nullable()
    .or(z.literal(""))
    .transform((v) => v ?? undefined),
  primaryColor: z.string().optional(),
  secondaryColor: z.string().optional(),
  fontFamily: z.string().optional(),
  themeMode: z.string().optional(),
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
    const branding = await schoolService.getBranding(id);

    return ApiResponse.success(
      branding,
      "School branding configuration retrieved successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to retrieve branding",
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
    const result = brandingSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const schoolService = new SchoolService();
    const updated = await schoolService.updateBranding(id, result.data);

    return ApiResponse.success(updated, "School branding updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update branding");
  }
}
