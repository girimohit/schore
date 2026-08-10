import { NextRequest } from "next/server";
import { BootstrapService } from "../../../../src/services/bootstrap.service";
import { ApiResponse } from "../../../../src/utils/response";

export async function GET(req: NextRequest) {
  try {
    const userId = req.headers.get("x-user-id");
    const schoolId = req.headers.get("x-school-id");
    const appVersion = req.headers.get("x-app-version");

    if (!userId || !schoolId) {
      return ApiResponse.unauthorized("Missing user or school context in headers");
    }

    const bootstrapService = new BootstrapService();
    const data = await bootstrapService.getBootstrapData(userId, schoolId, appVersion);

    return ApiResponse.success(data, "Bootstrap data loaded successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load bootstrap data");
  }
}
