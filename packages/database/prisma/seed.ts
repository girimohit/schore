import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  console.log("Seeding permissions...");
  const permissions = [
    // School level permissions
    { name: "school:read", description: "View school information" },
    { name: "school:write", description: "Update school details" },
    
    // User permissions
    { name: "user:read", description: "View user records" },
    { name: "user:create", description: "Create new users" },
    { name: "user:update", description: "Update user profiles" },
    { name: "user:delete", description: "Delete users" },
    
    // Branding & Feature flags
    { name: "branding:read", description: "View branding configuration" },
    { name: "branding:write", description: "Update branding styles" },
    { name: "features:read", description: "View feature toggles" },
    { name: "features:write", description: "Update feature toggles" },

    // Audit logs
    { name: "audit:read", description: "Read audit log entries" },
  ];

  const dbPermissions = [];
  for (const perm of permissions) {
    const dbPerm = await prisma.permission.upsert({
      where: { name: perm.name },
      update: { description: perm.description },
      create: perm,
    });
    dbPermissions.push(dbPerm);
  }

  console.log("Seeding roles...");
  const roles = [
    { name: "Super Admin", description: "System-wide owner" },
    { name: "School Admin", description: "School administrator" },
    { name: "Faculty", description: "Teachers and instructors" },
    { name: "Student", description: "Students and learners" },
  ];

  const dbRoles: Record<string, any> = {};
  for (const role of roles) {
    dbRoles[role.name] = await prisma.role.upsert({
      where: { name: role.name },
      update: { description: role.description },
      create: role,
    });
  }

  // Assign permissions to roles
  console.log("Mapping permissions to Super Admin...");
  await prisma.role.update({
    where: { id: dbRoles["Super Admin"].id },
    data: {
      permissions: {
        set: dbPermissions.map((p) => ({ id: p.id })),
      },
    },
  });

  console.log("Mapping permissions to School Admin...");
  await prisma.role.update({
    where: { id: dbRoles["School Admin"].id },
    data: {
      permissions: {
        set: dbPermissions.map((p) => ({ id: p.id })),
      },
    },
  });

  console.log("Mapping permissions to Faculty...");
  await prisma.role.update({
    where: { id: dbRoles["Faculty"].id },
    data: {
      permissions: {
        set: dbPermissions
          .filter((p) =>
            ["school:read", "user:read", "branding:read", "features:read"].includes(p.name)
          )
          .map((p) => ({ id: p.id })),
      },
    },
  });

  console.log("Mapping permissions to Student...");
  await prisma.role.update({
    where: { id: dbRoles["Student"].id },
    data: {
      permissions: {
        set: dbPermissions
          .filter((p) => ["school:read", "branding:read"].includes(p.name))
          .map((p) => ({ id: p.id })),
      },
    },
  });

  // Seed default Demo School
  console.log("Seeding Demo School...");
  const school = await prisma.school.upsert({
    where: { domain: "demo.schore.com" },
    update: {},
    create: {
      name: "Acme Academy",
      domain: "demo.schore.com",
    },
  });

  // Seed branding config
  console.log("Seeding Branding configuration...");
  await prisma.schoolBranding.upsert({
    where: { schoolId: school.id },
    update: {},
    create: {
      schoolId: school.id,
      schoolName: "Acme Academy",
      appName: "Schore ERP",
      logoUrl: "https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=128&h=128&fit=crop",
      primaryColor: "#6366F1",
      secondaryColor: "#4F46E5",
      themeMode: "DARK",
      font: "Inter",
      splashImageUrl: "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=800&h=600&fit=crop",
    },
  });

  // Seed feature flags
  console.log("Seeding School Feature flags...");
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
    },
  });

  // Seed default Super Admin User
  console.log("Seeding Super Admin user...");
  const hashedPassword = await bcrypt.hash("Admin@123", 12);
  const email = "superadmin@schore.com";

  await prisma.user.upsert({
    where: { email },
    update: {
      roleId: dbRoles["Super Admin"].id,
      schoolId: school.id,
    },
    create: {
      email,
      passwordHash: hashedPassword,
      firstName: "Super",
      lastName: "Admin",
      schoolId: school.id,
      roleId: dbRoles["Super Admin"].id,
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
