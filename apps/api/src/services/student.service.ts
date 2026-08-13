import { z } from "zod";
import {
  StudentRepository,
  FindStudentsOptions,
} from "../repositories/student.repository";
import { Gender, StudentStatus, prisma } from "@schore/database";
import bcrypt from "bcryptjs";
import { generateInvitationToken } from "../utils/jwt";

const genderEnum = z.nativeEnum(Gender);
const studentStatusEnum = z.nativeEnum(StudentStatus);

export const createStudentSchema = z.object({
  admissionNumber: z.string().min(1, "Admission number is required"),
  firstName: z.string().min(1, "First name is required"),
  middleName: z.string().optional(),
  lastName: z.string().optional(),
  dateOfBirth: z.coerce.date().optional(),
  gender: genderEnum.optional(),
  photoUrl: z.string().url().optional().or(z.literal("")),
  bloodGroup: z.string().optional(),
  email: z.string().email().optional().or(z.literal("")),
  phone: z.string().optional(),
  address: z.string().optional(),
  admissionDate: z.coerce.date().optional(),
  userId: z.string().optional(),
  academicYearId: z.string().min(1, "Academic Year ID is required"),
  classId: z.string().min(1, "Class ID is required"),
  sectionId: z.string().min(1, "Section ID is required"),
  rollNumber: z.number().int().optional(),
});

export const updateStudentSchema = z.object({
  firstName: z.string().optional(),
  middleName: z.string().optional(),
  lastName: z.string().optional(),
  dateOfBirth: z.coerce.date().optional(),
  gender: genderEnum.optional(),
  photoUrl: z.string().url().optional().or(z.literal("")),
  bloodGroup: z.string().optional(),
  email: z.string().email().optional().or(z.literal("")),
  phone: z.string().optional(),
  address: z.string().optional(),
  admissionDate: z.coerce.date().optional(),
  status: studentStatusEnum.optional(),
});

export class StudentService {
  private studentRepository = new StudentRepository();

  async createStudent(schoolId: string, input: unknown) {
    const data = createStudentSchema.parse(input);
    if (data.email) {
      data.email = data.email.trim().toLowerCase();
    }

    return prisma.$transaction(async (tx) => {
      let resolvedUserId = data.userId;

      if (!resolvedUserId) {
        // Auto-create corresponding User account
        const email = (data.email || `${data.admissionNumber.toLowerCase()}@schore.internal`).trim().toLowerCase();

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
            role: "STUDENT",
            status: "INACTIVE",
          },
        });
        resolvedUserId = newUser.id;

        // Generate invitation token & save to db
        const crypto = await import("crypto");
        const inviteToken = crypto.randomBytes(32).toString("hex");
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 7);

        await tx.invitation.create({
          data: {
            schoolId,
            email,
            role: "STUDENT",
            token: inviteToken,
            status: "INVITED",
            expiresAt,
            userId: newUser.id,
          },
        });

        const inviteLink = `http://localhost:3000/onboarding?token=${inviteToken}`;
        const { NotificationService } = await import("./notification.service");
        const notificationService = new NotificationService();
        await notificationService.sendInvitation({
          email,
          phone: data.phone || undefined,
          role: "STUDENT",
          inviteLink,
        });
      }

      return this.studentRepository.createStudent(schoolId, {
        ...data,
        userId: resolvedUserId,
        photoUrl: data.photoUrl || undefined,
        email: data.email || undefined,
      });
    });
  }

  async updateStudent(schoolId: string, studentId: string, input: unknown) {
    const data = updateStudentSchema.parse(input);
    return this.studentRepository.updateStudent(schoolId, studentId, {
      ...data,
      photoUrl: data.photoUrl || undefined,
      email: data.email || undefined,
    });
  }

  async getStudentById(schoolId: string, studentId: string) {
    const student = await this.studentRepository.findById(schoolId, studentId);
    if (!student) {
      throw new Error("Student not found");
    }
    return student;
  }

  async getStudentByUserId(schoolId: string, userId: string) {
    const student = await this.studentRepository.findByUserId(schoolId, userId);
    if (!student) {
      throw new Error("Student profile not found");
    }
    return student;
  }

  async searchStudents(schoolId: string, options: FindStudentsOptions) {
    return this.studentRepository.findStudents(schoolId, options);
  }

  async searchStudentsForFaculty(
    schoolId: string,
    facultyId: string,
    options: FindStudentsOptions,
  ) {
    return this.studentRepository.findStudentsForFaculty(
      schoolId,
      facultyId,
      options,
    );
  }

  async checkFacultyAccess(
    schoolId: string,
    studentId: string,
    facultyId: string,
  ): Promise<boolean> {
    return this.studentRepository.checkFacultyAccess(
      schoolId,
      studentId,
      facultyId,
    );
  }
}
