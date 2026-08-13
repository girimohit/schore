import { NextRequest } from "next/server";
import { prisma, UserRole, MarksSubmissionStatus } from "@schore/database";
import { ApiResponse } from "../../../../../../src/utils/response";
import { z } from "zod";

const reviewSchema = z.object({
  action: z.enum(["APPROVE", "REJECT", "REOPEN"]),
  remarks: z.string().optional().nullable(),
});

export async function POST(
  req: NextRequest,
  props: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await props.params;
    const adminRole = req.headers.get("x-user-role") as UserRole;
    const schoolId = req.headers.get("x-school-id");

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (adminRole !== UserRole.SCHOOL_ADMIN && adminRole !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Only administrators can review marks submissions");
    }

    const body = await req.json();
    const result = reviewSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const { action, remarks } = result.data;

    const submission = await prisma.marksSubmission.findFirst({
      where: { id, schoolId },
    });

    if (!submission) {
      return ApiResponse.notFound("Marks submission not found");
    }

    let nextStatus: MarksSubmissionStatus;

    if (action === "APPROVE") {
      nextStatus = MarksSubmissionStatus.FINALIZED;
    } else if (action === "REJECT") {
      nextStatus = MarksSubmissionStatus.SENT_BACK;
    } else {
      // REOPEN
      nextStatus = MarksSubmissionStatus.DRAFT;
    }

    const updated = await prisma.marksSubmission.update({
      where: { id },
      data: {
        status: nextStatus,
        remarks: action === "REJECT" ? remarks || "Sent back for corrections." : null,
      },
    });

    return ApiResponse.success(updated, `Marks submission ${action.toLowerCase()}d successfully`);
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to review marks submission");
  }
}
