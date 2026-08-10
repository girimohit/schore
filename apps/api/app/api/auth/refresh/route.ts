import { NextRequest } from "next/server";
import { z } from "zod";
import { AuthService } from "../../../../src/services/auth.service";
import { ApiResponse } from "../../../../src/utils/response";

const refreshSchema = z.object({
  refreshToken: z.string().min(1, "Refresh token is required"),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const result = refreshSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const authService = new AuthService();
    const { refreshToken } = result.data;
    const tokens = await authService.refresh(refreshToken);

    return ApiResponse.success(tokens, "Tokens refreshed successfully");
  } catch (error: any) {
    return ApiResponse.unauthorized(error.message || "Invalid refresh token");
  }
}
