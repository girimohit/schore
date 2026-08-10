import { prisma, SubmissionStatus } from "@schore/database";

export class HomeworkRepository {
  async createHomework(schoolId: string, facultyId: string, data: {
    classId: string;
    sectionId: string;
    subjectId: string;
    title: string;
    description?: string;
    attachmentUrl?: string;
    dueDate: Date;
    academicYearId: string; // needed to find enrolled students
  }) {
    return prisma.$transaction(async (tx) => {
      // 1. Create Homework
      const homework = await tx.homework.create({
        data: {
          schoolId,
          facultyId,
          classId: data.classId,
          sectionId: data.sectionId,
          subjectId: data.subjectId,
          title: data.title,
          description: data.description || null,
          attachmentUrl: data.attachmentUrl || null,
          dueDate: data.dueDate,
        },
      });

      // 2. Query all active student enrollments for this class & section
      const enrollments = await tx.studentEnrollment.findMany({
        where: {
          schoolId,
          classId: data.classId,
          sectionId: data.sectionId,
          academicYearId: data.academicYearId,
          status: "ACTIVE",
        },
        select: { studentId: true },
      });

      // 3. Auto-assign submission records to each student
      if (enrollments.length > 0) {
        await tx.homeworkSubmission.createMany({
          data: enrollments.map((env) => ({
            homeworkId: homework.id,
            studentId: env.studentId,
            status: SubmissionStatus.ASSIGNED,
          })),
        });
      }

      return homework;
    });
  }

  async updateHomework(schoolId: string, id: string, data: {
    title?: string;
    description?: string;
    attachmentUrl?: string;
    dueDate?: Date;
  }) {
    return prisma.homework.update({
      where: { id, schoolId },
      data,
    });
  }

  async deleteHomework(schoolId: string, id: string) {
    return prisma.homework.delete({
      where: { id, schoolId },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.homework.findFirst({
      where: { id, schoolId },
      include: {
        class: true,
        section: true,
        subject: true,
        faculty: true,
      },
    });
  }

  async findHomeworkList(schoolId: string, options: {
    classId?: string;
    sectionId?: string;
    subjectId?: string;
    facultyId?: string;
  }) {
    return prisma.homework.findMany({
      where: {
        schoolId,
        ...(options.classId ? { classId: options.classId } : {}),
        ...(options.sectionId ? { sectionId: options.sectionId } : {}),
        ...(options.subjectId ? { subjectId: options.subjectId } : {}),
        ...(options.facultyId ? { facultyId: options.facultyId } : {}),
      },
      include: {
        class: true,
        section: true,
        subject: true,
        faculty: true,
      },
      orderBy: { dueDate: "asc" },
    });
  }

  async findStudentAssignedHomework(schoolId: string, studentId: string) {
    return prisma.homeworkSubmission.findMany({
      where: {
        studentId,
        homework: { schoolId },
      },
      include: {
        homework: {
          include: {
            class: true,
            section: true,
            subject: true,
            faculty: true,
          },
        },
      },
      orderBy: {
        homework: {
          dueDate: "asc",
        },
      },
    });
  }

  async findSubmissions(homeworkId: string) {
    return prisma.homeworkSubmission.findMany({
      where: { homeworkId },
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
      orderBy: { submittedAt: "desc" },
    });
  }

  async findStudentSubmission(homeworkId: string, studentId: string) {
    return prisma.homeworkSubmission.findUnique({
      where: {
        homeworkId_studentId: {
          homeworkId,
          studentId,
        },
      },
    });
  }

  async submitHomework(homeworkId: string, studentId: string, contentUrl: string) {
    const homework = await prisma.homework.findUnique({
      where: { id: homeworkId },
      select: { dueDate: true },
    });

    if (!homework) {
      throw new Error("Homework not found");
    }

    const isLate = new Date() > homework.dueDate;
    const status = isLate ? SubmissionStatus.LATE : SubmissionStatus.SUBMITTED;

    return prisma.homeworkSubmission.update({
      where: {
        homeworkId_studentId: {
          homeworkId,
          studentId,
        },
      },
      data: {
        contentUrl,
        submittedAt: new Date(),
        status,
      },
    });
  }

  async reviewSubmission(submissionId: string, feedback: string, isApproved: boolean) {
    const status = isApproved ? SubmissionStatus.REVIEWED : SubmissionStatus.ASSIGNED;

    return prisma.homeworkSubmission.update({
      where: { id: submissionId },
      data: {
        feedback,
        reviewedAt: new Date(),
        status,
      },
    });
  }
}
