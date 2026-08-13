import { NextRequest } from "next/server";
import { prisma, UserRole, MarksSubmissionStatus } from "@schore/database";
import { ApiResponse } from "../../../../src/utils/response";
import { z } from "zod";

const submissionCreateSchema = z.object({
  examId: z.string().min(1, "Exam ID is required"),
  subjectId: z.string().min(1, "Subject ID is required"),
  classId: z.string().min(1, "Class ID is required"),
  sectionId: z.string().optional().nullable(),
  status: z.enum([MarksSubmissionStatus.DRAFT, MarksSubmissionStatus.SUBMITTED_FOR_REVIEW]),
});

export async function GET(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role") as UserRole;
    const userId = req.headers.get("x-user-id");

    if (!schoolId || !role || !userId) {
      return ApiResponse.unauthorized("Authentication context missing");
    }

    if (role === UserRole.STUDENT) {
      return ApiResponse.forbidden("Students cannot access marks submission states");
    }

    let submissions;

    if (role === UserRole.SCHOOL_ADMIN || role === UserRole.SUPER_ADMIN) {
      // Admins see all submissions in the school
      submissions = await prisma.marksSubmission.findMany({
        where: { schoolId },
        include: {
          exam: true,
          subject: true,
          class: true,
          section: true,
          teacher: true,
        },
        orderBy: { updatedAt: "desc" },
      });
    } else {
      // Faculty see their own submissions
      submissions = await prisma.marksSubmission.findMany({
        where: { schoolId, teacherId: userId },
        include: {
          exam: true,
          subject: true,
          class: true,
          section: true,
          teacher: true,
        },
        orderBy: { updatedAt: "desc" },
      });
    }

    return ApiResponse.success(submissions, "Submissions list retrieved successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to fetch submissions");
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

    if (role !== UserRole.FACULTY) {
      return ApiResponse.forbidden("Only faculty members can submit student marks");
    }

    const body = await req.json();
    const result = submissionCreateSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const { examId, subjectId, classId, sectionId, status } = result.data;

    // Check if the teacher is currently finalized or in review
    const existing = await prisma.marksSubmission.findFirst({
      where: {
        examId,
        subjectId,
        classId,
        sectionId: sectionId || null,
      },
    });

    if (existing && (existing.status === MarksSubmissionStatus.FINALIZED || existing.status === MarksSubmissionStatus.SUBMITTED_FOR_REVIEW) && existing.teacherId !== userId) {
      return ApiResponse.badRequest("This subject marks have already been submitted/finalized by another teacher.");
    }

    if (existing && existing.status === MarksSubmissionStatus.FINALIZED) {
      return ApiResponse.badRequest("This subject marks have already been finalized and locked.");
    }

    const upserted = await prisma.marksSubmission.upsert({
      where: {
        examId_subjectId_classId_sectionId: {
          examId,
          subjectId,
          classId,
          sectionId: (sectionId || null) as any,
        },
      },
      update: {
        status,
        teacherId: userId,
        remarks: null, // Clear remarks on resubmit/update
      },
      create: {
        schoolId,
        examId,
        subjectId,
        classId,
        sectionId: sectionId || null,
        teacherId: userId,
        status,
      },
    });

    return ApiResponse.success(upserted, "Marks submission recorded successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to submit marks");
  }
}
