import { prisma, StudentStatus, Gender } from "@schore/database";

export interface FindStudentsOptions {
  classId?: string;
  sectionId?: string;
  status?: StudentStatus;
  search?: string;
  take?: number;
  skip?: number;
}

export class StudentRepository {
  async createStudent(
    schoolId: string,
    data: {
      admissionNumber: string;
      firstName: string;
      middleName?: string;
      lastName?: string;
      dateOfBirth?: Date;
      gender?: Gender;
      photoUrl?: string;
      bloodGroup?: string;
      email?: string;
      phone?: string;
      address?: string;
      admissionDate?: Date;
      userId?: string;
      // Enrollment details
      academicYearId: string;
      classId: string;
      sectionId: string;
      rollNumber?: number;
    },
  ) {
    return prisma.$transaction(async (tx) => {
      // 1. Create Student
      const student = await tx.student.create({
        data: {
          schoolId,
          userId: data.userId || null,
          admissionNumber: data.admissionNumber,
          firstName: data.firstName,
          middleName: data.middleName || null,
          lastName: data.lastName || null,
          dateOfBirth: data.dateOfBirth || null,
          gender: data.gender || null,
          photoUrl: data.photoUrl || null,
          bloodGroup: data.bloodGroup || null,
          email: data.email || null,
          phone: data.phone || null,
          address: data.address || null,
          admissionDate: data.admissionDate || null,
          status: StudentStatus.ACTIVE,
        },
      });

      // 2. Create Enrollment for current academic year
      await tx.studentEnrollment.create({
        data: {
          schoolId,
          studentId: student.id,
          academicYearId: data.academicYearId,
          classId: data.classId,
          sectionId: data.sectionId,
          rollNumber: data.rollNumber || null,
        },
      });

      return student;
    });
  }

  async updateStudent(
    schoolId: string,
    studentId: string,
    data: {
      firstName?: string;
      middleName?: string;
      lastName?: string;
      dateOfBirth?: Date;
      gender?: Gender;
      photoUrl?: string;
      bloodGroup?: string;
      email?: string;
      phone?: string;
      address?: string;
      admissionDate?: Date;
      status?: StudentStatus;
    },
  ) {
    return prisma.student.update({
      where: { id: studentId, schoolId },
      data: {
        ...data,
      },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.student.findFirst({
      where: { id, schoolId },
      include: {
        enrollments: {
          include: {
            class: true,
            section: true,
            academicYear: true,
          },
        },
        user: true,
      },
    });
  }

  async findByUserId(schoolId: string, userId: string) {
    return prisma.student.findFirst({
      where: { userId, schoolId },
      include: {
        enrollments: {
          include: {
            class: true,
            section: true,
            academicYear: true,
          },
        },
      },
    });
  }

  async findStudents(schoolId: string, options: FindStudentsOptions) {
    const { classId, sectionId, status, search, take = 20, skip = 0 } = options;

    const where: any = {
      schoolId,
      ...(status ? { status } : {}),
      ...(classId || sectionId
        ? {
            enrollments: {
              some: {
                ...(classId ? { classId } : {}),
                ...(sectionId ? { sectionId } : {}),
                status: "ACTIVE",
              },
            },
          }
        : {}),
      ...(search
        ? {
            OR: [
              { firstName: { contains: search, mode: "insensitive" } },
              { lastName: { contains: search, mode: "insensitive" } },
              { admissionNumber: { contains: search, mode: "insensitive" } },
            ],
          }
        : {}),
    };

    const [students, total] = await Promise.all([
      prisma.student.findMany({
        where,
        include: {
          enrollments: {
            where: { status: "ACTIVE" },
            include: {
              class: true,
              section: true,
            },
          },
        },
        orderBy: { firstName: "asc" },
        take,
        skip,
      }),
      prisma.student.count({ where }),
    ]);

    return { students, total };
  }

  // Fetch only students enrolled in classes/sections assigned to the faculty member
  async findStudentsForFaculty(
    schoolId: string,
    facultyId: string,
    options: FindStudentsOptions,
  ) {
    const { classId, sectionId, status, search, take = 20, skip = 0 } = options;

    // Get classes & sections assigned to faculty
    const assignments = await prisma.facultySubjectAssignment.findMany({
      where: { facultyId },
      select: { classId: true, sectionId: true },
    });

    if (assignments.length === 0) {
      return { students: [], total: 0 };
    }

    const assignedClassIds = assignments.map((a) => a.classId);
    const assignedSectionIds = assignments
      .map((a) => a.sectionId)
      .filter((sid): sid is string => sid !== null);

    const where: any = {
      schoolId,
      ...(status ? { status } : {}),
      enrollments: {
        some: {
          classId: { in: classId ? [classId] : assignedClassIds },
          ...(sectionId
            ? { sectionId }
            : assignedSectionIds.length > 0
              ? { sectionId: { in: assignedSectionIds } }
              : {}),
          status: "ACTIVE",
        },
      },
      ...(search
        ? {
            OR: [
              { firstName: { contains: search, mode: "insensitive" } },
              { lastName: { contains: search, mode: "insensitive" } },
              { admissionNumber: { contains: search, mode: "insensitive" } },
            ],
          }
        : {}),
    };

    const [students, total] = await Promise.all([
      prisma.student.findMany({
        where,
        include: {
          enrollments: {
            where: { status: "ACTIVE" },
            include: {
              class: true,
              section: true,
            },
          },
        },
        orderBy: { firstName: "asc" },
        take,
        skip,
      }),
      prisma.student.count({ where }),
    ]);

    return { students, total };
  }

  async checkFacultyAccess(
    schoolId: string,
    studentId: string,
    facultyId: string,
  ): Promise<boolean> {
    const student = await this.findById(schoolId, studentId);
    if (!student) return false;

    const activeEnrollment = student.enrollments.find(
      (e) => e.status === "ACTIVE",
    );
    if (!activeEnrollment) return false;

    const assignment = await prisma.facultySubjectAssignment.findFirst({
      where: {
        facultyId,
        classId: activeEnrollment.classId,
        OR: [{ sectionId: null }, { sectionId: activeEnrollment.sectionId }],
      },
    });

    return !!assignment;
  }
}
