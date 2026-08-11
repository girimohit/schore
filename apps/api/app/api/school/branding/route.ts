import { NextRequest } from "next/server";
import { z } from "zod";
import { SchoolService } from "../../../../src/services/school.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

const schoolBrandingSchema = z.object({
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

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId || !role) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role !== UserRole.SCHOOL_ADMIN && role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: School Admin access required");
    }

    const schoolService = new SchoolService();
    const branding = await schoolService.getBranding(schoolId);

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

export async function PATCH(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId || !role) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role !== UserRole.SCHOOL_ADMIN && role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: School Admin access required");
    }

    const body = await req.json();
    const result = schoolBrandingSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const schoolService = new SchoolService();
    const updated = await schoolService.updateBranding(schoolId, result.data);

    return ApiResponse.success(updated, "School branding updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update branding");
  }
}
