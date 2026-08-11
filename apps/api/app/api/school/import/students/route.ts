import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@schore/database";
import { ApiResponse } from "../../../../../src/utils/response";
import bcrypt from "bcryptjs";
import { Gender } from "@schore/database";

const studentRowSchema = z.object({
  firstname: z.string().min(1, "First name is required"),
  lastname: z.string().optional(),
  email: z.string().email("Invalid email address"),
  phone: z.string().optional(),
  admissionnumber: z.string().min(1, "Admission number is required"),
  rollnumber: z.coerce.number().int().optional(),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]),
  dateofbirth: z.string().transform((val) => new Date(val)),
  classid: z.string().min(1, "Class ID is required"),
  sectionid: z.string().min(1, "Section ID is required"),
  academicyearid: z.string().min(1, "Academic Year ID is required"),
});

function parseCSV(text: string): string[][] {
  const result: string[][] = [];
  const lines = text.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i];
    if (!rawLine) continue;
    const line = rawLine.trim();
    if (!line) continue;

    const row: string[] = [];
    let inQuotes = false;
    let currentField = "";

    for (let j = 0; j < line.length; j++) {
      const char = line[j];

      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === "," && !inQuotes) {
        row.push(currentField.trim());
        currentField = "";
      } else {
        currentField += char;
      }
    }
    row.push(currentField.trim());
    result.push(row);
  }
  return result;
}

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const role = req.headers.get("x-user-role");

    if (!schoolId) {
      return ApiResponse.unauthorized("School context required");
    }

    if (role !== "SCHOOL_ADMIN" && role !== "SUPER_ADMIN") {
      return ApiResponse.forbidden(
        "Forbidden: School Admin or Super Admin access required",
      );
    }

    const formData = await req.formData();
    const fileEntry = formData.get("file");

    if (!fileEntry || typeof fileEntry === "string") {
      return ApiResponse.badRequest("No file uploaded under key 'file'");
    }

    const file = fileEntry as File;
    const csvText = await file.text();
    const rows = parseCSV(csvText);

    if (rows.length < 2) {
      return ApiResponse.badRequest("Empty CSV file or missing headers");
    }

    const firstRow = rows[0];
    if (!firstRow) {
      return ApiResponse.badRequest("No header row found in CSV");
    }

    const headers = firstRow.map((h) => h.toLowerCase().replace(/[\s_-]/g, ""));
    const recordRows = rows.slice(1);

    let successCount = 0;
    let failureCount = 0;
    const errors: Array<{ row: number; error: string; data?: any }> = [];

    const defaultPasswordHash = await bcrypt.hash("schore123", 12);

    for (let i = 0; i < recordRows.length; i++) {
      const rowNum = i + 2;
      const rowData = recordRows[i];

      if (!rowData) {
        continue;
      }

      if (rowData.length === 0 || (rowData.length === 1 && rowData[0] === "")) {
        continue;
      }

      const record: any = {};
      headers.forEach((header, index) => {
        record[header] = rowData[index] || "";
      });

      const parsed = studentRowSchema.safeParse(record);
      if (!parsed.success) {
        failureCount++;
        const errMsg = parsed.error.issues
          .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
          .join(", ");
        errors.push({ row: rowNum, error: errMsg, data: record });
        continue;
      }

      const data = parsed.data;

      try {
        await prisma.$transaction(async (tx) => {
          const existingUser = await tx.user.findFirst({
            where: { email: data.email },
          });
          if (existingUser) {
            throw new Error(`Email "${data.email}" is already registered.`);
          }

          const existingStudent = await tx.student.findFirst({
            where: { schoolId, admissionNumber: data.admissionnumber },
          });
          if (existingStudent) {
            throw new Error(
              `Admission number "${data.admissionnumber}" is already in use.`,
            );
          }

          const user = await tx.user.create({
            data: {
              schoolId,
              email: data.email,
              phone: data.phone || null,
              passwordHash: defaultPasswordHash,
              role: "STUDENT",
              status: "ACTIVE",
            },
          });

          const student = await tx.student.create({
            data: {
              schoolId,
              userId: user.id,
              admissionNumber: data.admissionnumber,
              firstName: data.firstname,
              lastName: data.lastname || null,
              dateOfBirth: data.dateofbirth,
              gender: data.gender as Gender,
              phone: data.phone || null,
              email: data.email,
              status: "ACTIVE",
            },
          });

          await tx.studentEnrollment.create({
            data: {
              schoolId,
              studentId: student.id,
              academicYearId: data.academicyearid,
              classId: data.classid,
              sectionId: data.sectionid,
              rollNumber: data.rollnumber || null,
            },
          });
        });

        successCount++;
      } catch (err: any) {
        failureCount++;
        errors.push({
          row: rowNum,
          error: err.message || "Database write failed",
          data: record,
        });
      }
    }

    return ApiResponse.success(
      {
        successCount,
        failureCount,
        errors,
      },
      "Student CSV processed successfully",
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to process student CSV file",
    );
  }
}
