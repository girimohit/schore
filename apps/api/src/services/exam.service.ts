import { z } from "zod";
import { ExamRepository } from "../repositories/exam.repository";
import { StudentRepository } from "../repositories/student.repository";
import { ExamStatus } from "@schore/database";
import { enforceEntitlement } from "../utils/entitlements";

const examStatusEnum = z.nativeEnum(ExamStatus);

export const createExamSchema = z.object({
  academicYearId: z.string().min(1, "Academic Year ID is required"),
  classId: z.string().min(1, "Class ID is required"),
  sectionId: z.string().optional(),
  name: z.string().min(1, "Exam name is required"),
  startDate: z.coerce.date().optional(),
  endDate: z.coerce.date().optional(),
});

export const updateExamSchema = z.object({
  name: z.string().optional(),
  startDate: z.coerce.date().optional(),
  endDate: z.coerce.date().optional(),
  status: examStatusEnum.optional(),
});

export const addSubjectToExamSchema = z.object({
  subjectId: z.string().min(1, "Subject ID is required"),
  examDate: z.coerce.date().optional(),
  maxMarks: z.number().positive("Max marks must be greater than 0"),
  passingMarks: z.number().positive("Passing marks must be greater than 0"),
});

export const recordResultSchema = z.object({
  studentId: z.string().min(1, "Student ID is required"),
  examSubjectId: z.string().min(1, "Exam subject assignment ID is required"),
  marksObtained: z.number().nonnegative("Marks obtained cannot be negative"),
  remarks: z.string().optional(),
});

export const batchRecordResultSchema = z.object({
  results: z
    .array(recordResultSchema)
    .min(1, "At least one result record is required"),
});

export class ExamService {
  private examRepository = new ExamRepository();
  private studentRepository = new StudentRepository();

  async createExam(schoolId: string, input: unknown) {
    await enforceEntitlement(schoolId, "exams");
    const data = createExamSchema.parse(input);
    return this.examRepository.createExam(schoolId, data);
  }

  async updateExam(schoolId: string, id: string, input: unknown) {
    await enforceEntitlement(schoolId, "exams");
    const data = updateExamSchema.parse(input);
    return this.examRepository.updateExam(schoolId, id, data);
  }

  async deleteExam(schoolId: string, id: string) {
    await enforceEntitlement(schoolId, "exams");
    return this.examRepository.deleteExam(schoolId, id);
  }

  async getExamDetails(schoolId: string, id: string) {
    await enforceEntitlement(schoolId, "exams");
    const exam = await this.examRepository.findById(schoolId, id);
    if (!exam) {
      throw new Error("Exam not found");
    }
    return exam;
  }

  async getExams(
    schoolId: string,
    options: {
      classId?: string;
      sectionId?: string;
      academicYearId?: string;
      status?: ExamStatus;
    },
  ) {
    await enforceEntitlement(schoolId, "exams");
    return this.examRepository.findExams(schoolId, options);
  }

  // ─────────────────────────────────────────────
  // EXAM SUBJECTS
  // ─────────────────────────────────────────────
  async addSubjectToExam(schoolId: string, examId: string, input: unknown) {
    await enforceEntitlement(schoolId, "exams");
    const data = addSubjectToExamSchema.parse(input);

    // Verify exam exists in school
    const exam = await this.examRepository.findById(schoolId, examId);
    if (!exam) {
      throw new Error("Exam not found");
    }

    if (data.passingMarks > data.maxMarks) {
      throw new Error("Passing marks cannot exceed max marks");
    }

    return this.examRepository.addSubjectToExam({
      examId,
      subjectId: data.subjectId,
      examDate: data.examDate,
      maxMarks: data.maxMarks,
      passingMarks: data.passingMarks,
    });
  }

