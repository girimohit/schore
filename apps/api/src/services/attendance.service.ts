import { z } from "zod";
import { AttendanceRepository } from "../repositories/attendance.repository";
import { AttendanceStatus } from "@schore/database";

const statusEnum = z.nativeEnum(AttendanceStatus);

export const markAttendanceSchema = z.object({
  studentId: z.string().min(1, "Student ID is required"),
  sectionId: z.string().min(1, "Section ID is required"),
  date: z.coerce.date(),
  status: statusEnum,
  note: z.string().optional(),
});

export const batchMarkAttendanceSchema = z.object({
  sectionId: z.string().min(1, "Section ID is required"),
  date: z.coerce.date(),
  records: z
    .array(
      z.object({
        studentId: z.string().min(1, "Student ID is required"),
        status: statusEnum,
        note: z.string().optional(),
      }),
    )
    .min(1, "At least one attendance record is required"),
});

export class AttendanceService {
  private attendanceRepository = new AttendanceRepository();

  async markSingle(
    schoolId: string,
    markedById: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    const data = markAttendanceSchema.parse(input);

    // Faculty auth check
    if (isFaculty) {
      const isAuthorized =
        await this.attendanceRepository.isFacultyAssignedToSection(
          markedById,
          data.sectionId,
        );
      if (!isAuthorized) {
        throw new Error(
          "You are not authorized to mark attendance for this section",
        );
      }
    }

    return this.attendanceRepository.markAttendance(schoolId, {
      ...data,
      markedById,
    });
  }

  async markBatch(
    schoolId: string,
    markedById: string,
    isFaculty: boolean,
    input: unknown,
  ) {
    const data = batchMarkAttendanceSchema.parse(input);

    if (isFaculty) {
      const isAuthorized =
        await this.attendanceRepository.isFacultyAssignedToSection(
          markedById,
          data.sectionId,
        );
      if (!isAuthorized) {
        throw new Error(
          "You are not authorized to mark attendance for this section",
        );
      }
    }

    const results = [];
    for (const record of data.records) {
      const res = await this.attendanceRepository.markAttendance(schoolId, {
        studentId: record.studentId,
        sectionId: data.sectionId,
        date: data.date,
        status: record.status,
        markedById,
        note: record.note,
      });
      results.push(res);
    }

    return results;
  }

  async getDailySectionAttendance(
    schoolId: string,
    sectionId: string,
    date: Date,
    userId: string,
    isFaculty: boolean,
  ) {
    if (isFaculty) {
      const isAuthorized =
        await this.attendanceRepository.isFacultyAssignedToSection(
          userId,
          sectionId,
        );
      if (!isAuthorized) {
        throw new Error("Access denied to this section");
      }
    }
    return this.attendanceRepository.findDailyAttendanceBySection(
      schoolId,
      sectionId,
      date,
    );
  }

  async getStudentAttendanceHistory(
    schoolId: string,
    studentId: string,
    startDate?: Date,
    endDate?: Date,
  ) {
    return this.attendanceRepository.findStudentAttendance(
      schoolId,
      studentId,
      startDate,
      endDate,
    );
  }

  async getStudentAttendanceStats(schoolId: string, studentId: string) {
    return this.attendanceRepository.getStudentStats(schoolId, studentId);
  }
}
