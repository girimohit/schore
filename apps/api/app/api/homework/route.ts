import { NextRequest } from "next/server";
import { HomeworkService } from "../../../src/services/homework.service";
import { StudentService } from "../../../src/services/student.service";
import { FacultyService } from "../../../src/services/faculty.service";
import { ApiResponse } from "../../../src/utils/response";
import { UserRole, prisma } from "@schore/database";

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
      const data = await homeworkService.getStudentHomework(
        schoolId,
        student.id,
      );
      return ApiResponse.success(
        data,
        "Student homework retrieved successfully",
      );
    }

    // Faculty or Admins can search lists of homework
    const { searchParams } = new URL(req.url);
    const classId = searchParams.get("classId") || undefined;
    const sectionId = searchParams.get("sectionId") || undefined;
    const subjectId = searchParams.get("subjectId") || undefined;

    let facultyId = searchParams.get("facultyId") || undefined;
    if (role === UserRole.FACULTY && !facultyId) {
      const facultyService = new FacultyService();
      try {
        const faculty = await facultyService.getFacultyByUserId(schoolId, userId);
        facultyId = faculty.id;
      } catch {
        // if faculty profile not found yet, fall back to undefined
      }
    }

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
      return ApiResponse.forbidden(
        "Students cannot create homework assignments",
      );
    }

    const body = await req.json();
    const homeworkService = new HomeworkService();
    const isFaculty = role === UserRole.FACULTY;

    let targetFacultyId = body.facultyId;

    if (isFaculty) {
      const facultyService = new FacultyService();
      const faculty = await facultyService.getFacultyByUserId(schoolId, userId);
      targetFacultyId = faculty.id;
    } else if (!targetFacultyId) {
      // For Admin, if not specified, find first faculty or create with first available faculty in school
      const firstFaculty = await prisma.faculty.findFirst({
        where: { schoolId },
      });
      if (!firstFaculty) {
        return ApiResponse.badRequest("No faculty registered in this school to assign homework with. Please add faculty first.");
      }
      targetFacultyId = firstFaculty.id;
    }

    const data = await homeworkService.createHomework(
      schoolId,
      targetFacultyId,
      isFaculty,
      body,
    );

    return ApiResponse.success(
      data,
      "Homework assignment created successfully",
      201,
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to create homework assignment",
    );
  }
}

