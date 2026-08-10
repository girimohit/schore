import { prisma } from "@schore/database";

export interface CreateTimetableInput {
  classId: string;
  sectionId: string;
  subjectId: string;
  facultyId?: string;
  dayOfWeek: number;
  period: number;
  startTime: string;
  endTime: string;
  room?: string;
}

export class TimetableRepository {
  async createEntry(schoolId: string, data: CreateTimetableInput) {
    return prisma.timetable.create({
      data: {
        schoolId,
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        facultyId: data.facultyId || null,
        dayOfWeek: data.dayOfWeek,
        period: data.period,
        startTime: data.startTime,
        endTime: data.endTime,
        room: data.room || null,
      },
    });
  }

  async updateEntry(schoolId: string, id: string, data: Partial<CreateTimetableInput>) {
    return prisma.timetable.update({
      where: { id, schoolId },
      data: {
        classId: data.classId,
        sectionId: data.sectionId,
        subjectId: data.subjectId,
        facultyId: data.facultyId !== undefined ? (data.facultyId || null) : undefined,
        dayOfWeek: data.dayOfWeek,
        period: data.period,
        startTime: data.startTime,
        endTime: data.endTime,
        room: data.room !== undefined ? (data.room || null) : undefined,
      },
    });
  }

  async deleteEntry(schoolId: string, id: string) {
    return prisma.timetable.delete({
      where: { id, schoolId },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.timetable.findFirst({
      where: { id, schoolId },
      include: {
        class: true,
        section: true,
        subject: true,
        faculty: true,
      },
    });
  }

  async findForClass(schoolId: string, classId: string, sectionId: string) {
    return prisma.timetable.findMany({
      where: {
        schoolId,
        classId,
        sectionId,
      },
      include: {
        subject: true,
        faculty: true,
      },
      orderBy: [
        { dayOfWeek: "asc" },
        { period: "asc" },
      ],
    });
  }

  async findForFaculty(schoolId: string, facultyId: string) {
    return prisma.timetable.findMany({
      where: {
        schoolId,
        facultyId,
      },
      include: {
        class: true,
        section: true,
        subject: true,
      },
      orderBy: [
        { dayOfWeek: "asc" },
        { period: "asc" },
      ],
    });
  }

  // Conflict verification
  async checkClassConflict(
    schoolId: string,
    classId: string,
    sectionId: string,
    dayOfWeek: number,
    period: number,
    excludeId?: string
  ) {
    return prisma.timetable.findFirst({
      where: {
        schoolId,
        classId,
        sectionId,
        dayOfWeek,
        period,
        ...(excludeId ? { NOT: { id: excludeId } } : {}),
      },
    });
  }

  async checkFacultyConflict(
    schoolId: string,
    facultyId: string,
    dayOfWeek: number,
    period: number,
    excludeId?: string
  ) {
    return prisma.timetable.findFirst({
      where: {
        schoolId,
        facultyId,
        dayOfWeek,
        period,
        ...(excludeId ? { NOT: { id: excludeId } } : {}),
      },
    });
  }
}
