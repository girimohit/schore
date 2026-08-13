import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../../src/utils/response";
import bcrypt from "bcryptjs";
import { z } from "zod";

const acceptSchema = z.object({
  token: z.string().min(1, "Token is required"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const result = acceptSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const { token, password } = result.data;

    const invitation = await prisma.invitation.findUnique({
      where: { token },
    });

    if (!invitation) {
      return ApiResponse.notFound("Invitation not found or invalid token");
    }

    if (invitation.status === "REVOKED") {
      return ApiResponse.badRequest("This invitation has been revoked.");
    }

    if (invitation.status === "ACTIVE") {
      return ApiResponse.badRequest("This invitation has already been accepted.");
    }

    if (new Date(invitation.expiresAt) < new Date()) {
      await prisma.invitation.update({
        where: { id: invitation.id },
        data: { status: "EXPIRED" },
      });
      return ApiResponse.badRequest("This invitation token has expired.");
    }

    if (!invitation.userId) {
      return ApiResponse.badRequest("Invitation is not linked to any user.");
    }

    const passwordHash = await bcrypt.hash(password, 12);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: invitation.userId },
        data: {
          passwordHash,
          status: "ACTIVE",
        },
      }),
      prisma.invitation.update({
        where: { id: invitation.id },
        data: {
          status: "ACTIVE",
        },
      }),
    ]);

    return ApiResponse.success(null, "Onboarding complete. Your account is now active.");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to accept invitation");
  }
}
