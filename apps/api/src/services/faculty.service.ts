import { z } from "zod";
import {
  FacultyRepository,
  FindFacultyOptions,
} from "../repositories/faculty.repository";
import { UserStatus } from "@schore/database";

const statusEnum = z.nativeEnum(UserStatus);

export const createFacultySchema = z.object({
  userId: z.string().min(1, "User ID is required"),
  employeeId: z.string().min(1, "Employee ID is required"),
  firstName: z.string().min(1, "First name is required"),
  middleName: z.string().optional(),
  lastName: z.string().optional(),
  phone: z.string().optional(),
  email: z.string().email().optional().or(z.literal("")),
  photoUrl: z.string().url().optional().or(z.literal("")),
  joiningDate: z.coerce.date().optional(),
});

export const updateFacultySchema = z.object({
  firstName: z.string().optional(),
  middleName: z.string().optional(),
  lastName: z.string().optional(),
  phone: z.string().optional(),
  email: z.string().email().optional().or(z.literal("")),
  photoUrl: z.string().url().optional().or(z.literal("")),
  joiningDate: z.coerce.date().optional(),
  status: statusEnum.optional(),
});

export class FacultyService {
  private facultyRepository = new FacultyRepository();

  async createFaculty(schoolId: string, input: unknown) {
    const data = createFacultySchema.parse(input);
    return this.facultyRepository.createFaculty(schoolId, {
      ...data,
      email: data.email || undefined,
      photoUrl: data.photoUrl || undefined,
    });
  }

  async updateFaculty(schoolId: string, facultyId: string, input: unknown) {
    const data = updateFacultySchema.parse(input);
    return this.facultyRepository.updateFaculty(schoolId, facultyId, {
      ...data,
      email: data.email || undefined,
      photoUrl: data.photoUrl || undefined,
    });
  }

  async getFacultyById(schoolId: string, id: string) {
    const faculty = await this.facultyRepository.findById(schoolId, id);
    if (!faculty) {
      throw new Error("Faculty profile not found");
    }
    return faculty;
  }

  async getFacultyByUserId(schoolId: string, userId: string) {
    const faculty = await this.facultyRepository.findByUserId(schoolId, userId);
    if (!faculty) {
      throw new Error("Faculty profile not found for this user");
    }
    return faculty;
  }

  async searchFaculty(schoolId: string, options: FindFacultyOptions) {
    return this.facultyRepository.findFaculty(schoolId, options);
  }
}
