import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../../src/utils/response";
import { UserRole } from "@schore/database";
import { z } from "zod";

const revokeSchema = z.object({
  email: z.string().email("Invalid email address").optional(),
  userId: z.string().optional(),
}).refine(data => data.email || data.userId, {
  message: "Either email or userId must be provided",
});

export async function POST(req: NextRequest) {
  try {
    const adminRole = req.headers.get("x-user-role") as UserRole;
    const schoolId = req.headers.get("x-school-id");

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (adminRole !== UserRole.SCHOOL_ADMIN && adminRole !== UserRole.SUPER_ADMIN) {
      return ApiResponse.forbidden("Only administrators can revoke invitations");
    }

    const body = await req.json();
    const result = revokeSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const { email, userId } = result.data;

    const user = await prisma.user.findFirst({
      where: {
        schoolId,
        OR: [
          ...(email ? [{ email: email.trim().toLowerCase() }] : []),
          ...(userId ? [{ id: userId }] : []),
        ],
      },
    });

    if (!user) {
      return ApiResponse.notFound("User not found");
    }

    await prisma.$transaction(async (tx) => {
      // Revoke any existing invitations
      await tx.invitation.updateMany({
        where: { userId: user.id },
        data: { status: "REVOKED" },
      });

      // Keep user as INACTIVE/SUSPENDED
      await tx.user.update({
        where: { id: user.id },
        data: { status: "INACTIVE" },
      });
    });

    return ApiResponse.success(null, "Invitation revoked successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to revoke invitation");
  }
}
