import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { jwtVerify } from "jose";

export async function middleware(request: NextRequest) {
  // 1. Version Compatibility check
  const appVersion = request.headers.get("x-app-version");
  const minSupportedVersion = process.env.MIN_SUPPORTED_APP_VERSION || "1.0.0";
  const latestVersion = process.env.LATEST_APP_VERSION || "1.0.0";

  if (appVersion) {
    if (!isVersionCompatible(appVersion, minSupportedVersion)) {
      return new NextResponse(
        JSON.stringify({
          success: false,
          message: "A newer version of the app is required. Please update.",
          code: "FORCE_UPDATE",
          minimumSupportedVersion: minSupportedVersion,
          latestVersion,
        }),
        {
          status: 426,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
  }

  // 2. Route Protection & Auth
  const { pathname } = request.nextUrl;

  const isAuthRoute =
    pathname.startsWith("/api/auth/login") ||
    pathname.startsWith("/api/auth/refresh") ||
    pathname.startsWith("/api/auth/logout");

  if (pathname.startsWith("/api") && !isAuthRoute) {
    const authHeader = request.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new NextResponse(
        JSON.stringify({
          success: false,
          message: "Unauthorized: Missing or invalid token format",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    const token = authHeader.split(" ")[1];
    if (!token) {
      return new NextResponse(
        JSON.stringify({
          success: false,
          message: "Unauthorized: Missing token",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    try {
      const secret = new TextEncoder().encode(
        process.env.JWT_ACCESS_SECRET ||
          "default_access_secret_change_me_in_production",
      );
      const { payload } = await jwtVerify(token, secret);

      // Resolve Tenant and User context, forward them via headers
      const requestHeaders = new Headers(request.headers);
      requestHeaders.set("x-user-id", payload.userId as string);
      requestHeaders.set("x-school-id", payload.schoolId as string);
      requestHeaders.set("x-user-role", payload.role as string);

      return NextResponse.next({
        request: {
          headers: requestHeaders,
        },
      });
    } catch (err) {
      return new NextResponse(
        JSON.stringify({
          success: false,
          message: "Unauthorized: Invalid or expired token",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }
  }

  return NextResponse.next();
}

function isVersionCompatible(appVersion: string, minVersion: string): boolean {
  const appParts = appVersion.split(".").map(Number);
  const minParts = minVersion.split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    const appPart = appParts[i] || 0;
    const minPart = minParts[i] || 0;
    if (appPart > minPart) return true;
    if (appPart < minPart) return false;
  }
  return true;
}

export const config = {
  matcher: ["/api/:path*"],
};
