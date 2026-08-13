import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../../src/utils/response";
import { UserRole } from "@schore/database";
import { z } from "zod";

const resendSchema = z.object({
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
      return ApiResponse.forbidden("Only administrators can resend invitations");
    }

    const body = await req.json();
    const result = resendSchema.safeParse(body);

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

    if (user.status === "ACTIVE") {
      return ApiResponse.badRequest("This user account is already active.");
    }

    const normalizedEmail = user.email ? user.email.trim().toLowerCase() : "";

    const crypto = await import("crypto");
    const inviteToken = crypto.randomBytes(32).toString("hex");
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await prisma.$transaction(async (tx) => {
      // Revoke any existing invitation for this user
      await tx.invitation.updateMany({
        where: { userId: user.id },
        data: { status: "REVOKED" },
      });

      // Create new invitation
      await tx.invitation.create({
        data: {
          schoolId,
          email: normalizedEmail,
          role: user.role,
          token: inviteToken,
          status: "INVITED",
          expiresAt,
          userId: user.id,
        },
      });

      // Ensure user status is INACTIVE
      await tx.user.update({
        where: { id: user.id },
        data: { status: "INACTIVE" },
      });
    });

    const inviteLink = `http://localhost:3000/onboarding?token=${inviteToken}`;
    const { NotificationService } = await import("../../../../../src/services/notification.service");
    const notificationService = new NotificationService();
    await notificationService.sendInvitation({
      email: normalizedEmail,
      phone: user.phone || undefined,
      role: user.role,
      inviteLink,
    });

    return ApiResponse.success({ token: inviteToken }, "Invitation resent successfully");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to resend invitation");
  }
}
