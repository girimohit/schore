import { NextRequest } from "next/server";
import { z } from "zod";
import { SchoolService } from "../../../../src/services/school.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

const provisionSchema = z.object({
  name: z.string().min(1, "School name is required"),
  code: z
    .string()
    .min(1, "School code is required")
    .regex(/^[A-Za-z0-9]+$/, "School code must be alphanumeric"),
  email: z
    .string()
    .email("Invalid email address")
    .optional()
    .transform((val) => val ?? undefined),
  phone: z
    .string()
    .optional()
    .transform((val) => val ?? undefined),
  address: z
    .string()
    .optional()
    .transform((val) => val ?? undefined),
  academicYearName: z.string().min(1, "Academic year name is required"),
  academicYearStartDate: z.string().transform((val) => new Date(val)),
  academicYearEndDate: z.string().transform((val) => new Date(val)),
  adminEmail: z.string().email("Invalid admin email address"),
  adminPhone: z
    .string()
    .optional()
    .transform((val) => val ?? undefined),
  appName: z.string().optional(),
  logoUrl: z
    .string()
    .url()
    .optional()
    .or(z.literal(""))
    .transform((val) => val ?? undefined),
  primaryColor: z.string().optional(),
  secondaryColor: z.string().optional(),
  fontFamily: z.string().optional(),
  themeMode: z.string().optional(),
  features: z
    .object({
      attendance: z.boolean().optional(),
      homework: z.boolean().optional(),
      exams: z.boolean().optional(),
      notices: z.boolean().optional(),
      remarks: z.boolean().optional(),
      timetable: z.boolean().optional(),
    })
    .optional(),
  subscriptionPlan: z.string().optional(),
  subscriptionDurationDays: z.number().optional(),
});

export async function POST(req: NextRequest) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const body = await req.json();
    const result = provisionSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const schoolService = new SchoolService();
    const provisionResult = await schoolService.provisionSchool(result.data);

    return ApiResponse.success(
      provisionResult,
      "School provisioned successfully",
      201,
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to provision school",
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const { searchParams } = new URL(req.url);
    const search = searchParams.get("search") || undefined;
    const status = searchParams.get("status") || undefined;
    const page = parseInt(searchParams.get("page") || "1", 10);
    const limit = parseInt(searchParams.get("limit") || "10", 10);

    const schoolService = new SchoolService();
    const listResult = await schoolService.listSchools({
      search,
      status,
      page,
      limit,
    });

    return ApiResponse.success(listResult, "Schools retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to list schools");
  }
}
