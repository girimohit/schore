import { NextRequest } from "next/server";
import { z } from "zod";
import { AuthService } from "../../../../src/services/auth.service";
import { ApiResponse } from "../../../../src/utils/response";

const logoutSchema = z.object({
  refreshToken: z.string().min(1, "Refresh token is required"),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const result = logoutSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const authService = new AuthService();
    const { refreshToken } = result.data;
    await authService.logout(refreshToken);

    return ApiResponse.success(null, "Logout successful");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Logout failed");
  }
}
