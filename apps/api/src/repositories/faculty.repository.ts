import { prisma, UserStatus } from "@schore/database";

export interface FindFacultyOptions {
  search?: string;
  status?: UserStatus;
  take?: number;
  skip?: number;
}

export class FacultyRepository {
  async createFaculty(
    schoolId: string,
    data: {
      userId: string;
      employeeId: string;
      firstName: string;
      middleName?: string;
      lastName?: string;
      phone?: string;
      email?: string;
      photoUrl?: string;
      joiningDate?: Date;
    },
    tx?: any,
  ) {
    const client = tx || prisma;
    return client.faculty.create({
      data: {
        schoolId,
        userId: data.userId,
        employeeId: data.employeeId,
        firstName: data.firstName,
        middleName: data.middleName || null,
        lastName: data.lastName || null,
        phone: data.phone || null,
        email: data.email || null,
        photoUrl: data.photoUrl || null,
        joiningDate: data.joiningDate || null,
        status: UserStatus.ACTIVE,
      },
    });
  }

  async updateFaculty(
    schoolId: string,
    id: string,
    data: {
      firstName?: string;
      middleName?: string;
      lastName?: string;
      phone?: string;
      email?: string;
      photoUrl?: string;
      joiningDate?: Date;
      status?: UserStatus;
    },
  ) {
    return prisma.faculty.update({
      where: { id, schoolId },
      data: {
        ...data,
      },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.faculty.findFirst({
      where: { id, schoolId },
      include: {
        assignments: {
          include: {
            class: true,
            subject: true,
          },
        },
        user: true,
      },
    });
  }

  async findByUserId(schoolId: string, userId: string) {
    return prisma.faculty.findFirst({
      where: { userId, schoolId },
      include: {
        assignments: {
          include: {
            class: true,
            subject: true,
          },
        },
      },
    });
  }

  async findFaculty(schoolId: string, options: FindFacultyOptions) {
    const { search, status, take = 20, skip = 0 } = options;

    const where: any = {
      schoolId,
      ...(status ? { status } : {}),
      ...(search
        ? {
            OR: [
              { firstName: { contains: search, mode: "insensitive" } },
              { lastName: { contains: search, mode: "insensitive" } },
              { employeeId: { contains: search, mode: "insensitive" } },
            ],
          }
        : {}),
    };

    const [faculty, total] = await Promise.all([
      prisma.faculty.findMany({
        where,
        include: {
          assignments: {
            include: {
              class: true,
              subject: true,
            },
          },
        },
        orderBy: { firstName: "asc" },
        take,
        skip,
      }),
      prisma.faculty.count({ where }),
    ]);

    return { faculty, total };
  }
}
