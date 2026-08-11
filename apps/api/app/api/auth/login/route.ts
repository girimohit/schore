import { NextRequest } from "next/server";
import { z } from "zod";
import { AuthService } from "../../../../src/services/auth.service";
import { AuditService } from "../../../../src/services/audit.service";
import { ApiResponse } from "../../../../src/utils/response";

const loginSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const result = loginSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const authService = new AuthService();
    const auditService = new AuditService();

    const { email, password } = result.data;
    const authData = await authService.login(email, password);

    // Create Audit Log for successful login
    await auditService.logRequest(
      req,
      "USER_LOGIN",
      "User",
      authData.user.id,
      authData.user.id,
      authData.user.schoolId || undefined,
      { email },
    );

    return ApiResponse.success(authData, "Login successful");
  } catch (error: any) {
    return ApiResponse.unauthorized(error.message || "Invalid credentials");
  }
}
