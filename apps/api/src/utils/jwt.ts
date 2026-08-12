import jwt from "jsonwebtoken";

const ACCESS_SECRET =
  process.env.JWT_ACCESS_SECRET ||
  "default_access_secret_change_me_in_production";
const REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET ||
  "default_refresh_secret_change_me_in_production";



export interface JwtPayload {
  userId: string;
  schoolId: string;
  role: string;
}

export function generateAccessToken(payload: JwtPayload): string {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: "15m" });
}

export function generateRefreshToken(payload: JwtPayload): string {
  return jwt.sign(payload, REFRESH_SECRET, { expiresIn: "7d" });
}

export function verifyAccessToken(token: string): JwtPayload {
  return jwt.verify(token, ACCESS_SECRET) as JwtPayload;
}

export function verifyRefreshToken(token: string): JwtPayload {
  return jwt.verify(token, REFRESH_SECRET) as JwtPayload;
}

export function generateInvitationToken(payload: {
  userId: string;
  schoolId: string;
  email: string;
}): string {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: "7d" });
}

export function verifyInvitationToken(token: string): {
  userId: string;
  schoolId: string;
  email: string;
} {
  return jwt.verify(token, ACCESS_SECRET) as {
    userId: string;
    schoolId: string;
    email: string;
  };
}