  // ─────────────────────────────────────────────
  // RESULTS
  // ─────────────────────────────────────────────
  async recordResultsBatch(
    schoolId: string,
    examId: string,
    userId: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    await enforceEntitlement(schoolId, "exams");
    const data = batchRecordResultSchema.parse(input);

    const exam = await this.examRepository.findById(schoolId, examId);
    if (!exam) {
      throw new Error("Exam not found");
    }

    // Class Teacher Authorization:
    // If user is Faculty, check if they teach/assign to this class/section.
    // If they do, they are authorized to manage all subject results for this class!
    if (isFaculty) {
      const isClassTeacher = await this.examRepository.isFacultyAssignedToClass(
        userId,
        exam.classId,
        exam.sectionId || undefined,
      );

      if (!isClassTeacher) {
        throw new Error(
          "Access denied: You are not authorized to update marks for this class",
        );
      }
    }

    const savedResults = [];
    for (const record of data.results) {
      // Find subject configuration to compare marks and status
      const subject = exam.subjects.find((s) => s.id === record.examSubjectId);
      if (!subject) {
        throw new Error(
          `Subject with ID ${record.examSubjectId} not found in this exam`,
        );
      }

      // Check if marks are locked
      const submission = await prisma.marksSubmission.findFirst({
        where: {
          examId,
          subjectId: subject.subjectId,
          classId: exam.classId,
          sectionId: exam.sectionId || null,
        },
      });

      if (submission && (submission.status === "SUBMITTED_FOR_REVIEW" || submission.status === "FINALIZED")) {
        throw new Error(
          `Marks for subject ${subject.subject.name} are locked. (Status: ${submission.status})`
        );
      }

      const marks = record.marksObtained;
      if (Number(marks) > Number(subject.maxMarks)) {
        throw new Error(
          `Marks obtained (${marks}) cannot exceed maximum marks (${subject.maxMarks})`,
        );
      }

      const percentage = Math.round(
        (Number(marks) / Number(subject.maxMarks)) * 100,
      );
      let grade = "F";
      if (percentage >= 90) grade = "A+";
      else if (percentage >= 80) grade = "A";
      else if (percentage >= 70) grade = "B";
      else if (percentage >= 60) grade = "C";
      else if (percentage >= 50) grade = "D";

      const isPassed = Number(marks) >= Number(subject.passingMarks);
      const status: "PASS" | "FAIL" = isPassed ? "PASS" : "FAIL";

      const res = await this.examRepository.recordResult(schoolId, {
        examId,
        studentId: record.studentId,
        examSubjectId: record.examSubjectId,
        marks: Number(marks),
        grade,
        percentage,
        remarks: record.remarks,
        status,
      });

      savedResults.push(res);
    }

    return savedResults;
  }

  async getStudentResults(schoolId: string, studentId: string) {
    await enforceEntitlement(schoolId, "exams");
    const allResults = await this.examRepository.findStudentResults(schoolId, studentId);

    const finalizedSubmissions = await prisma.marksSubmission.findMany({
      where: {
        schoolId,
        status: "FINALIZED",
      },
    });

    const finalizedSet = new Set(
      finalizedSubmissions.map(
        (s) => `${s.examId}:${s.subjectId}:${s.classId}:${s.sectionId || ""}`
      )
    );

    const student = await prisma.student.findUnique({
      where: { id: studentId },
      include: {
        enrollments: {
          where: { status: "ACTIVE" },
        },
      },
    });

    const activeEnrollment = student?.enrollments?.[0];
    const studentClassId = activeEnrollment?.classId || "";
    const studentSectionId = activeEnrollment?.sectionId || "";

    return allResults.filter((res) => {
      const subjectId = res.examSubject.subjectId;
      const examId = res.examId;
      const key = `${examId}:${subjectId}:${studentClassId}:${studentSectionId}`;
      const classKey = `${examId}:${subjectId}:${studentClassId}:`;

      return finalizedSet.has(key) || finalizedSet.has(classKey);
    });
  }

  async getExamResults(
    schoolId: string,
    examId: string,
    userId: string,
    isFaculty: boolean,
  ) {
    await enforceEntitlement(schoolId, "exams");
    const exam = await this.examRepository.findById(schoolId, examId);
    if (!exam) {
      throw new Error("Exam not found");
    }

    if (isFaculty) {
      const isClassTeacher = await this.examRepository.isFacultyAssignedToClass(
        userId,
        exam.classId,
        exam.sectionId || undefined,
      );

      if (!isClassTeacher) {
        throw new Error(
          "Access denied: You can only view results for your assigned classes",
        );
      }
    }

    return this.examRepository.findExamResults(schoolId, examId);
  }
}
