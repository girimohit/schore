import { NextRequest } from "next/server";
import { RemarkService } from "../../../src/services/remark.service";
import { StudentService } from "../../../src/services/student.service";
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

    const remarkService = new RemarkService();

    if (role === UserRole.STUDENT) {
      const studentService = new StudentService();
      const student = await studentService.getStudentByUserId(schoolId, userId);
      const data = await remarkService.getRemarksForStudent(
        schoolId,
        student.id,
      );
      return ApiResponse.success(
        data,
        "Student remarks retrieved successfully",
      );
    }

    // Faculty/Admins see all student remarks in the school
    const data = await remarkService.getAllRemarks(schoolId);
    return ApiResponse.success(data, "Student remarks retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to fetch remarks");
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
      return ApiResponse.forbidden("Students cannot publish remarks");
    }

    const body = await req.json();
    const remarkService = new RemarkService();
    const data = await remarkService.createRemark(schoolId, userId, role, body);

    return ApiResponse.success(data, "Student remark added successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to add remark");
  }
}
