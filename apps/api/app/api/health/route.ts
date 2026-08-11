import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../src/utils/response";

export async function GET(req: NextRequest) {
  try {
    await prisma.$queryRaw`SELECT 1`;

    const status = {
      status: "UP",
      timestamp: new Date().toISOString(),
      database: "connected",
      uptime: process.uptime(),
      env: process.env.NODE_ENV || "development",
    };

    return ApiResponse.success(status, "System health report");
  } catch (error: any) {
    return ApiResponse.success(
      {
        status: "DOWN",
        timestamp: new Date().toISOString(),
        database: "disconnected",
        error: error.message || "Failed to query database",
      },
      "System health report",
      503,
    );
  }
}
