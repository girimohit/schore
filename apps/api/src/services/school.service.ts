import { SchoolRepository } from "../repositories/school.repository";
import { prisma } from "@schore/database";
import { generateInvitationToken } from "../utils/jwt";
import bcrypt from "bcryptjs";

export class SchoolService {
  private schoolRepository = new SchoolRepository();

  async getSchoolById(id: string) {
    const school = await this.schoolRepository.findById(id);
    if (!school) {
      throw new Error("School not found");
    }
    return school;
  }

  async getBranding(schoolId: string) {
    const branding =
      await this.schoolRepository.findBrandingBySchoolId(schoolId);
    if (!branding) {
      throw new Error("Branding configuration not found for school");
    }
    return branding;
  }

  async getFeatures(schoolId: string) {
    const features =
      await this.schoolRepository.findFeaturesBySchoolId(schoolId);
    if (!features) {
      throw new Error("Feature flags configuration not found for school");
    }
    return features;
  }

  async provisionSchool(input: {
    name: string;
    code: string;
    email?: string;
    phone?: string;
    address?: string;

    academicYearName: string;
    academicYearStartDate: Date;
    academicYearEndDate: Date;

    adminEmail: string;
    adminPhone?: string;

    appName?: string;
    logoUrl?: string;
    primaryColor?: string;
    secondaryColor?: string;
    fontFamily?: string;
    themeMode?: string;

    features?: {
      attendance?: boolean;
      homework?: boolean;
      exams?: boolean;
      notices?: boolean;
      remarks?: boolean;
      timetable?: boolean;
    };

    subscriptionPlan?: string;
    subscriptionDurationDays?: number;
  }) {
    // 1. Unique validations
    const existingSchool = await prisma.school.findUnique({
      where: { code: input.code },
    });
    if (existingSchool) {
      throw new Error(`School code "${input.code}" is already taken.`);
    }

    const existingUser = await prisma.user.findFirst({
      where: { email: input.adminEmail },
    });
    if (existingUser) {
      throw new Error(
        `Admin user email "${input.adminEmail}" is already registered.`,
      );
    }

    // 2. Database Transaction
    const result = await prisma.$transaction(async (tx) => {
      // Create School
      const school = await tx.school.create({
        data: {
          name: input.name,
          code: input.code,
          email: input.email,
          phone: input.phone,
          address: input.address,
          status: "PENDING",
        },
      });

      // Create default Branding
      await tx.schoolBranding.create({
        data: {
          schoolId: school.id,
          appName: input.appName || "Schore ERP",
          logoUrl: input.logoUrl || null,
          primaryColor: input.primaryColor || "#6366F1",
          secondaryColor: input.secondaryColor || "#4F46E5",
          fontFamily: input.fontFamily || "Inter",
          themeMode: input.themeMode || "DARK",
        },
      });

      // Create Features
      await tx.schoolFeatures.create({
        data: {
          schoolId: school.id,
          attendance: input.features?.attendance !== false,
          homework: input.features?.homework !== false,
          exams: input.features?.exams !== false,
          notices: input.features?.notices !== false,
          remarks: input.features?.remarks !== false,
          timetable: input.features?.timetable !== false,
        },
      });

      // Create Subscription
      const startDate = new Date();
      const endDate = new Date();
      endDate.setDate(
        endDate.getDate() + (input.subscriptionDurationDays || 14),
      );
      await tx.schoolSubscription.create({
        data: {
          schoolId: school.id,
          plan: input.subscriptionPlan || "TRIAL",
          status: "ACTIVE",
          startDate,
          endDate,
        },
      });

      // Create initial AcademicYear
      await tx.academicYear.create({
        data: {
          schoolId: school.id,
          name: input.academicYearName,
          startDate: input.academicYearStartDate,
          endDate: input.academicYearEndDate,
          isCurrent: true,
        },
      });

      // Generate secure dummy password hash (overwritten at setup)
      const randomSeed = Math.random().toString(36).substring(7);
      const passwordHash = await bcrypt.hash(`DUMMY_${randomSeed}`, 12);

      // Create School Admin User (INACTIVE until activation/password setup)
      const user = await tx.user.create({
        data: {
          schoolId: school.id,
          email: input.adminEmail,
          phone: input.adminPhone,
          passwordHash,
          role: "SCHOOL_ADMIN",
          status: "INACTIVE",
        },
      });

      // Create Audit Log
      await tx.auditLog.create({
        data: {
          schoolId: school.id,
          userId: user.id,
          action: "SCHOOL_PROVISION",
          entity: "School",
          entityId: school.id,
          metadata: {
            provisionedBy: "SUPER_ADMIN",
            adminEmail: input.adminEmail,
            plan: input.subscriptionPlan || "TRIAL",
          },
        },
      });

      return { school, user };
    });

    // 3. Generate Secure Invitation Token
    const inviteToken = generateInvitationToken({
      userId: result.user.id,
      schoolId: result.school.id,
      email: result.user.email!,
    });

    return {
      school: result.school,
      user: result.user,
      inviteToken,
    };
  }

  async listSchools(params: {
    search?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) {
    const page = params.page || 1;
    const limit = params.limit || 10;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (params.search) {
      where.OR = [
        { name: { contains: params.search, mode: "insensitive" } },
        { code: { contains: params.search, mode: "insensitive" } },
      ];
    }
    if (params.status) {
      where.status = params.status;
    }

    const [schools, total] = await Promise.all([
      prisma.school.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: "desc" },
        include: {
          branding: true,
          features: true,
          subscription: true,
          _count: {
            select: {
              students: true,
              faculty: true,
            },
          },
        },
      }),
      prisma.school.count({ where }),
    ]);

    return {
      schools,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async updateSchoolStatus(
    id: string,
    status: "ACTIVE" | "SUSPENDED" | "INACTIVE",
    actorId: string,
  ) {
    const school = await prisma.school.findUnique({ where: { id } });
    if (!school) {
      throw new Error("School not found");
    }

    const updated = await prisma.$transaction(async (tx) => {
      const sch = await tx.school.update({
        where: { id },
        data: { status },
      });

      await tx.auditLog.create({
        data: {
          schoolId: id,
          userId: actorId,
          action: `SCHOOL_${status}`,
          entity: "School",
          entityId: id,
          metadata: {
            previousStatus: school.status,
            newStatus: status,
          },
        },
      });

      return sch;
    });

    return updated;
  }

  async updateSchoolDetails(
    id: string,
    data: {
      name?: string;
      email?: string;
      phone?: string;
      address?: string;
    },
  ) {
    const school = await prisma.school.findUnique({ where: { id } });
    if (!school) {
      throw new Error("School not found");
    }

    return prisma.school.update({
      where: { id },
      data,
    });
  }
}
