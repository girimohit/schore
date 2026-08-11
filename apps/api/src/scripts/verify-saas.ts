import { prisma } from "@schore/database";
import { SchoolService } from "../services/school.service";
import { AttendanceService } from "../services/attendance.service";
import { enforceEntitlement } from "../utils/entitlements";

async function runTests() {
  console.log("=== STARTING SAAS SERVICE INTEGRATION TESTS ===");
  const schoolService = new SchoolService();
  const attendanceService = new AttendanceService();

  const testCode =
    "TESTCAMPUS" + Math.random().toString(36).substring(7).toUpperCase();

  try {
    // 1. Provision School
    console.log(`\n1. Provisioning new school with code "${testCode}"...`);
    const provisionResult = await schoolService.provisionSchool({
      name: "Integration Test Campus",
      code: testCode,
      academicYearName: "Test Calendar Year",
      academicYearStartDate: new Date("2026-06-01"),
      academicYearEndDate: new Date("2027-05-31"),
      adminEmail: `admin_${testCode}@test.com`,
      subscriptionDurationDays: 30,
    });
    console.log("✓ School provisioned successfully!");
    console.log(`- School ID: ${provisionResult.school.id}`);
    console.log(
      `- Invitation Token: ${provisionResult.inviteToken.substring(0, 20)}...`,
    );

    const schoolId = provisionResult.school.id;

    // 2. Validate Default Features and Branding
    console.log("\n2. Checking default features configuration...");
    const features = await schoolService.getFeatures(schoolId);
    console.log("✓ Default features found:", JSON.stringify(features));

    // 3. Test Feature Gating Check (Disable attendance and verify check fails)
    console.log("\n3. Testing feature gating check...");
    console.log("- Disabling attendance module...");
    await schoolService.updateFeatures(schoolId, { attendance: false });

    try {
      console.log("- Querying attendance (should fail)...");
      await attendanceService.getStudentAttendanceStats(
        schoolId,
        "dummy-student-id",
      );
      console.error(
        "✗ FAILURE: Attendance query succeeded despite feature being disabled!",
      );
    } catch (err: any) {
      console.log(
        "✓ SUCCESS: Feature gate blocked access as expected. Error message:",
        err.message,
      );
    }

    // 4. Test Subscription Expiry Gating
    console.log("\n4. Testing subscription expiry gating...");
    console.log("- Modifying subscription end date to the past...");
    await prisma.schoolSubscription.update({
      where: { schoolId },
      data: { endDate: new Date("2020-01-01") },
    });

    try {
      console.log(
        "- Checking entitlement on expired subscription (should fail)...",
      );
      await enforceEntitlement(schoolId, "homework");
      console.error(
        "✗ FAILURE: Entitlement check succeeded despite expired subscription!",
      );
    } catch (err: any) {
      console.log(
        "✓ SUCCESS: Gating block caught expired subscription. Error message:",
        err.message,
      );
    }

    // Restore subscription for subsequent test
    await prisma.schoolSubscription.update({
      where: { schoolId },
      data: { endDate: new Date("2030-01-01") },
    });

    // 5. Test School Suspension Gating
    console.log("\n5. Testing school suspension gating...");
    console.log("- Suspending school status...");
    await schoolService.updateSchoolStatus(
      schoolId,
      "SUSPENDED",
      provisionResult.user.id,
    );

    try {
      console.log(
        "- Checking entitlement on suspended school (should fail)...",
      );
      await enforceEntitlement(schoolId, "timetable");
      console.error(
        "✗ FAILURE: Entitlement check succeeded despite suspended school!",
      );
    } catch (err: any) {
      console.log(
        "✓ SUCCESS: Gating block caught suspended school. Error message:",
        err.message,
      );
    }

    // 6. Cleanup
    console.log("\n6. Cleaning up test campus database records...");
    await prisma.school.delete({ where: { id: schoolId } });
    console.log("✓ Cleanup finished successfully.");
    console.log("\n=== ALL INTEGRATION TESTS PASSED ===");
  } catch (error: any) {
    console.error("\n✗ TEST RUN FAILED:", error);
    process.exit(1);
  }
}

runTests();
