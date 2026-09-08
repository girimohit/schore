import { NextRequest } from "next/server";
import { HomeworkService } from "../../../../src/services/homework.service";
import { FacultyService } from "../../../../src/services/faculty.service";
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

    const homeworkService = new HomeworkService();
    const data = await homeworkService.getHomeworkDetails(schoolId, id);

    return ApiResponse.success(data, "Homework details retrieved successfully");
  } catch (error: any) {
    return ApiResponse.notFound(
      error.message || "Homework assignment not found",
    );
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
      return ApiResponse.forbidden(
        "Students cannot update homework assignments",
      );
    }

    const body = await req.json();
    const homeworkService = new HomeworkService();
    const isFaculty = role === UserRole.FACULTY;

    let facultyId = "";
    if (isFaculty) {
      const facultyService = new FacultyService();
      const faculty = await facultyService.getFacultyByUserId(schoolId, userId);
      facultyId = faculty.id;
    }

    const data = await homeworkService.updateHomework(
      schoolId,
      id,
      facultyId,
      isFaculty,
      body,
    );

    return ApiResponse.success(
      data,
      "Homework assignment updated successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to update homework assignment",
    );
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
      return ApiResponse.forbidden(
        "Students cannot delete homework assignments",
      );
    }

    const homeworkService = new HomeworkService();
    const isFaculty = role === UserRole.FACULTY;

    let facultyId = "";
    if (isFaculty) {
      const facultyService = new FacultyService();
      const faculty = await facultyService.getFacultyByUserId(schoolId, userId);
      facultyId = faculty.id;
    }

    await homeworkService.deleteHomework(schoolId, id, facultyId, isFaculty);

    return ApiResponse.success(
      null,
      "Homework assignment deleted successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to delete homework assignment",
    );
  }
}

