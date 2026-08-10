import { AuditRepository, CreateAuditLogInput } from "../repositories/audit.repository";
import { NextRequest } from "next/server";

export class AuditService {
  private auditRepository = new AuditRepository();

  async log(input: CreateAuditLogInput) {
    try {
      return await this.auditRepository.create(input);
    } catch (error) {
      // In production, we would log this to a monitoring system, but not fail the user action
      console.error("Failed to create audit log:", error);
    }
  }

  async logRequest(
    req: NextRequest,
    action: string,
    entity: string,
    entityId?: string,
    userId?: string,
    schoolId?: string,
    payload?: any
  ) {
    const ipAddress = req.headers.get("x-forwarded-for") || req.headers.get("x-real-ip") || undefined;
    const userAgent = req.headers.get("user-agent") || undefined;

    return this.log({
      userId,
      schoolId,
      action,
      entity,
      entityId,
      payload,
      ipAddress,
      userAgent,
    });
  }

  async getLogsBySchool(schoolId: string, limit = 50) {
    return this.auditRepository.findBySchoolId(schoolId, limit);
  }
}
