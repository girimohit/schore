import { NextRequest } from "next/server";
import { ApiResponse } from "../../../src/utils/response";
import { writeFile, mkdir } from "fs/promises";
import path from "path";
import crypto from "crypto";

const MAX_FILE_SIZE = 15 * 1024 * 1024; // 15MB

const ALLOWED_MIME_TYPES = new Set([
  // Images
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  // Documents
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "text/plain",
  "text/csv",
]);

export async function POST(req: NextRequest) {
  try {
    const schoolId = req.headers.get("x-school-id");
    const userId = req.headers.get("x-user-id");

    if (!userId) {
      return ApiResponse.unauthorized("Authentication required to upload files");
    }

    const formData = await req.formData();
    const file = formData.get("file") as File | null;

    if (!file || typeof file === "string") {
      return ApiResponse.badRequest("No file provided");
    }

    if (file.size > MAX_FILE_SIZE) {
      return ApiResponse.badRequest("File size exceeds 15MB limit");
    }

    if (file.type && !ALLOWED_MIME_TYPES.has(file.type)) {
      return ApiResponse.badRequest(
        `Unsupported file type: ${file.type}. Allowed: PDF, Images, Word, Excel, CSV, Text`,
      );
    }

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);

    // Sanitize extension
    const ext = path.extname(file.name || "").toLowerCase() || ".bin";
    const safeExt = ext.replace(/[^a-z0-9.]/gi, "");
    const randomId = crypto.randomBytes(12).toString("hex");
    const uniqueFilename = `${Date.now()}-${randomId}${safeExt}`;

    // Target upload directory in public/uploads
    const uploadDir = path.join(process.cwd(), "public", "uploads");
    await mkdir(uploadDir, { recursive: true });

    const filePath = path.join(uploadDir, uniqueFilename);
    await writeFile(filePath, buffer);

    const fileUrl = `/uploads/${uniqueFilename}`;

    return ApiResponse.success(
      {
        url: fileUrl,
        filename: file.name,
        size: file.size,
        mimeType: file.type,
      },
      "File uploaded successfully",
      201,
    );
  } catch (error: any) {
    return ApiResponse.badRequest(
      error.message || "Failed to process file upload",
    );
  }
}
