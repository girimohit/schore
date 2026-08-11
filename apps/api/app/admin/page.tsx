"use client";

import React, { useState, useEffect } from "react";
import styles from "./admin.module.css";

const ADMIN_HEADERS = {
  "Content-Type": "application/json",
  "x-user-role": "SUPER_ADMIN",
  "x-user-id": "super-admin-web-dashboard",
};

interface School {
  id: string;
  name: string;
  code: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  status: "PENDING" | "ACTIVE" | "SUSPENDED" | "INACTIVE";
  branding?: {
    appName: string;
    logoUrl: string | null;
    splashImageUrl: string | null;
    primaryColor: string;
    secondaryColor: string;
    fontFamily: string;
    themeMode: string;
  };
  features?: {
    attendance: boolean;
    homework: boolean;
    exams: boolean;
    notices: boolean;
    remarks: boolean;
    timetable: boolean;
  };
  subscription?: {
    plan: string;
    status: string;
    startDate: string;
    endDate: string;
  };
  _count?: {
    students: number;
    faculty: number;
  };
}

interface AuditLog {
  id: string;
  action: string;
  entity: string | null;
  entityId: string | null;
  metadata: any;
  createdAt: string;
  user?: {
    email: string;
    role: string;
  };
  school?: {
    name: string;
    code: string;
  };
}

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState<"overview" | "schools" | "logs">(
    "overview",
  );

  // Stats & Config
  const [stats, setStats] = useState({
    totalSchools: 0,
    activeSchools: 0,
    totalStudents: 0,
    totalFaculty: 0,
    activeSubscriptions: 0,
  });

  const [platformConfig, setPlatformConfig] = useState({
    maintenanceMode: false,
    minAndroidVersion: "1.0.0",
    minIosVersion: "1.0.0",
    latestAndroidVersion: "1.0.0",
    latestIosVersion: "1.0.0",
  });

  // Schools list
  const [schools, setSchools] = useState<School[]>([]);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");

  // Audit Logs
  const [auditLogs, setAuditLogs] = useState<AuditLog[]>([]);

  // Modals
  const [showProvisionModal, setShowProvisionModal] = useState(false);
  const [provisionSuccess, setProvisionSuccess] = useState<any>(null);
  const [selectedSchool, setSelectedSchool] = useState<School | null>(null);
  const [configTab, setConfigTab] = useState<
    "branding" | "features" | "actions"
  >("branding");

  // Provision Form Fields
  const [provisionForm, setProvisionForm] = useState({
    name: "",
    code: "",
    email: "",
    phone: "",
    address: "",
    academicYearName: "Academic Year 2026-2027",
    academicYearStartDate: "2026-06-01",
    academicYearEndDate: "2027-05-31",
    adminEmail: "",
    adminPhone: "",
    subscriptionPlan: "TRIAL",
    subscriptionDurationDays: 14,
  });

  // Config Details Form Fields
  const [brandingForm, setBrandingForm] = useState({
    appName: "Schore ERP",
    logoUrl: "",
    splashImageUrl: "",
    primaryColor: "#6366F1",
    secondaryColor: "#4F46E5",
    fontFamily: "Inter",
    themeMode: "DARK",
  });

  const [featuresForm, setFeaturesForm] = useState({
    attendance: true,
    homework: true,
    exams: true,
    notices: true,
    remarks: true,
    timetable: true,
  });

  // Load Data
  const loadDashboardData = async () => {
    try {
      // 1. Fetch Metrics & Config
      const metricsRes = await fetch("/api/admin/metrics", {
        headers: ADMIN_HEADERS,
      });
      const metricsData = await metricsRes.json();
      if (metricsData.success) {
        setStats({
          totalSchools: metricsData.data.totalSchools,
          activeSchools: metricsData.data.activeSchools,
          totalStudents: metricsData.data.totalStudents,
          totalFaculty: metricsData.data.totalFaculty,
          activeSubscriptions: metricsData.data.activeSubscriptions,
        });
        setPlatformConfig({
          maintenanceMode: metricsData.data.maintenanceMode,
          minAndroidVersion: metricsData.data.minAndroidVersion,
          minIosVersion: metricsData.data.minIosVersion,
          latestAndroidVersion: metricsData.data.latestAndroidVersion,
          latestIosVersion: metricsData.data.latestIosVersion,
        });
        setAuditLogs(metricsData.data.recentLogs);
      }

      // 2. Fetch Schools
      const schoolsRes = await fetch("/api/admin/schools?limit=100", {
        headers: ADMIN_HEADERS,
      });
      const schoolsData = await schoolsRes.json();
      if (schoolsData.success) {
        setSchools(schoolsData.data.schools);
      }
    } catch (error) {
      console.error("Failed to load dashboard data:", error);
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  // Save Platform Config
  const handleSavePlatformConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch("/api/admin/config", {
        method: "PATCH",
        headers: ADMIN_HEADERS,
        body: JSON.stringify(platformConfig),
      });
      const data = await res.json();
      if (data.success) {
        alert("Platform configuration saved successfully!");
        loadDashboardData();
      } else {
        alert(`Error: ${data.message}`);
      }
    } catch (err: any) {
      alert(`Error saving platform configuration: ${err.message}`);
    }
  };

  // Provision School Submit
  const handleProvisionSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch("/api/admin/schools", {
        method: "POST",
        headers: ADMIN_HEADERS,
        body: JSON.stringify({
          ...provisionForm,
          academicYearStartDate: new Date(
            provisionForm.academicYearStartDate,
          ).toISOString(),
          academicYearEndDate: new Date(
            provisionForm.academicYearEndDate,
          ).toISOString(),
        }),
      });
      const data = await res.json();
      if (data.success) {
        setProvisionSuccess(data.data);
        setProvisionForm({
          name: "",
          code: "",
          email: "",
          phone: "",
          address: "",
          academicYearName: "Academic Year 2026-2027",
          academicYearStartDate: "2026-06-01",
          academicYearEndDate: "2027-05-31",
          adminEmail: "",
          adminPhone: "",
          subscriptionPlan: "TRIAL",
          subscriptionDurationDays: 14,
        });
        loadDashboardData();
      } else {
        alert(`Error: ${data.message}`);
      }
    } catch (err: any) {
      alert(`Provision error: ${err.message}`);
    }
  };

  // Open School Details
  const handleOpenSchoolDetails = (school: School) => {
    setSelectedSchool(school);
    setBrandingForm({
      appName: school.branding?.appName || "Schore ERP",
      logoUrl: school.branding?.logoUrl || "",
      splashImageUrl: school.branding?.splashImageUrl || "",
      primaryColor: school.branding?.primaryColor || "#6366F1",
      secondaryColor: school.branding?.secondaryColor || "#4F46E5",
      fontFamily: school.branding?.fontFamily || "Inter",
      themeMode: school.branding?.themeMode || "DARK",
    });
    setFeaturesForm({
      attendance: school.features?.attendance ?? true,
      homework: school.features?.homework ?? true,
      exams: school.features?.exams ?? true,
      notices: school.features?.notices ?? true,
      remarks: school.features?.remarks ?? true,
      timetable: school.features?.timetable ?? true,
    });
    setConfigTab("branding");
  };

  // Update Branding config
  const handleSaveBranding = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedSchool) return;
    try {
      const res = await fetch(
        `/api/admin/schools/${selectedSchool.id}/branding`,
        {
          method: "PATCH",
          headers: ADMIN_HEADERS,
          body: JSON.stringify(brandingForm),
        },
      );
      const data = await res.json();
      if (data.success) {
        alert("Branding configuration updated successfully!");
        loadDashboardData();
        setSelectedSchool(null);
      } else {
        alert(`Error: ${data.message}`);
      }
    } catch (err: any) {
      alert(err.message);
    }
  };

  // Update Features config
  const handleSaveFeatures = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedSchool) return;
    try {
      const res = await fetch(
        `/api/admin/schools/${selectedSchool.id}/features`,
        {
          method: "PATCH",
          headers: ADMIN_HEADERS,
          body: JSON.stringify(featuresForm),
        },
      );
      const data = await res.json();
      if (data.success) {
        alert("Feature configurations updated successfully!");
        loadDashboardData();
        setSelectedSchool(null);
      } else {
        alert(`Error: ${data.message}`);
      }
    } catch (err: any) {
      alert(err.message);
    }
  };

  // School Lifecycle Actions
  const handleSchoolAction = async (
    action: "activate" | "suspend" | "deactivate",
  ) => {
    if (!selectedSchool) return;
    if (!confirm(`Are you sure you want to ${action} this school?`)) return;

    try {
      const res = await fetch(
        `/api/admin/schools/${selectedSchool.id}/${action}`,
        {
          method: "POST",
          headers: ADMIN_HEADERS,
        },
      );
      const data = await res.json();
      if (data.success) {
        alert(`School status ${action}d successfully!`);
        loadDashboardData();
        setSelectedSchool(null);
      } else {
        alert(`Error: ${data.message}`);
      }
    } catch (err: any) {
      alert(err.message);
    }
  };

  // Filtered schools
  const filteredSchools = schools.filter((s) => {
    const matchesSearch =
      s.name.toLowerCase().includes(search.toLowerCase()) ||
      s.code.toLowerCase().includes(search.toLowerCase());
    const matchesStatus = statusFilter ? s.status === statusFilter : true;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className={styles.dashboard}>
      {/* Header */}
      <header className={styles.header}>
        <div className={styles.brand}>
          <h1 className={styles.brandTitle}>Schore ERP</h1>
          <span className={styles.brandSub}>Super Admin Central Control</span>
        </div>
        <div className={styles.statusIndicator}>
          <span
            className={`${styles.dot} ${platformConfig.maintenanceMode ? styles.dotMaint : styles.dotActive}`}
          ></span>
          <span>
            {platformConfig.maintenanceMode
              ? "Maintenance Mode Active"
              : "All Systems Operational"}
          </span>
        </div>
      </header>

      {/* Main Container */}
      <div className={styles.container}>
        {/* Navigation Tabs */}
        <nav className={styles.navigation}>
          <button
            className={`${styles.navLink} ${activeTab === "overview" ? styles.navLinkActive : ""}`}
            onClick={() => setActiveTab("overview")}
          >
            Overview & Configuration
          </button>
          <button
            className={`${styles.navLink} ${activeTab === "schools" ? styles.navLinkActive : ""}`}
            onClick={() => setActiveTab("schools")}
          >
            Schools Management
          </button>
          <button
            className={`${styles.navLink} ${activeTab === "logs" ? styles.navLinkActive : ""}`}
            onClick={() => setActiveTab("logs")}
          >
            Platform Audit Logs
          </button>
        </nav>

        {/* Tab 1: Overview */}
        {activeTab === "overview" && (
          <>
            <div className={styles.metricsGrid}>
              <div className={styles.metricCard}>
                <span className={styles.metricTitle}>Total Provisioned</span>
                <span className={styles.metricValue}>
                  {stats.totalSchools} Schools
                </span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricTitle}>Active Sites</span>
                <span className={styles.metricValue}>
                  {stats.activeSchools} Schools
                </span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricTitle}>
                  Total Platform Students
                </span>
                <span className={styles.metricValue}>
                  {stats.totalStudents} Students
                </span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricTitle}>
                  Total Platform Faculty
                </span>
                <span className={styles.metricValue}>
                  {stats.totalFaculty} Instructors
                </span>
              </div>
            </div>

            <div className={styles.contentSplit}>
              {/* Global Config */}
              <div className={styles.panel}>
                <h2 className={styles.panelTitle}>
                  Global Settings Configuration
                </h2>
                <form
                  onSubmit={handleSavePlatformConfig}
                  className={styles.form}
                >
                  <div className={styles.toggleWrapper}>
                    <div>
                      <span
                        className={styles.label}
                        style={{ display: "block" }}
                      >
                        Global Maintenance Block
                      </span>
                      <span
                        style={{
                          fontSize: "0.8125rem",
                          color: "#64748b",
                          marginTop: "0.25rem",
                          display: "block",
                        }}
                      >
                        Enabling this blocks all tenant endpoints immediately.
                      </span>
                    </div>
                    <input
                      type="checkbox"
                      style={{
                        width: "20px",
                        height: "20px",
                        cursor: "pointer",
                      }}
                      checked={platformConfig.maintenanceMode}
                      onChange={(e) =>
                        setPlatformConfig({
                          ...platformConfig,
                          maintenanceMode: e.target.checked,
                        })
                      }
                    />
                  </div>

                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr",
                      gap: "1rem",
                    }}
                  >
                    <div className={styles.formGroup}>
                      <label className={styles.label}>
                        Min Android Version
                      </label>
                      <input
                        className={styles.input}
                        type="text"
                        value={platformConfig.minAndroidVersion}
                        onChange={(e) =>
                          setPlatformConfig({
                            ...platformConfig,
                            minAndroidVersion: e.target.value,
                          })
                        }
                        placeholder="e.g. 1.0.0"
                      />
                    </div>
                    <div className={styles.formGroup}>
                      <label className={styles.label}>Min iOS Version</label>
                      <input
                        className={styles.input}
                        type="text"
                        value={platformConfig.minIosVersion}
                        onChange={(e) =>
                          setPlatformConfig({
                            ...platformConfig,
                            minIosVersion: e.target.value,
                          })
                        }
                        placeholder="e.g. 1.0.0"
                      />
                    </div>
                  </div>

                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr",
                      gap: "1rem",
                    }}
                  >
                    <div className={styles.formGroup}>
                      <label className={styles.label}>
                        Latest Android Version
                      </label>
                      <input
                        className={styles.input}
                        type="text"
                        value={platformConfig.latestAndroidVersion}
                        onChange={(e) =>
                          setPlatformConfig({
                            ...platformConfig,
                            latestAndroidVersion: e.target.value,
                          })
                        }
                        placeholder="e.g. 1.0.0"
                      />
                    </div>
                    <div className={styles.formGroup}>
                      <label className={styles.label}>Latest iOS Version</label>
                      <input
                        className={styles.input}
                        type="text"
                        value={platformConfig.latestIosVersion}
                        onChange={(e) =>
                          setPlatformConfig({
                            ...platformConfig,
                            latestIosVersion: e.target.value,
                          })
                        }
                        placeholder="e.g. 1.0.0"
                      />
                    </div>
                  </div>

                  <button type="submit" className={styles.btn}>
                    Save Platform Configuration
                  </button>
                </form>
              </div>

              {/* Quick Actions */}
              <div className={styles.panel}>
                <h2 className={styles.panelTitle}>Admin Operations</h2>
                <div
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: "1rem",
                  }}
                >
                  <button
                    className={styles.btn}
                    onClick={() => setShowProvisionModal(true)}
                    style={{ width: "100%" }}
                  >
                    Provision New School
                  </button>
                  <button
                    className={`${styles.btn} ${styles.btnSecondary}`}
                    onClick={() => setActiveTab("schools")}
                    style={{ width: "100%" }}
                  >
                    Manage Existing Schools
                  </button>
                  <div
                    style={{
                      padding: "1rem",
                      background: "#0b0f19",
                      borderRadius: "0.5rem",
                      border: "1px solid #1e293b",
                    }}
                  >
                    <span
                      style={{
                        display: "block",
                        fontSize: "0.8125rem",
                        color: "#64748b",
                        lineHeight: "1.4",
                      }}
                    >
                      Use this workspace to register, activate, configure custom
                      themes, and allocate active feature modules to partner
                      campuses.
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </>
        )}

        {/* Tab 2: Schools List */}
        {activeTab === "schools" && (
          <div className={styles.panel}>
            <div className={styles.panelTitle}>
              <span>Registered Campuses</span>
              <button
                className={styles.btn}
                onClick={() => setShowProvisionModal(true)}
              >
                Provision School
              </button>
            </div>

            {/* Filter Bar */}
            <div className={styles.searchBar}>
              <input
                className={styles.input}
                type="text"
                placeholder="Search by school name or code..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="">All Statuses</option>
                <option value="ACTIVE">Active</option>
                <option value="PENDING">Pending Invitation</option>
                <option value="SUSPENDED">Suspended</option>
                <option value="INACTIVE">Deactivated</option>
              </select>
            </div>

            <div className={styles.tableWrapper}>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>School Name</th>
                    <th>Code</th>
                    <th>Status</th>
                    <th>Subscription</th>
                    <th>Enrolled Stats</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredSchools.map((school) => {
                    const statusClass =
                      school.status === "ACTIVE"
                        ? styles.badgeActive
                        : school.status === "PENDING"
                          ? styles.badgePending
                          : school.status === "SUSPENDED"
                            ? styles.badgeSuspended
                            : styles.badgeInactive;

                    return (
                      <tr key={school.id}>
                        <td style={{ fontWeight: "700" }}>{school.name}</td>
                        <td>
                          <span
                            style={{
                              fontFamily: "monospace",
                              background: "#1e293b",
                              padding: "0.25rem 0.5rem",
                              borderRadius: "0.25rem",
                            }}
                          >
                            {school.code}
                          </span>
                        </td>
                        <td>
                          <span className={`${styles.badge} ${statusClass}`}>
                            {school.status.replace("_", " ")}
                          </span>
                        </td>
                        <td>
                          {school.subscription ? (
                            <div>
                              <span style={{ fontWeight: "600" }}>
                                {school.subscription.plan}
                              </span>
                              <span
                                style={{
                                  display: "block",
                                  fontSize: "0.75rem",
                                  color: "#64748b",
                                  marginTop: "0.25rem",
                                }}
                              >
                                Exp:{" "}
                                {new Date(
                                  school.subscription.endDate,
                                ).toLocaleDateString()}
                              </span>
                            </div>
                          ) : (
                            <span style={{ color: "#ef4444" }}>None</span>
                          )}
                        </td>
                        <td>
                          <span
                            style={{ fontSize: "0.8125rem", color: "#94a3b8" }}
                          >
                            👤 {school._count?.students || 0} Students / 💼{" "}
                            {school._count?.faculty || 0} Faculty
                          </span>
                        </td>
                        <td>
                          <button
                            className={`${styles.btn} ${styles.btnSecondary}`}
                            onClick={() => handleOpenSchoolDetails(school)}
                            style={{
                              padding: "0.4rem 0.8rem",
                              fontSize: "0.75rem",
                            }}
                          >
                            Details & Gating
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                  {filteredSchools.length === 0 && (
                    <tr>
                      <td
                        colSpan={6}
                        style={{ textAlign: "center", padding: "2rem" }}
                      >
                        No schools found matching search criteria.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Tab 3: Audit Logs */}
        {activeTab === "logs" && (
          <div className={styles.panel}>
            <h2 className={styles.panelTitle}>Platform Activity Stream</h2>
            <div className={styles.tableWrapper}>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>Date & Time</th>
                    <th>User</th>
                    <th>School</th>
                    <th>Action Event</th>
                    <th>Parameters</th>
                  </tr>
                </thead>
                <tbody>
                  {auditLogs.map((log) => (
                    <tr key={log.id}>
                      <td style={{ fontSize: "0.8125rem", color: "#64748b" }}>
                        {new Date(log.createdAt).toLocaleString()}
                      </td>
                      <td>
                        <span style={{ fontWeight: "600" }}>
                          {log.user?.email || "System"}
                        </span>
                        <span
                          style={{
                            display: "block",
                            fontSize: "0.75rem",
                            color: "#64748b",
                          }}
                        >
                          {log.user?.role}
                        </span>
                      </td>
                      <td>{log.school?.name || "Global"}</td>
                      <td>
                        <span
                          style={{
                            fontWeight: "700",
                            color: "#38bdf8",
                            background: "rgba(56, 189, 248, 0.1)",
                            padding: "0.25rem 0.5rem",
                            borderRadius: "0.25rem",
                            fontSize: "0.75rem",
                          }}
                        >
                          {log.action}
                        </span>
                      </td>
                      <td>
                        <pre
                          style={{
                            margin: 0,
                            fontFamily: "monospace",
                            fontSize: "0.75rem",
                            color: "#94a3b8",
                            whiteSpace: "pre-wrap",
                          }}
                        >
                          {JSON.stringify(log.metadata)}
                        </pre>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>

      {/* Provision Modal */}
      {showProvisionModal && (
        <div className={styles.modalOverlay}>
          <div className={styles.modalContent}>
            <div className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>Provision New Campus Tenant</h3>
              <button
                onClick={() => {
                  setShowProvisionModal(false);
                  setProvisionSuccess(null);
                }}
                style={{
                  background: "none",
                  border: "none",
                  color: "#64748b",
                  fontSize: "1.5rem",
                  cursor: "pointer",
                }}
              >
                &times;
              </button>
            </div>

            {provisionSuccess ? (
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: "1rem",
                }}
              >
                <div className={styles.alertSuccess}>
                  🎉 School **{provisionSuccess.school.name}** has been
                  successfully provisioned!
                </div>
                <div className={styles.formGroup}>
                  <label className={styles.label}>School Domain Code</label>
                  <input
                    className={styles.input}
                    type="text"
                    readOnly
                    value={provisionSuccess.school.code}
                  />
                </div>
                <div className={styles.formGroup}>
                  <label className={styles.label}>Admin Activation URL</label>
                  <span
                    style={{
                      fontSize: "0.75rem",
                      color: "#64748b",
                      marginBottom: "0.25rem",
                    }}
                  >
                    Provide this link to the School Admin to set up their
                    password.
                  </span>
                  <div className={styles.tokenBox}>
                    {window.location.origin}/api/auth/invite?token=
                    {provisionSuccess.inviteToken}
                  </div>
                </div>
                <div className={styles.modalFooter}>
                  <button
                    className={styles.btn}
                    onClick={() => {
                      setShowProvisionModal(false);
                      setProvisionSuccess(null);
                    }}
                  >
                    Dismiss
                  </button>
                </div>
              </div>
            ) : (
              <form onSubmit={handleProvisionSubmit} className={styles.form}>
                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: "1rem",
                  }}
                >
                  <div className={styles.formGroup}>
                    <label className={styles.label}>School Name *</label>
                    <input
                      className={styles.input}
                      required
                      type="text"
                      value={provisionForm.name}
                      onChange={(e) =>
                        setProvisionForm({
                          ...provisionForm,
                          name: e.target.value,
                        })
                      }
                      placeholder="e.g. Oxford High School"
                    />
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>
                      Unique Code (Alphanumeric) *
                    </label>
                    <input
                      className={styles.input}
                      required
                      type="text"
                      value={provisionForm.code}
                      onChange={(e) =>
                        setProvisionForm({
                          ...provisionForm,
                          code: e.target.value.replace(/[^A-Za-z0-9]/g, ""),
                        })
                      }
                      placeholder="e.g. OXFORD01"
                    />
                  </div>
                </div>

                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: "1rem",
                  }}
                >
                  <div className={styles.formGroup}>
                    <label className={styles.label}>School Contact Email</label>
                    <input
                      className={styles.input}
                      type="email"
                      value={provisionForm.email}
                      onChange={(e) =>
                        setProvisionForm({
                          ...provisionForm,
                          email: e.target.value,
                        })
                      }
                      placeholder="e.g. info@oxford.edu"
                    />
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>School Contact Phone</label>
                    <input
                      className={styles.input}
                      type="text"
                      value={provisionForm.phone}
                      onChange={(e) =>
                        setProvisionForm({
                          ...provisionForm,
                          phone: e.target.value,
                        })
                      }
                      placeholder="e.g. +1234567890"
                    />
                  </div>
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.label}>School Address</label>
                  <input
                    className={styles.input}
                    type="text"
                    value={provisionForm.address}
                    onChange={(e) =>
                      setProvisionForm({
                        ...provisionForm,
                        address: e.target.value,
                      })
                    }
                    placeholder="e.g. 123 Education Way, New York"
                  />
                </div>

                <div
                  style={{ borderTop: "1px solid #1e293b", paddingTop: "1rem" }}
                >
                  <h4 style={{ marginBottom: "1rem", color: "#f8fafc" }}>
                    Campus Academic Calendar
                  </h4>
                  <div
                    className={styles.formGroup}
                    style={{ marginBottom: "1rem" }}
                  >
                    <label className={styles.label}>Calendar Term Name *</label>
                    <input
                      className={styles.input}
                      required
                      type="text"
                      value={provisionForm.academicYearName}
                      onChange={(e) =>
                        setProvisionForm({
                          ...provisionForm,
                          academicYearName: e.target.value,
                        })
                      }
                    />
                  </div>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr",
                      gap: "1rem",
                    }}
                  >
                    <div className={styles.formGroup}>
                      <label className={styles.label}>Term Start Date *</label>
                      <input
                        className={styles.input}
                        required
                        type="date"
                        value={provisionForm.academicYearStartDate}
                        onChange={(e) =>
                          setProvisionForm({
                            ...provisionForm,
                            academicYearStartDate: e.target.value,
                          })
                        }
                      />
                    </div>
                    <div className={styles.formGroup}>
                      <label className={styles.label}>Term End Date *</label>
                      <input
                        className={styles.input}
                        required
                        type="date"
                        value={provisionForm.academicYearEndDate}
                        onChange={(e) =>
                          setProvisionForm({
                            ...provisionForm,
                            academicYearEndDate: e.target.value,
                          })
                        }
                      />
                    </div>
                  </div>
                </div>

                <div
                  style={{ borderTop: "1px solid #1e293b", paddingTop: "1rem" }}
                >
                  <h4 style={{ marginBottom: "1rem", color: "#f8fafc" }}>
                    School Administrator Credentials
                  </h4>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr",
                      gap: "1rem",
                    }}
                  >
                    <div className={styles.formGroup}>
                      <label className={styles.label}>
                        Admin Account Email *
                      </label>
                      <input
                        className={styles.input}
                        required
                        type="email"
                        value={provisionForm.adminEmail}
                        onChange={(e) =>
                          setProvisionForm({
                            ...provisionForm,
                            adminEmail: e.target.value,
                          })
                        }
                        placeholder="e.g. admin@oxford.edu"
                      />
                    </div>
                    <div className={styles.formGroup}>
                      <label className={styles.label}>Admin Mobile Phone</label>
                      <input
                        className={styles.input}
                        type="text"
                        value={provisionForm.adminPhone}
                        onChange={(e) =>
                          setProvisionForm({
                            ...provisionForm,
                            adminPhone: e.target.value,
                          })
                        }
                        placeholder="e.g. +1234567890"
                      />
                    </div>
                  </div>
                </div>

                <div
                  style={{ borderTop: "1px solid #1e293b", paddingTop: "1rem" }}
                >
                  <h4 style={{ marginBottom: "1rem", color: "#f8fafc" }}>
                    Subscription Allocation
                  </h4>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr",
                      gap: "1rem",
                    }}
                  >
                    <div className={styles.formGroup}>
                      <label className={styles.label}>
                        Subscription Plan *
                      </label>
                      <select
                        style={{
                          background: "#0b0f19",
                          border: "1px solid #1e293b",
                          borderRadius: "0.5rem",
                          padding: "0.75rem 1rem",
                          color: "#f8fafc",
                        }}
                        value={provisionForm.subscriptionPlan}
                        onChange={(e) =>
                          setProvisionForm({
                            ...provisionForm,
                            subscriptionPlan: e.target.value,
                          })
                        }
                      >
                        <option value="TRIAL">Trial Plan</option>
                        <option value="BASIC">Basic Plan</option>
                        <option value="PREMIUM">Premium Plan</option>
                      </select>
                    </div>
                    <div className={styles.formGroup}>
                      <label className={styles.label}>Duration (Days) *</label>
                      <input
                        className={styles.input}
                        required
                        type="number"
                        value={provisionForm.subscriptionDurationDays}
                        onChange={(e) =>
                          setProvisionForm({
                            ...provisionForm,
                            subscriptionDurationDays: parseInt(
                              e.target.value,
                              10,
                            ),
                          })
                        }
                      />
                    </div>
                  </div>
                </div>

                <div className={styles.modalFooter}>
                  <button
                    type="button"
                    className={`${styles.btn} ${styles.btnSecondary}`}
                    onClick={() => setShowProvisionModal(false)}
                  >
                    Cancel
                  </button>
                  <button type="submit" className={styles.btn}>
                    Provision Campuses
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* School Details / Config Modal */}
      {selectedSchool && (
        <div className={styles.modalOverlay}>
          <div className={styles.modalContent} style={{ maxWidth: "700px" }}>
            <div className={styles.modalHeader}>
              <div>
                <h3 className={styles.modalTitle}>
                  Configure {selectedSchool.name}
                </h3>
                <span style={{ fontSize: "0.875rem", color: "#64748b" }}>
                  Code: {selectedSchool.code} | Status: {selectedSchool.status}
                </span>
              </div>
              <button
                onClick={() => setSelectedSchool(null)}
                style={{
                  background: "none",
                  border: "none",
                  color: "#64748b",
                  fontSize: "1.5rem",
                  cursor: "pointer",
                }}
              >
                &times;
              </button>
            </div>

            {/* Modal Internal Nav */}
            <nav
              className={styles.navigation}
              style={{ borderBottom: "1px solid #1e293b", margin: 0 }}
            >
              <button
                className={`${styles.navLink} ${configTab === "branding" ? styles.navLinkActive : ""}`}
                onClick={() => setConfigTab("branding")}
                style={{ padding: "0.75rem 0", fontSize: "0.875rem" }}
              >
                School Branding
              </button>
              <button
                className={`${styles.navLink} ${configTab === "features" ? styles.navLinkActive : ""}`}
                onClick={() => setConfigTab("features")}
                style={{ padding: "0.75rem 0", fontSize: "0.875rem" }}
              >
                Feature Allocations
              </button>
              <button
                className={`${styles.navLink} ${configTab === "actions" ? styles.navLinkActive : ""}`}
                onClick={() => setConfigTab("actions")}
                style={{ padding: "0.75rem 0", fontSize: "0.875rem" }}
              >
                Lifecycle Controls
              </button>
            </nav>

            {/* Config: Branding */}
            {configTab === "branding" && (
              <form onSubmit={handleSaveBranding} className={styles.form}>
                <div className={styles.formGroup}>
                  <label className={styles.label}>
                    Application Display Title
                  </label>
                  <input
                    className={styles.input}
                    type="text"
                    value={brandingForm.appName}
                    onChange={(e) =>
                      setBrandingForm({
                        ...brandingForm,
                        appName: e.target.value,
                      })
                    }
                  />
                </div>
                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: "1rem",
                  }}
                >
                  <div className={styles.formGroup}>
                    <label className={styles.label}>Primary Brand Color</label>
                    <div style={{ display: "flex", gap: "0.5rem" }}>
                      <input
                        className={styles.input}
                        type="color"
                        style={{ width: "40px", padding: 0, height: "38px" }}
                        value={brandingForm.primaryColor}
                        onChange={(e) =>
                          setBrandingForm({
                            ...brandingForm,
                            primaryColor: e.target.value,
                          })
                        }
                      />
                      <input
                        className={styles.input}
                        type="text"
                        style={{ flex: 1 }}
                        value={brandingForm.primaryColor}
                        onChange={(e) =>
                          setBrandingForm({
                            ...brandingForm,
                            primaryColor: e.target.value,
                          })
                        }
                      />
                    </div>
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>
                      Secondary Brand Color
                    </label>
                    <div style={{ display: "flex", gap: "0.5rem" }}>
                      <input
                        className={styles.input}
                        type="color"
                        style={{ width: "40px", padding: 0, height: "38px" }}
                        value={brandingForm.secondaryColor}
                        onChange={(e) =>
                          setBrandingForm({
                            ...brandingForm,
                            secondaryColor: e.target.value,
                          })
                        }
                      />
                      <input
                        className={styles.input}
                        type="text"
                        style={{ flex: 1 }}
                        value={brandingForm.secondaryColor}
                        onChange={(e) =>
                          setBrandingForm({
                            ...brandingForm,
                            secondaryColor: e.target.value,
                          })
                        }
                      />
                    </div>
                  </div>
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.label}>Splash Image URL</label>
                  <input
                    className={styles.input}
                    type="text"
                    value={brandingForm.splashImageUrl}
                    onChange={(e) =>
                      setBrandingForm({
                        ...brandingForm,
                        splashImageUrl: e.target.value,
                      })
                    }
                    placeholder="https://example.com/splash.png"
                  />
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.label}>Logo File URL</label>
                  <input
                    className={styles.input}
                    type="text"
                    value={brandingForm.logoUrl}
                    onChange={(e) =>
                      setBrandingForm({
                        ...brandingForm,
                        logoUrl: e.target.value,
                      })
                    }
                    placeholder="https://example.com/logo.png"
                  />
                </div>

                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: "1rem",
                  }}
                >
                  <div className={styles.formGroup}>
                    <label className={styles.label}>
                      Default UI Typography
                    </label>
                    <select
                      style={{
                        background: "#0b0f19",
                        border: "1px solid #1e293b",
                        borderRadius: "0.5rem",
                        padding: "0.75rem 1rem",
                        color: "#f8fafc",
                      }}
                      value={brandingForm.fontFamily}
                      onChange={(e) =>
                        setBrandingForm({
                          ...brandingForm,
                          fontFamily: e.target.value,
                        })
                      }
                    >
                      <option value="Inter">Inter Sans</option>
                      <option value="Outfit">Outfit Pro</option>
                      <option value="Roboto">Roboto Condensed</option>
                    </select>
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>Branded Theme Mode</label>
                    <select
                      style={{
                        background: "#0b0f19",
                        border: "1px solid #1e293b",
                        borderRadius: "0.5rem",
                        padding: "0.75rem 1rem",
                        color: "#f8fafc",
                      }}
                      value={brandingForm.themeMode}
                      onChange={(e) =>
                        setBrandingForm({
                          ...brandingForm,
                          themeMode: e.target.value,
                        })
                      }
                    >
                      <option value="LIGHT">Force Light Theme</option>
                      <option value="DARK">Force Dark Theme</option>
                      <option value="SYSTEM">Adapt System Settings</option>
                    </select>
                  </div>
                </div>

                <div className={styles.modalFooter}>
                  <button
                    type="button"
                    className={`${styles.btn} ${styles.btnSecondary}`}
                    onClick={() => setSelectedSchool(null)}
                  >
                    Close
                  </button>
                  <button type="submit" className={styles.btn}>
                    Save Branding Configurations
                  </button>
                </div>
              </form>
            )}

            {/* Config: Features */}
            {configTab === "features" && (
              <form onSubmit={handleSaveFeatures} className={styles.form}>
                <span
                  style={{
                    fontSize: "0.875rem",
                    color: "#64748b",
                    marginBottom: "1rem",
                    display: "block",
                  }}
                >
                  Toggle active modules for this tenant campus. Disabled modules
                  will block access immediately.
                </span>

                <div className={styles.checkboxGrid}>
                  <label className={styles.checkboxLabel}>
                    <input
                      type="checkbox"
                      style={{ width: "16px", height: "16px" }}
                      checked={featuresForm.attendance}
                      onChange={(e) =>
                        setFeaturesForm({
                          ...featuresForm,
                          attendance: e.target.checked,
                        })
                      }
                    />
                    <span>Attendance Management</span>
                  </label>
                  <label className={styles.checkboxLabel}>
                    <input
                      type="checkbox"
                      style={{ width: "16px", height: "16px" }}
                      checked={featuresForm.homework}
                      onChange={(e) =>
                        setFeaturesForm({
                          ...featuresForm,
                          homework: e.target.checked,
                        })
                      }
                    />
                    <span>Homework Submissions</span>
                  </label>
                  <label className={styles.checkboxLabel}>
                    <input
                      type="checkbox"
                      style={{ width: "16px", height: "16px" }}
                      checked={featuresForm.exams}
                      onChange={(e) =>
                        setFeaturesForm({
                          ...featuresForm,
                          exams: e.target.checked,
                        })
                      }
                    />
                    <span>Exam & Report Cards</span>
                  </label>
                  <label className={styles.checkboxLabel}>
                    <input
                      type="checkbox"
                      style={{ width: "16px", height: "16px" }}
                      checked={featuresForm.notices}
                      onChange={(e) =>
                        setFeaturesForm({
                          ...featuresForm,
                          notices: e.target.checked,
                        })
                      }
                    />
                    <span>Notices & Broadcasts</span>
                  </label>
                  <label className={styles.checkboxLabel}>
                    <input
                      type="checkbox"
                      style={{ width: "16px", height: "16px" }}
                      checked={featuresForm.remarks}
                      onChange={(e) =>
                        setFeaturesForm({
                          ...featuresForm,
                          remarks: e.target.checked,
                        })
                      }
                    />
                    <span>Student Remarks Tracker</span>
                  </label>
                  <label className={styles.checkboxLabel}>
                    <input
                      type="checkbox"
                      style={{ width: "16px", height: "16px" }}
                      checked={featuresForm.timetable}
                      onChange={(e) =>
                        setFeaturesForm({
                          ...featuresForm,
                          timetable: e.target.checked,
                        })
                      }
                    />
                    <span>Weekly Class Timetables</span>
                  </label>
                </div>

                <div className={styles.modalFooter}>
                  <button
                    type="button"
                    className={`${styles.btn} ${styles.btnSecondary}`}
                    onClick={() => setSelectedSchool(null)}
                  >
                    Close
                  </button>
                  <button type="submit" className={styles.btn}>
                    Save Entitlements Config
                  </button>
                </div>
              </form>
            )}

            {/* Config: Actions */}
            {configTab === "actions" && (
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: "1.5rem",
                }}
              >
                <span
                  style={{
                    fontSize: "0.875rem",
                    color: "#94a3b8",
                    lineHeight: "1.5",
                  }}
                >
                  Manage the operational lifecycle status of this partner
                  school. Suspending or deactivating a school blocks all user
                  logins immediately.
                </span>

                <div className={styles.actionsGrid}>
                  <button
                    className={`${styles.btn} ${styles.btnSecondary}`}
                    style={{ background: "#10b981", border: "none" }}
                    onClick={() => handleSchoolAction("activate")}
                    disabled={selectedSchool.status === "ACTIVE"}
                  >
                    Activate Access
                  </button>
                  <button
                    className={`${styles.btn} ${styles.btnSecondary}`}
                    style={{ background: "#f59e0b", border: "none" }}
                    onClick={() => handleSchoolAction("suspend")}
                    disabled={selectedSchool.status === "SUSPENDED"}
                  >
                    Suspend School
                  </button>
                  <button
                    className={`${styles.btn} ${styles.btnDanger}`}
                    onClick={() => handleSchoolAction("deactivate")}
                    disabled={selectedSchool.status === "INACTIVE"}
                  >
                    Deactivate Campus
                  </button>
                </div>

                <div className={styles.modalFooter}>
                  <button
                    className={styles.btn}
                    onClick={() => setSelectedSchool(null)}
                  >
                    Close
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
