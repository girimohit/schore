import { NextRequest } from "next/server";
import { StudentService } from "../../../src/services/student.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole, StudentStatus } from "@schore/database";

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    const { searchParams } = new URL(req.url);
    const classId = searchParams.get("classId") || undefined;
    const sectionId = searchParams.get("sectionId") || undefined;
    const status = (searchParams.get("status") as StudentStatus) || undefined;
    const search = searchParams.get("search") || undefined;
    const limit = parseInt(searchParams.get("limit") || "20", 10);
    const offset = parseInt(searchParams.get("offset") || "0", 10);

    const studentService = new StudentService();

    // RBAC check
    if (role === UserRole.STUDENT) {
      // Students cannot view list of other students
      return ApiResponse.forbidden("Students cannot list student records");
    }

    if (role === UserRole.FACULTY) {
      // Faculty can only view students in their assigned classes/sections
      const data = await studentService.searchStudentsForFaculty(
        schoolId,
        userId,
        {
          classId,
          sectionId,
          status,
          search,
          take: limit,
          skip: offset,
        },
      );
      return ApiResponse.success(data, "Students retrieved successfully");
    }

    // Admins get access to all students
    const data = await studentService.searchStudents(schoolId, {
      classId,
      sectionId,
      status,
      search,
      take: limit,
      skip: offset,
    });
    return ApiResponse.success(data, "Students retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to search students");
  }
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== UserRole.SUPER_ADMIN && role !== UserRole.SCHOOL_ADMIN) {
      return ApiResponse.forbidden("Only administrators can create students");
    }

    const body = await req.json();
    const studentService = new StudentService();
    const data = await studentService.createStudent(schoolId, body);

    return ApiResponse.success(data, "Student created successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to create student");
  }
}
