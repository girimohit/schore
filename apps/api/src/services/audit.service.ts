import {
  AuditRepository,
  CreateAuditLogInput,
} from "../repositories/audit.repository";
import { NextRequest } from "next/server";

export class AuditService {
  private auditRepository = new AuditRepository();

  async log(input: CreateAuditLogInput) {
    try {
      return await this.auditRepository.create(input);
    } catch (error) {
      console.error("Failed to create audit log:", error);
    }
  }

  async logRequest(
    req: NextRequest,
    action: string,
    entity?: string,
    entityId?: string,
    userId?: string,
    schoolId?: string,
    metadata?: any,
  ) {
    return this.log({
      userId,
      schoolId,
      action,
      entity,
      entityId,
      metadata,
    });
  }

  async getLogsBySchool(schoolId: string, limit = 50) {
    return this.auditRepository.findBySchoolId(schoolId, limit);
  }
}
