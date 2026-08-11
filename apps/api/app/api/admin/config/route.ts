import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

const configSchema = z.object({
  maintenanceMode: z.boolean().optional(),
  minAndroidVersion: z.string().optional(),
  minIosVersion: z.string().optional(),
  latestAndroidVersion: z.string().optional(),
  latestIosVersion: z.string().optional(),
  killSwitches: z.record(z.boolean()).optional(),
});

export async function PATCH(req: NextRequest) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    const body = await req.json();
    const result = configSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const existing = await prisma.platformConfig.findFirst();

    let updated;
    if (existing) {
      updated = await prisma.platformConfig.update({
        where: { id: existing.id },
        data: result.data,
      });
    } else {
      updated = await prisma.platformConfig.create({
        data: {
          maintenanceMode: result.data.maintenanceMode ?? false,
          minAndroidVersion: result.data.minAndroidVersion ?? "1.0.0",
          minIosVersion: result.data.minIosVersion ?? "1.0.0",
          latestAndroidVersion: result.data.latestAndroidVersion ?? "1.0.0",
          latestIosVersion: result.data.latestIosVersion ?? "1.0.0",
          killSwitches: result.data.killSwitches ?? {},
        },
      });
    }

    return ApiResponse.success(
      updated,
      "Platform configuration updated successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update config");
  }
}
export async function GET(req: NextRequest) {
  try {
    const role = req.headers.get("x-user-role") as UserRole;
    if (role !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Forbidden: Super Admin access required");
    }

    let config = await prisma.platformConfig.findFirst();
    if (!config) {
      config = await prisma.platformConfig.create({
        data: {
          maintenanceMode: false,
          minAndroidVersion: "1.0.0",
          minIosVersion: "1.0.0",
          latestAndroidVersion: "1.0.0",
          latestIosVersion: "1.0.0",
          killSwitches: {},
        },
      });
    }

    return ApiResponse.success(config, "Config retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to retrieve config");
  }
}
