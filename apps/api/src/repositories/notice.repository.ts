import { prisma, NoticeAudience } from "@schore/database";

export interface CreateNoticeInput {
  title: string;
  description: string;
  audience: NoticeAudience;
  classId?: string;
  sectionId?: string;
  expiresAt?: Date;
  attachmentUrl?: string;
}

export class NoticeRepository {
  async createNotice(schoolId: string, data: CreateNoticeInput) {
    return prisma.notice.create({
      data: {
        schoolId,
        title: data.title,
        description: data.description,
        audience: data.audience,
        classId: data.classId || null,
        sectionId: data.sectionId || null,
        expiresAt: data.expiresAt || null,
        attachmentUrl: data.attachmentUrl || null,
      },
    });
  }

  async updateNotice(
    schoolId: string,
    id: string,
    data: Partial<CreateNoticeInput>,
  ) {
    return prisma.notice.update({
      where: { id, schoolId },
      data: {
        title: data.title,
        description: data.description,
        audience: data.audience,
        classId: data.classId !== undefined ? data.classId || null : undefined,
        sectionId:
          data.sectionId !== undefined ? data.sectionId || null : undefined,
        expiresAt:
          data.expiresAt !== undefined ? data.expiresAt || null : undefined,
        attachmentUrl:
          data.attachmentUrl !== undefined
            ? data.attachmentUrl || null
            : undefined,
      },
    });
  }

  async deleteNotice(schoolId: string, id: string) {
    return prisma.notice.delete({
      where: { id, schoolId },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.notice.findFirst({
      where: { id, schoolId },
      include: {
        class: true,
        section: true,
      },
    });
  }

  // Retrieve notices based on audience rules
  async findNoticesForUser(
    schoolId: string,
    options: {
      role: string;
      classId?: string;
      sectionId?: string;
    },
  ) {
    const now = new Date();

    const dateFilter = {
      OR: [{ expiresAt: null }, { expiresAt: { gte: now } }],
    };

    // Admins see all notices
    if (options.role === "SUPER_ADMIN" || options.role === "SCHOOL_ADMIN") {
      return prisma.notice.findMany({
        where: { schoolId },
        include: { class: true, section: true },
        orderBy: { publishedAt: "desc" },
      });
    }

    // Faculty see School and Faculty notices
    if (options.role === "FACULTY") {
      return prisma.notice.findMany({
        where: {
          schoolId,
          ...dateFilter,
          OR: [
            { audience: NoticeAudience.SCHOOL },
            { audience: NoticeAudience.FACULTY },
          ],
        },
        include: { class: true, section: true },
        orderBy: { publishedAt: "desc" },
      });
    }

    // Students see School, Students, or their matching class/section notices
    if (options.role === "STUDENT") {
      return prisma.notice.findMany({
        where: {
          schoolId,
          ...dateFilter,
          OR: [
            { audience: NoticeAudience.SCHOOL },
            { audience: NoticeAudience.STUDENTS },
            {
              AND: [
                { audience: NoticeAudience.CLASS },
                { classId: options.classId },
              ],
            },
            {
              AND: [
                { audience: NoticeAudience.SECTION },
                { sectionId: options.sectionId },
              ],
            },
          ],
        },
        include: { class: true, section: true },
        orderBy: { publishedAt: "desc" },
      });
    }

    // Fallback: only public/school announcements
    return prisma.notice.findMany({
      where: {
        schoolId,
        audience: NoticeAudience.SCHOOL,
        ...dateFilter,
      },
      orderBy: { publishedAt: "desc" },
    });
  }
}
