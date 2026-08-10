import { prisma } from "@schore/database";

export interface CreateAuditLogInput {
  userId?: string;
  schoolId?: string;
  action: string;
  entity: string;
  entityId?: string;
  payload?: any;
  ipAddress?: string;
  userAgent?: string;
}

export class AuditRepository {
  async create(data: CreateAuditLogInput) {
    return prisma.auditLog.create({
      data: {
        userId: data.userId || null,
        schoolId: data.schoolId || null,
        action: data.action,
        entity: data.entity,
        entityId: data.entityId || null,
        payload: data.payload || undefined,
        ipAddress: data.ipAddress || null,
        userAgent: data.userAgent || null,
      },
    });
  }

  async findBySchoolId(schoolId: string, limit = 50) {
    return prisma.auditLog.findMany({
      where: { schoolId },
      orderBy: { timestamp: "desc" },
      take: limit,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
          },
        },
      },
    });
  }
}
