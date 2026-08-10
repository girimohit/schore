import { NextRequest } from "next/server";
import { NoticeService } from "../../../src/services/notice.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const noticeService = new NoticeService();
    const data = await noticeService.getNoticesForUser(schoolId, role, userId);

    return ApiResponse.success(data, "Notices retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load notices");
  }
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot publish notices");
    }

    const body = await req.json();
    const noticeService = new NoticeService();
    const isFaculty = role === UserRole.FACULTY;

    const data = await noticeService.createNotice(schoolId, isFaculty, body);

    return ApiResponse.success(data, "Notice published successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to publish notice");
  }
}
