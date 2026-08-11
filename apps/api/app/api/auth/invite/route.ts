import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@schore/database";
import {
  verifyInvitationToken,
  generateAccessToken,
  generateRefreshToken,
} from "../../../../src/utils/jwt";
import { ApiResponse } from "../../../../src/utils/response";
import { getPermissionsForRole } from "../../../../src/utils/permissions";
import bcrypt from "bcryptjs";

const setupSchema = z.object({
  token: z.string().min(1, "Token is required"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const result = setupSchema.safeParse(body);

    if (!result.success) {
      return ApiResponse.badRequest("Validation failed", result.error.format());
    }

    const { token, password } = result.data;
    const decoded = verifyInvitationToken(token);

    const session = await prisma.$transaction(
      async (tx) => {
        const user = await tx.user.findUnique({
          where: { id: decoded.userId },
          include: { school: true },
        });

        if (!user) {
          throw new Error("Invitation user not found.");
        }

        if (user.status !== "INACTIVE") {
          throw new Error("Invitation has already been accepted.");
        }

        const passwordHash = await bcrypt.hash(password, 12);

        const updatedUser = await tx.user.update({
          where: { id: user.id },
          data: {
            passwordHash,
            status: "ACTIVE",
          },
        });

        if (user.schoolId) {
          await tx.school.update({
            where: { id: user.schoolId },
            data: { status: "ACTIVE" },
          });
        }

        await tx.auditLog.create({
          data: {
            schoolId: user.schoolId,
            userId: user.id,
            action: "SCHOOL_ADMIN_ACTIVATION",
            entity: "User",
            entityId: user.id,
            metadata: {
              email: user.email,
            },
          },
        });

        return { user: updatedUser, school: user.school };
      },
      {
        maxWait: 20000,
        timeout: 30000,
      },
    );

    const payload = {
      userId: session.user.id,
      schoolId: session.user.schoolId || "",
      role: session.user.role,
    };

    const accessToken = generateAccessToken(payload);
    const refreshToken = generateRefreshToken(payload);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);
    await prisma.refreshToken.create({
      data: {
        userId: session.user.id,
        token: refreshToken,
        expiresAt,
      },
    });

    return ApiResponse.success(
      {
        accessToken,
        refreshToken,
        user: {
          id: session.user.id,
          email: session.user.email,
          firstName: "School",
          lastName: "Admin",
          schoolId: session.user.schoolId,
          role: session.user.role,
          permissions: getPermissionsForRole(session.user.role),
        },
      },
      "Account activated successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to setup credentials",
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const token = searchParams.get("token");

    if (!token) {
      return ApiResponse.badRequest("Missing invitation token");
    }

    const decoded = verifyInvitationToken(token);

    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      include: { school: true },
    });

    if (!user) {
      return ApiResponse.badRequest(
        "Invalid invitation payload: user not found",
      );
    }

    if (user.status !== "INACTIVE") {
      return ApiResponse.badRequest("Invitation has already been processed");
    }

    return ApiResponse.success(
      {
        email: user.email,
        schoolName: user.school?.name,
        schoolCode: user.school?.code,
      },
      "Invitation is valid",
    );
  } catch (error: any) {
    return ApiResponse.badRequest("Invalid or expired invitation token");
  }
}
