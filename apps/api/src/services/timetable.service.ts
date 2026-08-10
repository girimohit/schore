import { z } from "zod";
import { TimetableRepository, CreateTimetableInput } from "../repositories/timetable.repository";

export const createTimetableSchema = z.object({
  classId: z.string().min(1, "Class ID is required"),
  sectionId: z.string().min(1, "Section ID is required"),
  subjectId: z.string().min(1, "Subject ID is required"),
  facultyId: z.string().optional(),
  dayOfWeek: z.number().min(1, "Day must be between 1 and 7").max(7),
  period: z.number().min(1, "Period must be at least 1"),
  startTime: z.string().min(1, "Start time is required"),
  endTime: z.string().min(1, "End time is required"),
  room: z.string().optional(),
});

export const updateTimetableSchema = z.object({
  classId: z.string().optional(),
  sectionId: z.string().optional(),
  subjectId: z.string().optional(),
  facultyId: z.string().optional(),
  dayOfWeek: z.number().min(1).max(7).optional(),
  period: z.number().min(1).optional(),
  startTime: z.string().optional(),
  endTime: z.string().optional(),
  room: z.string().optional(),
});

export class TimetableService {
  private timetableRepository = new TimetableRepository();

  async createEntry(schoolId: string, input: unknown) {
    const data = createTimetableSchema.parse(input);

    // 1. Conflict Check: Class/Section conflict
    const classConflict = await this.timetableRepository.checkClassConflict(
      schoolId,
      data.classId,
      data.sectionId,
      data.dayOfWeek,
      data.period
    );
    if (classConflict) {
      throw new Error(`This class/section already has a period assigned at Day ${data.dayOfWeek}, Period ${data.period}`);
    }

    // 2. Conflict Check: Faculty conflict (if facultyId is provided)
    if (data.facultyId) {
      const facultyConflict = await this.timetableRepository.checkFacultyConflict(
        schoolId,
        data.facultyId,
        data.dayOfWeek,
        data.period
      );
      if (facultyConflict) {
        throw new Error("This faculty member is already scheduled for another class during this period");
      }
    }

    return this.timetableRepository.createEntry(schoolId, data);
  }

  async updateEntry(schoolId: string, id: string, input: unknown) {
    const data = updateTimetableSchema.parse(input);

    const existing = await this.timetableRepository.findById(schoolId, id);
    if (!existing) {
      throw new Error("Timetable entry not found");
    }

    const classId = data.classId || existing.classId;
    const sectionId = data.sectionId || existing.sectionId;
    const dayOfWeek = data.dayOfWeek !== undefined ? data.dayOfWeek : existing.dayOfWeek;
    const period = data.period !== undefined ? data.period : existing.period;
    const facultyId = data.facultyId !== undefined ? data.facultyId : (existing.facultyId || undefined);

    // Check class conflict
    const classConflict = await this.timetableRepository.checkClassConflict(
      schoolId,
      classId,
      sectionId,
      dayOfWeek,
      period,
      id
    );
    if (classConflict) {
      throw new Error(`Conflict: Class/section has another assignment at Day ${dayOfWeek}, Period ${period}`);
    }

    // Check faculty conflict
    if (facultyId) {
      const facultyConflict = await this.timetableRepository.checkFacultyConflict(
        schoolId,
        facultyId,
        dayOfWeek,
        period,
        id
      );
      if (facultyConflict) {
        throw new Error("Conflict: Faculty member is scheduled elsewhere during this period");
      }
    }

    return this.timetableRepository.updateEntry(schoolId, id, data);
  }

  async deleteEntry(schoolId: string, id: string) {
    const existing = await this.timetableRepository.findById(schoolId, id);
    if (!existing) {
      throw new Error("Timetable entry not found");
    }
    return this.timetableRepository.deleteEntry(schoolId, id);
  }

  async getEntryDetails(schoolId: string, id: string) {
    const entry = await this.timetableRepository.findById(schoolId, id);
    if (!entry) {
      throw new Error("Timetable entry not found");
    }
    return entry;
  }

  async getClassTimetable(schoolId: string, classId: string, sectionId: string) {
    return this.timetableRepository.findForClass(schoolId, classId, sectionId);
  }

  async getFacultyTimetable(schoolId: string, facultyId: string) {
    return this.timetableRepository.findForFaculty(schoolId, facultyId);
  }
}
