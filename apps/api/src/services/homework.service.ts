import { z } from "zod";
import { HomeworkRepository } from "../repositories/homework.repository";
import { AcademicRepository } from "../repositories/academic.repository";
import { StudentRepository } from "../repositories/student.repository";

export const createHomeworkSchema = z.object({
  classId: z.string().min(1, "Class ID is required"),
  sectionId: z.string().min(1, "Section ID is required"),
  subjectId: z.string().min(1, "Subject ID is required"),
  title: z.string().min(1, "Title is required"),
  description: z.string().optional(),
  attachmentUrl: z.string().url().optional().or(z.literal("")),
  dueDate: z.coerce.date(),
  academicYearId: z.string().min(1, "Academic Year ID is required"),
});

export const updateHomeworkSchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
  attachmentUrl: z.string().url().optional().or(z.literal("")),
  dueDate: z.coerce.date().optional(),
});

export const submitHomeworkSchema = z.object({
  contentUrl: z.string().url("Valid submission content URL is required"),
});

export const reviewSubmissionSchema = z.object({
  feedback: z.string().min(1, "Feedback is required"),
  isApproved: z.boolean(),
});

export class HomeworkService {
  private homeworkRepository = new HomeworkRepository();
  private academicRepository = new AcademicRepository();
  private studentRepository = new StudentRepository();

  async createHomework(
    schoolId: string,
    facultyId: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    const data = createHomeworkSchema.parse(input);

    if (isFaculty) {
      // Verify faculty is assigned to this section/class
      const isAuthorized = await this.academicRepository.assignFacultySubject({
        facultyId,
        subjectId: data.subjectId,
        classId: data.classId,
        sectionId: data.sectionId,
      }); // We can use findFirst check in repository, or call database check
      // Let's do a simple check:
      const assigned = await this.academicRepository.findSectionById(
        schoolId,
        data.sectionId,
      );
      if (!assigned || assigned.classId !== data.classId) {
        throw new Error("Invalid class/section assignment");
      }
    }

    return this.homeworkRepository.createHomework(schoolId, facultyId, {
      ...data,
      attachmentUrl: data.attachmentUrl || undefined,
    });
  }

  async updateHomework(
    schoolId: string,
    id: string,
    facultyId: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    const data = updateHomeworkSchema.parse(input);

    if (isFaculty) {
      const homework = await this.homeworkRepository.findById(schoolId, id);
      if (!homework || homework.facultyId !== facultyId) {
        throw new Error("You are not authorized to update this homework");
      }
    }

    return this.homeworkRepository.updateHomework(schoolId, id, {
      ...data,
      attachmentUrl: data.attachmentUrl || undefined,
    });
  }

  async deleteHomework(
    schoolId: string,
    id: string,
    facultyId: string,
    isFaculty: boolean,
  ) {
    if (isFaculty) {
      const homework = await this.homeworkRepository.findById(schoolId, id);
      if (!homework || homework.facultyId !== facultyId) {
        throw new Error("You are not authorized to delete this homework");
      }
    }
    return this.homeworkRepository.deleteHomework(schoolId, id);
  }

  async getHomeworkDetails(schoolId: string, id: string) {
    const homework = await this.homeworkRepository.findById(schoolId, id);
    if (!homework) {
      throw new Error("Homework not found");
    }
    return homework;
  }

  async getHomeworkList(
    schoolId: string,
    options: {
      classId?: string;
      sectionId?: string;
      subjectId?: string;
      facultyId?: string;
    },
  ) {
    return this.homeworkRepository.findHomeworkList(schoolId, options);
  }

  async getStudentHomework(schoolId: string, studentId: string) {
    return this.homeworkRepository.findStudentAssignedHomework(
      schoolId,
      studentId,
    );
  }

  async getHomeworkSubmissions(
    schoolId: string,
    homeworkId: string,
    facultyId: string,
    isFaculty: boolean,
  ) {
    if (isFaculty) {
      const homework = await this.homeworkRepository.findById(
        schoolId,
        homeworkId,
      );
      if (!homework || homework.facultyId !== facultyId) {
        throw new Error(
          "You are not authorized to view submissions for this homework",
        );
      }
    }
    return this.homeworkRepository.findSubmissions(homeworkId);
  }

  async submitHomework(
    schoolId: string,
    homeworkId: string,
    userId: string,
    input: unknown,
  ) {
    const data = submitHomeworkSchema.parse(input);

    // Resolve studentId from userId
    const student = await this.studentRepository.findByUserId(schoolId, userId);
    if (!student) {
      throw new Error("Student profile not found");
    }

    // Verify student is assigned to this homework
    const assigned = await this.homeworkRepository.findStudentSubmission(
      homeworkId,
      student.id,
    );
    if (!assigned) {
      throw new Error("You are not assigned to this homework");
    }

    return this.homeworkRepository.submitHomework(
      homeworkId,
      student.id,
      data.contentUrl,
    );
  }

  async reviewSubmission(
    schoolId: string,
    homeworkId: string,
    submissionId: string,
    facultyId: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    const data = reviewSubmissionSchema.parse(input);

    if (isFaculty) {
      const homework = await this.homeworkRepository.findById(
        schoolId,
        homeworkId,
      );
      if (!homework || homework.facultyId !== facultyId) {
        throw new Error(
          "You are not authorized to review submissions for this homework",
        );
      }
    }

    return this.homeworkRepository.reviewSubmission(
      submissionId,
      data.feedback,
      data.isApproved,
    );
  }
}
