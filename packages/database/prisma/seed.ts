import { PrismaClient, UserRole, UserStatus } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  console.log("Seeding Demo School...");
  const school = await prisma.school.upsert({
    where: { code: "DEMO123" },
    update: {},
    create: {
      name: "Acme Academy",
      code: "DEMO123",
      email: "info@demo.schore.com",
      phone: "1234567890",
      address: "123 Education Way",
      status: UserStatus.ACTIVE,
    },
  });

  console.log("Seeding School Branding...");
  await prisma.schoolBranding.upsert({
    where: { schoolId: school.id },
    update: {},
    create: {
      schoolId: school.id,
      appName: "Schore ERP",
      logoUrl: "https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=128&h=128&fit=crop",
      primaryColor: "#6366F1",
      secondaryColor: "#4F46E5",
      themeMode: "DARK",
      fontFamily: "Inter",
      splashImageUrl: "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=800&h=600&fit=crop",
    },
  });

  console.log("Seeding School Features...");
  await prisma.schoolFeatures.upsert({
    where: { schoolId: school.id },
    update: {},
    create: {
      schoolId: school.id,
      attendance: true,
      homework: true,
      exams: true,
      notices: true,
      remarks: true,
      timetable: true,
    },
  });

  const hashedPassword = await bcrypt.hash("Admin@123", 12);

  console.log("Seeding Users...");
  // Super Admin
  await prisma.user.upsert({
    where: { email: "superadmin@schore.com" },
    update: {},
    create: {
      email: "superadmin@schore.com",
      passwordHash: hashedPassword,
      role: UserRole.SUPER_ADMIN,
      status: UserStatus.ACTIVE,
    },
  });

  // School Admin (linked to school)
  await prisma.user.upsert({
    where: { email: "admin@schore.com" },
    update: { schoolId: school.id },
    create: {
      email: "admin@schore.com",
      passwordHash: hashedPassword,
      role: UserRole.SCHOOL_ADMIN,
      status: UserStatus.ACTIVE,
      schoolId: school.id,
    },
  });

  // Faculty User
  const facultyUser = await prisma.user.upsert({
    where: { email: "faculty@schore.com" },
    update: { schoolId: school.id },
    create: {
      email: "faculty@schore.com",
      passwordHash: hashedPassword,
      role: UserRole.FACULTY,
      status: UserStatus.ACTIVE,
      schoolId: school.id,
    },
  });

  // Faculty Profile
  await prisma.faculty.upsert({
    where: { userId: facultyUser.id },
    update: {},
    create: {
      schoolId: school.id,
      userId: facultyUser.id,
      employeeId: "FAC001",
      firstName: "John",
      lastName: "Doe",
      email: "faculty@schore.com",
      status: UserStatus.ACTIVE,
    },
  });

  // Student User
  const studentUser = await prisma.user.upsert({
    where: { email: "student@schore.com" },
    update: { schoolId: school.id },
    create: {
      email: "student@schore.com",
      passwordHash: hashedPassword,
      role: UserRole.STUDENT,
      status: UserStatus.ACTIVE,
      schoolId: school.id,
    },
  });

  // Student Profile
  await prisma.student.upsert({
    where: { userId: studentUser.id },
    update: {},
    create: {
      schoolId: school.id,
      userId: studentUser.id,
      admissionNumber: "STUD001",
      firstName: "Jane",
      lastName: "Smith",
      email: "student@schore.com",
    },
  });

  console.log("Database seeding completed successfully!");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
