import { z } from "zod";
import { NoticeRepository } from "../repositories/notice.repository";
import { StudentRepository } from "../repositories/student.repository";
import { NoticeAudience } from "@schore/database";
import { enforceEntitlement } from "../utils/entitlements";

const audienceEnum = z.nativeEnum(NoticeAudience);

export const createNoticeSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().min(1, "Description is required"),
  audience: audienceEnum,
  classId: z.string().optional(),
  sectionId: z.string().optional(),
  expiresAt: z.coerce.date().optional(),
  attachmentUrl: z.string().url().optional().or(z.literal("")),
});

export const updateNoticeSchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
  audience: audienceEnum.optional(),
  classId: z.string().optional(),
  sectionId: z.string().optional(),
  expiresAt: z.coerce.date().optional(),
  attachmentUrl: z.string().url().optional().or(z.literal("")),
});

export class NoticeService {
  private noticeRepository = new NoticeRepository();
  private studentRepository = new StudentRepository();

  async createNotice(schoolId: string, isFaculty: boolean, input: unknown) {
    await enforceEntitlement(schoolId, "notices");
    const data = createNoticeSchema.parse(input);

    if (isFaculty) {
      if (
        data.audience === NoticeAudience.SCHOOL ||
        data.audience === NoticeAudience.FACULTY
      ) {
        throw new Error(
          "Faculty members cannot publish school-wide or faculty-wide notices",
        );
      }
    }

    return this.noticeRepository.createNotice(schoolId, data);
  }

  async updateNotice(
    schoolId: string,
    id: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    await enforceEntitlement(schoolId, "notices");
    const data = updateNoticeSchema.parse(input);

    const existing = await this.noticeRepository.findById(schoolId, id);
    if (!existing) {
      throw new Error("Notice not found");
    }

    if (isFaculty) {
      if (
        data.audience === NoticeAudience.SCHOOL ||
        data.audience === NoticeAudience.FACULTY
      ) {
        throw new Error(
          "Faculty members cannot publish school-wide or faculty-wide notices",
        );
      }
    }

    return this.noticeRepository.updateNotice(schoolId, id, data);
  }

  async deleteNotice(schoolId: string, id: string) {
    await enforceEntitlement(schoolId, "notices");
    const existing = await this.noticeRepository.findById(schoolId, id);
    if (!existing) {
      throw new Error("Notice not found");
    }
    return this.noticeRepository.deleteNotice(schoolId, id);
  }

  async getNoticeDetails(schoolId: string, id: string) {
    await enforceEntitlement(schoolId, "notices");
    const notice = await this.noticeRepository.findById(schoolId, id);
    if (!notice) {
      throw new Error("Notice not found");
    }
    return notice;
  }

  async getNoticesForUser(schoolId: string, role: string, userId: string) {
    await enforceEntitlement(schoolId, "notices");
    let classId: string | undefined;
    let sectionId: string | undefined;

    if (role === "STUDENT") {
      const student = await this.studentRepository.findByUserId(
        schoolId,
        userId,
      );
      if (student) {
        const activeEnrollment = student.enrollments.find(
          (e) => e.status === "ACTIVE",
        );
        if (activeEnrollment) {
          classId = activeEnrollment.classId;
          sectionId = activeEnrollment.sectionId;
        }
      }
    }

    return this.noticeRepository.findNoticesForUser(schoolId, {
      role,
      classId,
      sectionId,
    });
  }
}
