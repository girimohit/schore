import { NextRequest } from "next/server";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../../src/utils/response";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const token = searchParams.get("token");

    if (!token) {
      return ApiResponse.badRequest("Token parameter is required");
    }

    const invitation = await prisma.invitation.findUnique({
      where: { token },
      include: {
        school: {
          include: {
            branding: true,
          },
        },
      },
    });

    if (!invitation) {
      return ApiResponse.notFound("Invitation not found or invalid token");
    }

    if (invitation.status === "REVOKED") {
      return ApiResponse.badRequest("This invitation has been revoked.");
    }

    if (invitation.status === "ACTIVE") {
      return ApiResponse.badRequest("This invitation token has already been used.");
    }

    if (new Date(invitation.expiresAt) < new Date()) {
      await prisma.invitation.update({
        where: { id: invitation.id },
        data: { status: "EXPIRED" },
      });
      return ApiResponse.badRequest("This invitation token has expired.");
    }

    if (invitation.status === "INVITED") {
      await prisma.invitation.update({
        where: { id: invitation.id },
        data: { status: "ONBOARDING" },
      });
    }

    return ApiResponse.success({
      email: invitation.email,
      role: invitation.role,
      school: {
        name: invitation.school.name,
        branding: invitation.school.branding,
      },
    }, "Invitation is valid");
  } catch (error: any) {
    return ApiResponse.badRequest(error.message || "Failed to validate invitation");
  }
}
