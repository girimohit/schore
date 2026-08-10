import { z } from "zod";
import { RemarkRepository } from "../repositories/remark.repository";
import { FacultyRepository } from "../repositories/faculty.repository";
import { RemarkCategory } from "@schore/database";

const categoryEnum = z.nativeEnum(RemarkCategory);

export const createRemarkSchema = z.object({
  studentId: z.string().min(1, "Student ID is required"),
  category: categoryEnum,
  text: z.string().min(1, "Remark content is required"),
});

export const updateRemarkSchema = z.object({
  category: categoryEnum.optional(),
  text: z.string().optional(),
});

export class RemarkService {
  private remarkRepository = new RemarkRepository();
  private facultyRepository = new FacultyRepository();

  async createRemark(schoolId: string, userId: string, role: string, input: unknown) {
    const data = createRemarkSchema.parse(input);

    let facultyId: string | null = null;
    if (role === "FACULTY") {
      const faculty = await this.facultyRepository.findByUserId(schoolId, userId);
      if (!faculty) {
        throw new Error("Faculty profile not found");
      }
      facultyId = faculty.id;
    }

    return this.remarkRepository.createRemark(schoolId, facultyId, data);
  }

  async updateRemark(schoolId: string, id: string, userId: string, role: string, input: unknown) {
    const data = updateRemarkSchema.parse(input);

    const existing = await this.remarkRepository.findById(schoolId, id);
    if (!existing) {
      throw new Error("Remark not found");
    }

    // Auth check: Only administrators or the authoring faculty member can edit
    if (role === "FACULTY") {
      const faculty = await this.facultyRepository.findByUserId(schoolId, userId);
      if (!faculty || existing.facultyId !== faculty.id) {
        throw new Error("You are not authorized to edit this remark");
      }
    } else if (role !== "SUPER_ADMIN" && role !== "SCHOOL_ADMIN") {
      throw new Error("Access denied");
    }

    return this.remarkRepository.updateRemark(schoolId, id, data);
  }

  async deleteRemark(schoolId: string, id: string, userId: string, role: string) {
    const existing = await this.remarkRepository.findById(schoolId, id);
    if (!existing) {
      throw new Error("Remark not found");
    }

    // Auth check: Only administrators or the authoring faculty member can delete
    if (role === "FACULTY") {
      const faculty = await this.facultyRepository.findByUserId(schoolId, userId);
      if (!faculty || existing.facultyId !== faculty.id) {
        throw new Error("You are not authorized to delete this remark");
      }
    } else if (role !== "SUPER_ADMIN" && role !== "SCHOOL_ADMIN") {
      throw new Error("Access denied");
    }

    return this.remarkRepository.deleteRemark(schoolId, id);
  }

  async getRemarksForStudent(schoolId: string, studentId: string) {
    return this.remarkRepository.findForStudent(schoolId, studentId);
  }
}
