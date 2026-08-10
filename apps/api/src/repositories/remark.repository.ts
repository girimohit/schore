import { prisma, RemarkCategory } from "@schore/database";

export interface CreateRemarkInput {
  studentId: string;
  category: RemarkCategory;
  text: string;
}

export class RemarkRepository {
  async createRemark(schoolId: string, facultyId: string | null, data: CreateRemarkInput) {
    return prisma.studentRemark.create({
      data: {
        schoolId,
        studentId: data.studentId,
        facultyId,
        category: data.category,
        text: data.text,
      },
    });
  }

  async updateRemark(schoolId: string, id: string, data: { category?: RemarkCategory; text?: string }) {
    return prisma.studentRemark.update({
      where: { id, schoolId },
      data,
    });
  }

  async deleteRemark(schoolId: string, id: string) {
    return prisma.studentRemark.delete({
      where: { id, schoolId },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.studentRemark.findFirst({
      where: { id, schoolId },
      include: {
        faculty: true,
      },
    });
  }

  async findForStudent(schoolId: string, studentId: string) {
    return prisma.studentRemark.findMany({
      where: {
        schoolId,
        studentId,
      },
      include: {
        faculty: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });
  }
}
