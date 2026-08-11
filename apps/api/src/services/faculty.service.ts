import { z } from "zod";
import {
  FacultyRepository,
  FindFacultyOptions,
} from "../repositories/faculty.repository";
import { UserStatus, prisma } from "@schore/database";
import bcrypt from "bcryptjs";

const statusEnum = z.nativeEnum(UserStatus);

export const createFacultySchema = z.object({
  userId: z.string().optional(),
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

    return prisma.$transaction(async (tx) => {
      let resolvedUserId = data.userId;

      if (!resolvedUserId) {
        // Auto-create a corresponding User account for the faculty
        const email =
          data.email || `${data.employeeId.toLowerCase()}@schore.internal`;

        // Check if user already exists
        const existingUser = await tx.user.findFirst({
          where: { email },
        });

        if (existingUser) {
          throw new Error(`Email "${email}" is already registered.`);
        }

        const passwordHash = await bcrypt.hash("schore123", 12);
        const newUser = await tx.user.create({
          data: {
            schoolId,
            email,
            phone: data.phone || null,
            passwordHash,
            role: "FACULTY",
            status: "ACTIVE",
          },
        });
        resolvedUserId = newUser.id;
      }

      // Verify that this employeeId isn't already used in this school
      const existingFaculty = await tx.faculty.findFirst({
        where: {
          schoolId,
          employeeId: data.employeeId,
        },
      });

      if (existingFaculty) {
        throw new Error(
          `Employee ID "${data.employeeId}" is already registered.`,
        );
      }

      return tx.faculty.create({
        data: {
          schoolId,
          userId: resolvedUserId,
          employeeId: data.employeeId,
          firstName: data.firstName,
          middleName: data.middleName || null,
          lastName: data.lastName || null,
          phone: data.phone || null,
          email: data.email || null,
          photoUrl: data.photoUrl || null,
          joiningDate: data.joiningDate || null,
          status: "ACTIVE",
        },
      });
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
