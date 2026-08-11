import {
  UserRole,
  UserStatus,
  SchoolStatus,
} from "../src/generated/prisma/enums";
import bcrypt from "bcryptjs";
import { prisma } from "../src/index";

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
      status: SchoolStatus.ACTIVE,
    },
  });

  console.log("Seeding School Branding...");
  await prisma.schoolBranding.upsert({
    where: { schoolId: school.id },
    update: {},
    create: {
      schoolId: school.id,
      appName: "Schore ERP",
      logoUrl:
        "https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=128&h=128&fit=crop",
      primaryColor: "#6366F1",
      secondaryColor: "#4F46E5",
      themeMode: "DARK",
      fontFamily: "Inter",
      splashImageUrl:
        "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=800&h=600&fit=crop",
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

  async function getOrCreateUser(
    email: string,
    role: UserRole,
    schoolId?: string,
  ) {
    let user = await prisma.user.findFirst({ where: { email } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          passwordHash: hashedPassword,
          role,
          status: UserStatus.ACTIVE,
          schoolId,
        },
      });
    } else if (schoolId && user.schoolId !== schoolId) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { schoolId },
      });
    }
    return user;
  }

  console.log("Seeding Users...");
  // Super Admin
  await getOrCreateUser("superadmin@schore.com", UserRole.SUPER_ADMIN);

  // School Admin (linked to school)
  await getOrCreateUser("admin@schore.com", UserRole.SCHOOL_ADMIN, school.id);

  // Faculty User
  const facultyUser = await getOrCreateUser(
    "faculty@schore.com",
    UserRole.FACULTY,
    school.id,
  );

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
  const studentUser = await getOrCreateUser(
    "student@schore.com",
    UserRole.STUDENT,
    school.id,
  );

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
