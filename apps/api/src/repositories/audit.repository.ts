import { prisma } from "@schore/database";

export interface CreateAuditLogInput {
  userId?: string;
  schoolId?: string;
  action: string;
  entity?: string;
  entityId?: string;
  metadata?: any;
}

export class AuditRepository {
  async create(data: CreateAuditLogInput) {
    return prisma.auditLog.create({
      data: {
        userId: data.userId || null,
        schoolId: data.schoolId || null,
        action: data.action,
        entity: data.entity || null,
        entityId: data.entityId || null,
        metadata: data.metadata || undefined,
      },
    });
  }

  async findBySchoolId(schoolId: string, limit = 50) {
    return prisma.auditLog.findMany({
      where: { schoolId },
      orderBy: { createdAt: "desc" },
      take: limit,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            role: true,
          },
        },
      },
    });
  }
}
