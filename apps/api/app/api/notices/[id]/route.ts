import { NextRequest } from "next/server";
import { NoticeService } from "../../../../src/services/notice.service";
import { ApiResponse } from "../../../../src/utils/response";
import { UserRole } from "@schore/database";

export async function GET(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    const noticeService = new NoticeService();
    const data = await noticeService.getNoticeDetails(schoolId, id);

    return ApiResponse.success(data, "Notice details retrieved successfully");
  } catch (error: any) {
    return ApiResponse.notFound(error.message || "Notice not found");
  }
}

export async function PUT(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot update notices");
    }

    const body = await req.json();
    const noticeService = new NoticeService();
    const isFaculty = role === UserRole.FACULTY;

    const data = await noticeService.updateNotice(
      schoolId,
      id,
      isFaculty,
      body,
    );

    return ApiResponse.success(data, "Notice updated successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to update notice");
  }
}

export async function DELETE(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot delete notices");
    }

    const noticeService = new NoticeService();

    await noticeService.deleteNotice(schoolId, id);

    return ApiResponse.success(null, "Notice deleted successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to delete notice");
  }
}
