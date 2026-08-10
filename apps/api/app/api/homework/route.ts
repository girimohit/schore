import { NextRequest } from "next/server";
import { HomeworkService } from "../../../src/services/homework.service";
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

    const homeworkService = new HomeworkService();

    if (role === UserRole.STUDENT) {
      // Students view their own assigned homework
      const studentService = new StudentService();
      const student = await studentService.getStudentByUserId(schoolId, userId);
      const data = await homeworkService.getStudentHomework(schoolId, student.id);
      return ApiResponse.success(data, "Student homework retrieved successfully");
    }

    // Faculty or Admins can search lists of homework
    const { searchParams } = new URL(req.url);
    const classId = searchParams.get("classId") || undefined;
    const sectionId = searchParams.get("sectionId") || undefined;
    const subjectId = searchParams.get("subjectId") || undefined;
    const facultyId = role === UserRole.FACULTY ? userId : (searchParams.get("facultyId") || undefined);

    const data = await homeworkService.getHomeworkList(schoolId, {
      classId,
      sectionId,
      subjectId,
      facultyId,
    });

    return ApiResponse.success(data, "Homework list retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to load homework");
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
      return ApiResponse.forbidden("Students cannot create homework assignments");
    }

    const body = await req.json();
    const homeworkService = new HomeworkService();
    const isFaculty = role === UserRole.FACULTY;

    const data = await homeworkService.createHomework(schoolId, userId, isFaculty, body);

    return ApiResponse.success(data, "Homework assignment created successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to create homework assignment");
  }
}
