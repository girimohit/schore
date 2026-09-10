import { prisma } from "@schore/database";

const CACHE_TTL_MS = 45 * 1000; // 45 seconds in-memory TTL

interface CachedPlatformConfig {
  maintenanceMode: boolean;
  cachedAt: number;
}

interface CachedSchoolEntitlement {
  status: string;
  subscription: {
    status: string;
    endDate: Date;
  } | null;
  features: Record<string, boolean> | null;
  cachedAt: number;
}

let cachedPlatformConfig: CachedPlatformConfig | null = null;
const schoolEntitlementCache = new Map<string, CachedSchoolEntitlement>();

/**
 * Invalidate platform config cache
 */
export function invalidatePlatformConfigCache() {
  cachedPlatformConfig = null;
}

/**
 * Invalidate school entitlement cache for a specific school or globally
 */
export function invalidateSchoolEntitlementCache(schoolId?: string) {
  if (schoolId) {
    schoolEntitlementCache.delete(schoolId);
  } else {
    schoolEntitlementCache.clear();
  }
}

/**
 * Get platform config with in-memory caching
 */
export async function getCachedPlatformConfig(): Promise<CachedPlatformConfig> {
  const now = Date.now();
  if (
    cachedPlatformConfig &&
    now - cachedPlatformConfig.cachedAt < CACHE_TTL_MS
  ) {
    return cachedPlatformConfig;
  }

  const config = await prisma.platformConfig.findFirst();
  cachedPlatformConfig = {
    maintenanceMode: config?.maintenanceMode ?? false,
    cachedAt: now,
  };
  return cachedPlatformConfig;
}

/**
 * Get school entitlement metadata (status, subscription, features)
 * Uses single consolidated query and in-memory cache
 */
export async function getCachedSchoolEntitlement(
  schoolId: string,
): Promise<CachedSchoolEntitlement> {
  const now = Date.now();
  const cached = schoolEntitlementCache.get(schoolId);
  if (cached && now - cached.cachedAt < CACHE_TTL_MS) {
    return cached;
  }

  // Single consolidated query fetching school, subscription, and feature flags
  const school = await prisma.school.findUnique({
    where: { id: schoolId },
    include: {
      subscription: true,
      features: true,
    },
  });

  if (!school) {
    throw new Error("School configuration not found.");
  }

  const entitlement: CachedSchoolEntitlement = {
    status: school.status,
    subscription: school.subscription
      ? {
          status: school.subscription.status,
          endDate: school.subscription.endDate,
        }
      : null,
    features: school.features
      ? {
          attendance: school.features.attendance,
          homework: school.features.homework,
          exams: school.features.exams,
          notices: school.features.notices,
          remarks: school.features.remarks,
          timetable: school.features.timetable,
        }
      : null,
    cachedAt: now,
  };

  schoolEntitlementCache.set(schoolId, entitlement);
  return entitlement;
}

export async function enforceEntitlement(
  schoolId: string,
  feature:
    | "attendance"
    | "homework"
    | "exams"
    | "notices"
    | "remarks"
    | "timetable",
): Promise<void> {
  // 1. Global Maintenance Mode Check (cached in-memory, 0ms)
  const platformConfig = await getCachedPlatformConfig();
  if (platformConfig.maintenanceMode) {
    throw new Error(
      "The platform is currently undergoing maintenance. Please try again later.",
    );
  }

  // 2. School Status and Subscription Checks (cached in-memory, 0ms on hit, 1 DB query on miss)
  const school = await getCachedSchoolEntitlement(schoolId);

  if (school.status === "SUSPENDED") {
    throw new Error(
      "Your school access has been suspended. Please contact support.",
    );
  }

  if (school.status === "INACTIVE" || school.status === "PENDING") {
    throw new Error(
      "Your school account is currently inactive. Please contact support.",
    );
  }

  const sub = school.subscription;
  if (!sub || sub.status !== "ACTIVE" || new Date(sub.endDate) < new Date()) {
    throw new Error(
      "Your school subscription has expired or is inactive. Please contact support.",
    );
  }

  // 3. Feature Gating Check
  if (school.features && !school.features[feature]) {
    throw new Error(
      `This module is not enabled for your school. Please contact support.`,
    );
  }
}
