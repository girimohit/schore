import { NextRequest } from "next/server";
import { ExamService } from "../../../../../src/services/exam.service";
import { StudentService } from "../../../../../src/services/student.service";
import { ApiResponse } from "../../../../../src/utils/response";
import { UserRole, prisma } from "@schore/database";

async function getStudentReportCard(
  schoolId: string,
  examId: string,
  studentId: string,
) {
  const exam = await prisma.exam.findFirst({
    where: { id: examId, schoolId },
    include: {
      subjects: {
        include: {
          subject: true,
        },
      },
    },
  });

  if (!exam) {
    throw new Error("Exam not found");
  }

  const results = await prisma.result.findMany({
    where: {
      schoolId,
      examId,
      studentId,
    },
    include: {
      examSubject: {
        include: {
          subject: true,
        },
      },
    },
  });

  const scores = exam.subjects.map((sub: any) => {
    const result = results.find((r: any) => r.examSubjectId === sub.id);
    return {
      subject: { name: sub.subject.name },
      status: result ? result.status : "ABSENT",
      marks: result ? result.marks : 0,
      maxMarks: sub.maxMarks,
      passingMarks: sub.passingMarks,
    };
  });

  const totalMaxMarks = scores.reduce(
    (sum: number, s: any) => sum + s.maxMarks,
    0,
  );
  const totalMarks = scores.reduce((sum: number, s: any) => sum + s.marks, 0);
  const percentage =
    totalMaxMarks > 0 ? Math.round((totalMarks / totalMaxMarks) * 100) : 0;
  const status = scores.some((s: any) => s.status === "FAIL") ? "FAIL" : "PASS";
  let grade = "F";
  if (percentage >= 90) grade = "A+";
  else if (percentage >= 80) grade = "A";
  else if (percentage >= 70) grade = "B";
  else if (percentage >= 60) grade = "C";
  else if (percentage >= 50) grade = "D";

  return {
    exam: { id: exam.id, name: exam.name },
    scores,
    status,
    percentage,
    grade,
  };
}

export async function GET(
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

    const { searchParams } = new URL(req.url);
    let studentId = searchParams.get("studentId");

    if (role === UserRole.STUDENT) {
      const studentService = new StudentService();
      const student = await studentService.getStudentByUserId(schoolId, userId);
      studentId = student.id;
    }

    if (studentId) {
      const reportCard = await getStudentReportCard(schoolId, id, studentId);
      return ApiResponse.success(
        reportCard,
        "Report card retrieved successfully",
      );
    }

    // Faculty/Admins see the report card of the first student to satisfy shared mobile view
    const firstResult = await prisma.result.findFirst({
      where: { schoolId, examId: id },
    });
    if (firstResult) {
      const reportCard = await getStudentReportCard(
        schoolId,
        id,
        firstResult.studentId,
      );
      return ApiResponse.success(
        reportCard,
        "Report card retrieved successfully",
      );
    }

    const exam = await prisma.exam.findFirst({ where: { id, schoolId } });
    return ApiResponse.success(
      {
        exam: { id, name: exam?.name || "Exam" },
        scores: [],
        status: "PASS",
        percentage: 0,
        grade: "N/A",
      },
      "Report card retrieved successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to load exam results",
    );
  }
}

export async function POST(
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
      return ApiResponse.forbidden("Students cannot record exam results");
    }

    const body = await req.json();
    const examService = new ExamService();
    const isFaculty = role === UserRole.FACULTY;

    const data = await examService.recordResultsBatch(
      schoolId,
      id,
      userId,
      isFaculty,
      body,
    );

    return ApiResponse.success(data, "Exam results recorded successfully", 201);
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to record exam results",
    );
  }
}
