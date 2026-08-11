import { z } from "zod";
import { AcademicRepository } from "../repositories/academic.repository";

// ─────────────────────────────────────────────
// VALIDATION SCHEMAS
// ─────────────────────────────────────────────
export const createAcademicYearSchema = z.object({
  name: z.string().min(1, "Name is required"),
  startDate: z.coerce.date(),
  endDate: z.coerce.date(),
  isCurrent: z.boolean().optional(),
});

export const createClassSchema = z.object({
  name: z.string().min(1, "Class name is required"),
  code: z.string().optional(),
  sortOrder: z.number().int().optional(),
});

export const createSectionSchema = z.object({
  classId: z.string().min(1, "Class ID is required"),
  name: z.string().min(1, "Section name is required"),
});

export const createSubjectSchema = z.object({
  name: z.string().min(1, "Subject name is required"),
  code: z.string().optional(),
});

export const assignSubjectToClassSchema = z.object({
  classId: z.string().min(1, "Class ID is required"),
  subjectId: z.string().min(1, "Subject ID is required"),
});

export const assignFacultySubjectSchema = z.object({
  facultyId: z.string().min(1, "Faculty ID is required"),
  subjectId: z.string().min(1, "Subject ID is required"),
  classId: z.string().min(1, "Class ID is required"),
  sectionId: z.string().optional(),
});

export class AcademicService {
  private academicRepository = new AcademicRepository();

  // ─────────────────────────────────────────────
  // ACADEMIC YEAR
  // ─────────────────────────────────────────────
  async createAcademicYear(schoolId: string, input: unknown) {
    const data = createAcademicYearSchema.parse(input);
    if (data.startDate >= data.endDate) {
      throw new Error("Start date must be before end date");
    }
    return this.academicRepository.createAcademicYear(schoolId, data);
  }

  async getAcademicYears(schoolId: string) {
    return this.academicRepository.findAcademicYears(schoolId);
  }

  async setAcademicYearCurrent(schoolId: string, id: string) {
    return this.academicRepository.setAcademicYearCurrent(schoolId, id);
  }

  // ─────────────────────────────────────────────
  // CLASS
  // ─────────────────────────────────────────────
  async createClass(schoolId: string, input: unknown) {
    const data = createClassSchema.parse(input);
    return this.academicRepository.createClass(schoolId, data);
  }

  async getClasses(schoolId: string) {
    return this.academicRepository.findClasses(schoolId);
  }

  // ─────────────────────────────────────────────
  // SECTION
  // ─────────────────────────────────────────────
  async createSection(schoolId: string, input: unknown) {
    const data = createSectionSchema.parse(input);

    // Verify class belongs to the school
    const classRecord = await this.academicRepository.findClassById(
      schoolId,
      data.classId,
    );
    if (!classRecord) {
      throw new Error("Class not found in this school");
    }

    return this.academicRepository.createSection(schoolId, data.classId, {
      name: data.name,
    });
  }

  async getSections(schoolId: string, classId?: string) {
    if (classId) {
      const classRecord = await this.academicRepository.findClassById(
        schoolId,
        classId,
      );
      if (!classRecord) {
        throw new Error("Class not found in this school");
      }
    }
    return this.academicRepository.findSections(schoolId, classId);
  }

  // ─────────────────────────────────────────────
  // SUBJECT
  // ─────────────────────────────────────────────
  async createSubject(schoolId: string, input: unknown) {
    const data = createSubjectSchema.parse(input);
    return this.academicRepository.createSubject(schoolId, data);
  }

  async getSubjects(schoolId: string) {
    return this.academicRepository.findSubjects(schoolId);
  }

  // ─────────────────────────────────────────────
  // ASSIGNMENTS
  // ─────────────────────────────────────────────
  async assignSubjectToClass(schoolId: string, input: unknown) {
    const data = assignSubjectToClassSchema.parse(input);

    // Verify class belongs to school
    const classRecord = await this.academicRepository.findClassById(
      schoolId,
      data.classId,
    );
    if (!classRecord) {
      throw new Error("Class not found");
    }

    return this.academicRepository.assignSubjectToClass(
      data.classId,
      data.subjectId,
    );
  }

  async assignFacultySubject(schoolId: string, input: unknown) {
    const data = assignFacultySubjectSchema.parse(input);

    // Verify class belongs to school
    const classRecord = await this.academicRepository.findClassById(
      schoolId,
      data.classId,
    );
    if (!classRecord) {
      throw new Error("Class not found");
    }

    // Verify section if provided
    if (data.sectionId) {
      const sectionRecord = await this.academicRepository.findSectionById(
        schoolId,
        data.sectionId,
      );
      if (!sectionRecord || sectionRecord.classId !== data.classId) {
        throw new Error(
          "Section not found or does not belong to the selected class",
        );
      }
    }

    return this.academicRepository.assignFacultySubject(data);
  }
}
