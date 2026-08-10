import { prisma } from "@schore/database";

export class AcademicRepository {
  // ─────────────────────────────────────────────
  // ACADEMIC YEAR
  // ─────────────────────────────────────────────
  async createAcademicYear(schoolId: string, data: { name: string; startDate: Date; endDate: Date; isCurrent?: boolean }) {
    if (data.isCurrent) {
      // Unset previous current academic year
      await prisma.academicYear.updateMany({
        where: { schoolId, isCurrent: true },
        data: { isCurrent: false },
      });
    }

    return prisma.academicYear.create({
      data: {
        schoolId,
        name: data.name,
        startDate: data.startDate,
        endDate: data.endDate,
        isCurrent: data.isCurrent ?? false,
      },
    });
  }

  async findAcademicYears(schoolId: string) {
    return prisma.academicYear.findMany({
      where: { schoolId },
      orderBy: { startDate: "desc" },
    });
  }

  async setAcademicYearCurrent(schoolId: string, id: string) {
    await prisma.academicYear.updateMany({
      where: { schoolId, isCurrent: true },
      data: { isCurrent: false },
    });

    return prisma.academicYear.update({
      where: { id },
      data: { isCurrent: true },
    });
  }

  // ─────────────────────────────────────────────
  // CLASS
  // ─────────────────────────────────────────────
  async createClass(schoolId: string, data: { name: string; code?: string; sortOrder?: number }) {
    return prisma.class.create({
      data: {
        schoolId,
        name: data.name,
        code: data.code,
        sortOrder: data.sortOrder ?? 0,
      },
    });
  }

  async findClasses(schoolId: string) {
    return prisma.class.findMany({
      where: { schoolId },
      orderBy: { sortOrder: "asc" },
      include: {
        sections: true,
        subjects: {
          include: {
            subject: true,
          },
        },
      },
    });
  }

  async findClassById(schoolId: string, classId: string) {
    return prisma.class.findFirst({
      where: { id: classId, schoolId },
      include: {
        sections: true,
      },
    });
  }

  // ─────────────────────────────────────────────
  // SECTION
  // ─────────────────────────────────────────────
  async createSection(schoolId: string, classId: string, data: { name: string }) {
    return prisma.section.create({
      data: {
        schoolId,
        classId,
        name: data.name,
      },
    });
  }

  async findSections(schoolId: string, classId?: string) {
    return prisma.section.findMany({
      where: {
        schoolId,
        ...(classId ? { classId } : {}),
      },
      orderBy: { name: "asc" },
    });
  }

  async findSectionById(schoolId: string, sectionId: string) {
    return prisma.section.findFirst({
      where: { id: sectionId, schoolId },
    });
  }

  // ─────────────────────────────────────────────
  // SUBJECT
  // ─────────────────────────────────────────────
  async createSubject(schoolId: string, data: { name: string; code?: string }) {
    return prisma.subject.create({
      data: {
        schoolId,
        name: data.name,
        code: data.code,
      },
    });
  }

  async findSubjects(schoolId: string) {
    return prisma.subject.findMany({
      where: { schoolId },
      orderBy: { name: "asc" },
    });
  }

  // ─────────────────────────────────────────────
  // ASSIGNMENTS
  // ─────────────────────────────────────────────
  async assignSubjectToClass(classId: string, subjectId: string) {
    return prisma.classSubject.upsert({
      where: {
        classId_subjectId: {
          classId,
          subjectId,
        },
      },
      update: {},
      create: {
        classId,
        subjectId,
      },
    });
  }

  async assignFacultySubject(data: {
    facultyId: string;
    subjectId: string;
    classId: string;
    sectionId?: string;
  }) {
    const existing = await prisma.facultySubjectAssignment.findFirst({
      where: {
        facultyId: data.facultyId,
        subjectId: data.subjectId,
        classId: data.classId,
        sectionId: data.sectionId || null,
      },
    });

    if (existing) {
      return existing;
    }

    return prisma.facultySubjectAssignment.create({
      data: {
        facultyId: data.facultyId,
        subjectId: data.subjectId,
        classId: data.classId,
        sectionId: data.sectionId || null,
      },
    });
  }
}
