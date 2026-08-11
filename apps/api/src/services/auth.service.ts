import { UserRepository } from "../repositories/user.repository";
import { verifyPassword } from "../utils/password";
import {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
} from "../utils/jwt";
import { getPermissionsForRole } from "../utils/permissions";
import { UserRole } from "@schore/database";

export class AuthService {
  private userRepository = new UserRepository();

  async login(email: string, password: string) {
    const user = await this.userRepository.findByEmail(email);
    if (!user) {
      throw new Error("Invalid email or password");
    }

    const isPasswordValid = await verifyPassword(password, user.passwordHash);
    if (!isPasswordValid) {
      throw new Error("Invalid email or password");
    }

    const payload = {
      userId: user.id,
      schoolId: user.schoolId || "",
      role: user.role,
    };

    const accessToken = generateAccessToken(payload);
    const refreshToken = generateRefreshToken(payload);

    // Save refresh token to DB with a 7 day expiry
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await this.userRepository.createRefreshToken(
      user.id,
      refreshToken,
      expiresAt,
    );

    // Resolve name fields from profile relations
    let firstName = "System";
    let lastName = "Admin";
    if (user.role === UserRole.FACULTY && user.faculty) {
      firstName = user.faculty.firstName;
      lastName = user.faculty.lastName || "";
    } else if (user.role === UserRole.STUDENT && user.student) {
      firstName = user.student.firstName;
      lastName = user.student.lastName || "";
    } else if (user.role === UserRole.SCHOOL_ADMIN) {
      firstName = "School";
      lastName = "Admin";
    }

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        firstName,
        lastName,
        schoolId: user.schoolId,
        role: user.role,
        permissions: getPermissionsForRole(user.role),
      },
    };
  }

  async refresh(token: string) {
    try {
      const payload = verifyRefreshToken(token);

      const storedToken = await this.userRepository.findRefreshToken(token);
      if (
        !storedToken ||
        storedToken.revokedAt ||
        storedToken.expiresAt < new Date()
      ) {
        throw new Error("Invalid or expired refresh token");
      }

      // Revoke the old refresh token
      await this.userRepository.revokeRefreshToken(token);

      const user = storedToken.user;
      const newPayload = {
        userId: user.id,
        schoolId: user.schoolId || "",
        role: user.role,
      };

      const newAccessToken = generateAccessToken(newPayload);
      const newRefreshToken = generateRefreshToken(newPayload);

      // Save new refresh token
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7);
      await this.userRepository.createRefreshToken(
        user.id,
        newRefreshToken,
        expiresAt,
      );

      return {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      };
    } catch (error) {
      throw new Error("Invalid refresh token");
    }
  }

  async logout(token: string) {
    try {
      await this.userRepository.revokeRefreshToken(token);
      return true;
    } catch (error) {
      // Return true anyway because the token is effectively dead or invalid
      return true;
    }
  }
}
