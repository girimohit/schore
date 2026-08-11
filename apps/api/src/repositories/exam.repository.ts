import { prisma, ExamStatus } from "@schore/database";

export interface CreateExamInput {
  academicYearId: string;
  classId: string;
  sectionId?: string;
  name: string;
  startDate?: Date;
  endDate?: Date;
}

export class ExamRepository {
  async createExam(schoolId: string, data: CreateExamInput) {
    return prisma.exam.create({
      data: {
        schoolId,
        academicYearId: data.academicYearId,
        classId: data.classId,
        sectionId: data.sectionId || null,
        name: data.name,
        startDate: data.startDate || null,
        endDate: data.endDate || null,
        status: ExamStatus.DRAFT,
      },
    });
  }

  async updateExam(
    schoolId: string,
    id: string,
    data: Partial<CreateExamInput> & { status?: ExamStatus },
  ) {
    return prisma.exam.update({
      where: { id, schoolId },
      data: {
        name: data.name,
        academicYearId: data.academicYearId,
        classId: data.classId,
        sectionId:
          data.sectionId !== undefined ? data.sectionId || null : undefined,
        startDate:
          data.startDate !== undefined ? data.startDate || null : undefined,
        endDate: data.endDate !== undefined ? data.endDate || null : undefined,
        status: data.status,
      },
    });
  }

  async deleteExam(schoolId: string, id: string) {
    return prisma.exam.delete({
      where: { id, schoolId },
    });
  }

  async findById(schoolId: string, id: string) {
    return prisma.exam.findFirst({
      where: { id, schoolId },
      include: {
        class: true,
        section: true,
        academicYear: true,
        subjects: {
          include: {
            subject: true,
          },
        },
      },
    });
  }

  async findExams(
    schoolId: string,
    options: {
      classId?: string;
      sectionId?: string;
      academicYearId?: string;
      status?: ExamStatus;
    },
  ) {
    return prisma.exam.findMany({
      where: {
        schoolId,
        ...(options.classId ? { classId: options.classId } : {}),
        ...(options.sectionId ? { sectionId: options.sectionId } : {}),
        ...(options.academicYearId
          ? { academicYearId: options.academicYearId }
          : {}),
        ...(options.status ? { status: options.status } : {}),
      },
      include: {
        class: true,
        section: true,
        academicYear: true,
      },
      orderBy: { createdAt: "desc" },
    });
  }

  // ─────────────────────────────────────────────
  // EXAM SUBJECTS
  // ─────────────────────────────────────────────
  async addSubjectToExam(data: {
    examId: string;
    subjectId: string;
    examDate?: Date;
    maxMarks: number;
    passingMarks: number;
  }) {
    return prisma.examSubject.upsert({
      where: {
        examId_subjectId: {
          examId: data.examId,
          subjectId: data.subjectId,
        },
      },
      update: {
        examDate: data.examDate || null,
        maxMarks: data.maxMarks,
        passingMarks: data.passingMarks,
      },
      create: {
        examId: data.examId,
        subjectId: data.subjectId,
        examDate: data.examDate || null,
        maxMarks: data.maxMarks,
        passingMarks: data.passingMarks,
      },
    });
  }

  // ─────────────────────────────────────────────
  // RESULTS
  // ─────────────────────────────────────────────
  async recordResult(
    schoolId: string,
    data: {
      examId: string;
      studentId: string;
      examSubjectId: string;
      marks: number;
      grade?: string;
      percentage?: number;
      remarks?: string;
      status: "PASS" | "FAIL" | "ABSENT";
    },
  ) {
    return prisma.result.upsert({
      where: {
        examSubjectId_studentId: {
          examSubjectId: data.examSubjectId,
          studentId: data.studentId,
        },
      },
      update: {
        marks: data.marks,
        grade: data.grade || null,
        percentage: data.percentage || null,
        remarks: data.remarks || null,
        status: data.status,
      },
      create: {
        schoolId,
        examId: data.examId,
        studentId: data.studentId,
        examSubjectId: data.examSubjectId,
        marks: data.marks,
        grade: data.grade || null,
        percentage: data.percentage || null,
        remarks: data.remarks || null,
        status: data.status,
      },
    });
  }

  async findStudentResults(schoolId: string, studentId: string) {
    return prisma.result.findMany({
      where: {
        schoolId,
        studentId,
        exam: {
          status: ExamStatus.PUBLISHED,
        },
      },
      include: {
        exam: true,
        examSubject: {
          include: {
            subject: true,
          },
        },
      },
      orderBy: {
        exam: {
          startDate: "desc",
        },
      },
    });
  }

  async findExamResults(schoolId: string, examId: string) {
    return prisma.result.findMany({
      where: {
        schoolId,
        examId,
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
        examSubject: {
          include: {
            subject: true,
          },
        },
      },
    });
  }

  // Authorization: check if faculty is assigned to the class/section
  async isFacultyAssignedToClass(
    facultyId: string,
    classId: string,
    sectionId?: string,
  ): Promise<boolean> {
    const assignment = await prisma.facultySubjectAssignment.findFirst({
      where: {
        facultyId,
        classId,
        ...(sectionId
          ? {
              OR: [{ sectionId: null }, { sectionId }],
            }
          : {}),
      },
    });
    return !!assignment;
  }
}
