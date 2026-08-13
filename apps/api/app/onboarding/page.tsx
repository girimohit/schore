"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";

function OnboardingContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [brand, setBrand] = useState<{
    name: string;
    branding?: {
      primaryColor?: string;
      secondaryColor?: string;
      logoUrl?: string;
    };
  } | null>(null);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState("");

  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    if (!token) {
      setErrorMsg("Missing invitation token. Please check your link.");
      setLoading(false);
      return;
    }

    // Validate invitation token
    fetch(`/api/auth/invite/validate?token=${token}`)
      .then((res) => res.json())
      .then((data) => {
        if (!data.success) {
          setErrorMsg(data.message || "Invitation token is invalid or has expired.");
        } else {
          setEmail(data.data.email);
          setRole(data.data.role);
          setBrand(data.data.school);
        }
      })
      .catch(() => {
        setErrorMsg("Failed to connect to school verification servers.");
      })
      .finally(() => {
        setLoading(false);
      });
  }, [token]);

  // Simple password strength calculation
  const getPasswordStrength = (pass: string) => {
    if (!pass) return { score: 0, text: "None", color: "#ddd" };
    let score = 0;
    if (pass.length >= 6) score += 1;
    if (/[A-Z]/.test(pass)) score += 1;
    if (/[a-z]/.test(pass)) score += 1;
    if (/[0-9]/.test(pass)) score += 1;
    if (/[^A-Za-z0-9]/.test(pass)) score += 1;

    if (score <= 2) return { score, text: "Weak", color: "#f44336" };
    if (score <= 4) return { score, text: "Fair", color: "#ff9800" };
    return { score, text: "Strong", color: "#4caf50" };
  };

  const strength = getPasswordStrength(password);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError(null);

    if (password.length < 6) {
      setPasswordError("Password must be at least 6 characters long.");
      return;
    }

    if (password !== confirmPassword) {
      setPasswordError("Passwords do not match.");
      return;
    }

    if (strength.text === "Weak") {
      setPasswordError("Please choose a stronger password.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/auth/invite/accept", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, password }),
      });
      const data = await res.json();
      if (!data.success) {
        setPasswordError(data.message || "Failed to accept invitation.");
      } else {
        setSuccess(true);
      }
    } catch {
      setPasswordError("Network error. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  // Branding colors
  const primaryColor = brand?.branding?.primaryColor || "#6366f1";
  const schoolName = brand?.name || "Schore Portal";

  if (loading) {
    return (
      <div style={styles.container}>
        <div style={styles.spinner}></div>
        <p style={styles.loadingText}>Verifying your invitation credentials...</p>
      </div>
    );
  }

  if (errorMsg) {
    return (
      <div style={styles.container}>
        <div style={styles.card}>
          <div style={{ ...styles.avatar, backgroundColor: "#fee2e2" }}>
            <svg style={{ width: 32, height: 32, color: "#ef4444" }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <h2 style={styles.title}>Verification Failed</h2>
          <p style={styles.errorText}>{errorMsg}</p>
          <div style={{ marginTop: 24, fontSize: 13, color: "#666" }}>
            Please contact your school administrator to request a new onboarding invitation link.
          </div>
        </div>
      </div>
    );
  }

  if (success) {
    return (
      <div style={styles.container}>
        <div style={styles.card}>
          <div style={{ ...styles.avatar, backgroundColor: "#d1fae5" }}>
            <svg style={{ width: 32, height: 32, color: "#10b981" }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h2 style={styles.title}>Account Activated!</h2>
          <p style={styles.successText}>
            Welcome to <strong>{schoolName}</strong>! Your password has been successfully configured.
          </p>
          <div style={styles.infoBox}>
            <h4 style={{ margin: "0 0 8px 0", color: "#1e293b" }}>Next Steps:</h4>
            <ol style={{ margin: 0, paddingLeft: 20, color: "#475569", lineHeight: 1.5 }}>
              <li>Open the <strong>SCHORE ERP</strong> app on your mobile device.</li>
              <li>Log in using your email: <strong>{email}</strong></li>
              <li>Enter the password you just configured.</li>
            </ol>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        {brand?.branding?.logoUrl ? (
          <img src={brand.branding.logoUrl} alt="Logo" style={styles.logo} />
        ) : (
          <div style={{ ...styles.avatar, backgroundColor: `${primaryColor}22` }}>
            <span style={{ fontSize: 24, fontWeight: "bold", color: primaryColor }}>
              {schoolName.substring(0, 2).toUpperCase()}
            </span>
          </div>
        )}

        <h2 style={styles.title}>Setup Your Account</h2>
        <p style={styles.subtitle}>
          Set up credentials to access the <strong>{schoolName}</strong> portal.
        </p>

        <div style={styles.badgeRow}>
          <span style={styles.badge}>Email: {email}</span>
          <span style={styles.badge}>Role: {role}</span>
        </div>

        <form onSubmit={handleSubmit} style={styles.form}>
          <div style={styles.inputGroup}>
            <label style={styles.label}>Choose Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Minimum 6 characters"
              style={styles.input}
              required
              disabled={submitting}
            />
          </div>

          <div style={styles.strengthWrapper}>
            <div style={styles.strengthBarContainer}>
              <div
                style={{
                  ...styles.strengthBar,
                  width: `${(strength.score / 5) * 100}%`,
                  backgroundColor: strength.color,
                }}
              />
            </div>
            <span style={{ ...styles.strengthText, color: strength.score > 0 ? strength.color : "#94a3b8" }}>
              Strength: {strength.text}
            </span>
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>Confirm Password</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Re-enter password"
              style={styles.input}
              required
              disabled={submitting}
            />
          </div>

          {passwordError && <p style={styles.errorMessage}>{passwordError}</p>}

          <button
            type="submit"
            style={{
              ...styles.button,
              backgroundColor: submitting ? "#94a3b8" : primaryColor,
            }}
            disabled={submitting}
          >
            {submitting ? "Saving Config..." : "Activate Account & Onboard"}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function OnboardingPage() {
  return (
    <Suspense fallback={
      <div style={styles.container}>
        <div style={styles.spinner}></div>
        <p style={styles.loadingText}>Loading Onboarding page...</p>
      </div>
    }>
      <OnboardingContent />
    </Suspense>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    minHeight: "100vh",
    backgroundColor: "#f8fafc",
    fontFamily: "Inter, system-ui, -apple-system, sans-serif",
    padding: "20px",
  },
  card: {
    backgroundColor: "#ffffff",
    borderRadius: "16px",
    boxShadow: "0 10px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.05)",
    padding: "40px 30px",
    width: "100%",
    maxWidth: "460px",
    textAlign: "center",
  },
  logo: {
    maxHeight: "60px",
    marginBottom: "16px",
  },
  avatar: {
    width: "64px",
    height: "64px",
    borderRadius: "50%",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    margin: "0 auto 20px auto",
  },
  title: {
    fontSize: "22px",
    fontWeight: "bold",
    color: "#0f172a",
    margin: "0 0 8px 0",
  },
  subtitle: {
    fontSize: "14px",
    color: "#64748b",
    margin: "0 0 20px 0",
    lineHeight: "1.5",
  },
  badgeRow: {
    display: "flex",
    justifyContent: "center",
    gap: "8px",
    flexWrap: "wrap",
    marginBottom: "24px",
  },
  badge: {
    fontSize: "12px",
    fontWeight: "600",
    backgroundColor: "#f1f5f9",
    color: "#475569",
    padding: "4px 10px",
    borderRadius: "20px",
  },
  form: {
    textAlign: "left",
  },
  inputGroup: {
    marginBottom: "20px",
  },
  label: {
    display: "block",
    fontSize: "13px",
    fontWeight: "600",
    color: "#334155",
    marginBottom: "6px",
  },
  input: {
    width: "100%",
    padding: "10px 14px",
    fontSize: "14px",
    border: "1px solid #cbd5e1",
    borderRadius: "8px",
    boxSizing: "border-box",
    transition: "border-color 0.2s",
    outline: "none",
  },
  strengthWrapper: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: "-12px",
    marginBottom: "16px",
  },
  strengthBarContainer: {
    height: "5px",
    width: "65%",
    backgroundColor: "#f1f5f9",
    borderRadius: "10px",
    overflow: "hidden",
  },
  strengthBar: {
    height: "100%",
    borderRadius: "10px",
    transition: "width 0.3s ease",
  },
  strengthText: {
    fontSize: "11px",
    fontWeight: "bold",
  },
  button: {
    width: "100%",
    color: "#ffffff",
    border: "none",
    padding: "12px",
    fontSize: "14px",
    fontWeight: "bold",
    borderRadius: "8px",
    cursor: "pointer",
    transition: "opacity 0.2s",
    marginTop: "10px",
  },
  spinner: {
    width: "40px",
    height: "40px",
    border: "4px solid #f3f3f3",
    borderTop: "4px solid #6366f1",
    borderRadius: "50%",
    animation: "spin 1s linear infinite",
    marginBottom: "16px",
  },
  loadingText: {
    color: "#475569",
    fontSize: "14px",
  },
  errorText: {
    color: "#ef4444",
    fontSize: "14px",
    lineHeight: "1.5",
    margin: "12px 0 0 0",
  },
  successText: {
    color: "#0f172a",
    fontSize: "15px",
    lineHeight: "1.5",
    margin: "12px 0 20px 0",
  },
  infoBox: {
    backgroundColor: "#f8fafc",
    border: "1px solid #e2e8f0",
    borderRadius: "12px",
    padding: "20px",
    textAlign: "left",
  },
  errorMessage: {
    color: "#ef4444",
    fontSize: "13px",
    marginTop: "-12px",
    marginBottom: "16px",
    fontWeight: "500",
  },
};
