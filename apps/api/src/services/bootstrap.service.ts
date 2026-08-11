import { UserRepository } from "../repositories/user.repository";
import { SchoolRepository } from "../repositories/school.repository";
import { getPermissionsForRole } from "../utils/permissions";

export class BootstrapService {
  private userRepository = new UserRepository();
  private schoolRepository = new SchoolRepository();

  async getBootstrapData(
    userId: string,
    schoolId: string,
    appVersion: string | null,
  ) {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new Error("User not found");
    }

    const school = await this.schoolRepository.findById(schoolId);
    if (!school) {
      throw new Error("School not found");
    }

    const minVersion = process.env.MIN_SUPPORTED_APP_VERSION || "1.0.0";
    const latestVersion = process.env.LATEST_APP_VERSION || "1.0.0";

    let forceUpdate = false;
    if (appVersion) {
      forceUpdate = !this.isVersionCompatible(appVersion, minVersion);
    }

    return {
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
      },
      school: {
        id: school.id,
        name: school.name,
        code: school.code,
      },
      branding: school.branding,
      featureFlags: {
        attendance: school.features?.attendance ?? false,
        homework: school.features?.homework ?? false,
        exams: school.features?.exams ?? false,
        notices: school.features?.notices ?? false,
        remarks: school.features?.remarks ?? false,
        timetable: school.features?.timetable ?? false,
      },
      permissions: getPermissionsForRole(user.role),
      appVersion: {
        minimumSupportedVersion: minVersion,
        latestVersion: latestVersion,
        forceUpdate,
      },
    };
  }

  private isVersionCompatible(appVersion: string, minVersion: string): boolean {
    const appParts = appVersion.split(".").map(Number);
    const minParts = minVersion.split(".").map(Number);
    for (let i = 0; i < 3; i++) {
      const appPart = appParts[i] || 0;
      const minPart = minParts[i] || 0;
      if (appPart > minPart) return true;
      if (appPart < minPart) return false;
    }
    return true;
  }
}
