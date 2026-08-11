import { prisma, AttendanceStatus } from "@schore/database";

export class AttendanceRepository {
  async markAttendance(
    schoolId: string,
    data: {
      studentId: string;
      sectionId: string;
      date: Date;
      status: AttendanceStatus;
      markedById: string;
      note?: string;
    },
  ) {
    // Standardize date to ignore time components (midnight UTC)
    const attendanceDate = new Date(data.date);
    attendanceDate.setUTCHours(0, 0, 0, 0);

    return prisma.attendance.upsert({
      where: {
        studentId_date: {
          studentId: data.studentId,
          date: attendanceDate,
        },
      },
      update: {
        status: data.status,
        markedById: data.markedById,
        note: data.note || null,
      },
      create: {
        schoolId,
        studentId: data.studentId,
        sectionId: data.sectionId,
        date: attendanceDate,
        status: data.status,
        markedById: data.markedById,
        note: data.note || null,
      },
    });
  }

  async findDailyAttendanceBySection(
    schoolId: string,
    sectionId: string,
    date: Date,
  ) {
    const attendanceDate = new Date(date);
    attendanceDate.setUTCHours(0, 0, 0, 0);

    return prisma.attendance.findMany({
      where: {
        schoolId,
        sectionId,
        date: attendanceDate,
      },
      include: {
        student: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            admissionNumber: true,
          },
        },
      },
      orderBy: {
        student: {
          firstName: "asc",
        },
      },
    });
  }

  async findStudentAttendance(
    schoolId: string,
    studentId: string,
    startDate?: Date,
    endDate?: Date,
  ) {
    return prisma.attendance.findMany({
      where: {
        schoolId,
        studentId,
        ...(startDate || endDate
          ? {
              date: {
                ...(startDate ? { gte: startDate } : {}),
                ...(endDate ? { lte: endDate } : {}),
              },
            }
          : {}),
      },
      orderBy: { date: "desc" },
    });
  }

  async getStudentStats(schoolId: string, studentId: string) {
    const records = await prisma.attendance.findMany({
      where: { schoolId, studentId },
      select: { status: true },
    });

    const total = records.length;
    if (total === 0) {
      return {
        total: 0,
        present: 0,
        absent: 0,
        late: 0,
        excused: 0,
        percentage: 100, // Default to 100% if no classes marked
      };
    }

    let present = 0;
    let absent = 0;
    let late = 0;
    let excused = 0;

    for (const r of records) {
      if (r.status === AttendanceStatus.PRESENT) present++;
      else if (r.status === AttendanceStatus.ABSENT) absent++;
      else if (r.status === AttendanceStatus.LATE) late++;
      else if (r.status === AttendanceStatus.EXCUSED) excused++;
    }

    // Standard school calculation: present + late (as present/half) or just count present + late
    const attended = present + late;
    const percentage = Math.round((attended / total) * 100);

    return {
      total,
      present,
      absent,
      late,
      excused,
      percentage,
    };
  }

  // Verify if a teacher is assigned to a section
  async isFacultyAssignedToSection(
    facultyId: string,
    sectionId: string,
  ): Promise<boolean> {
    const section = await prisma.section.findUnique({
      where: { id: sectionId },
      select: { classId: true },
    });

    if (!section) return false;

    const assignment = await prisma.facultySubjectAssignment.findFirst({
      where: {
        facultyId,
        classId: section.classId,
        OR: [{ sectionId: null }, { sectionId }],
      },
    });

    return !!assignment;
  }
}
