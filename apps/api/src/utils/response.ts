import { NextResponse } from "next/server";

export class ApiResponse {
  static success(data: any = null, message = "Success", status = 200) {
    return NextResponse.json(
      {
        success: true,
        message,
        data,
      },
      { status }
    );
  }

  static error(message = "An error occurred", status = 500, errors: any = null) {
    return NextResponse.json(
      {
        success: false,
        message,
        errors,
      },
      { status }
    );
  }

  static unauthorized(message = "Unauthorized") {
    return this.error(message, 401);
  }

  static forbidden(message = "Forbidden") {
    return this.error(message, 403);
  }

  static badRequest(message = "Bad Request", errors: any = null) {
    return this.error(message, 400, errors);
  }

  static notFound(message = "Resource not found") {
    return this.error(message, 404);
  }
}
