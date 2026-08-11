import styles from "./page.module.css";

export default function Home() {
  return (
    <div className={styles.container}>
      <main className={styles.main}>
        <div className={styles.badge}>v1.0.0-alpha</div>
        <h1 className={styles.title}>School ERP API Portal</h1>
        <p className={styles.description}>
          The backend API foundation for the multi-tenant School ERP platform is
          running.
        </p>
        <div className={styles.status}>
          <span className={styles.dot}></span>
          <span className={styles.statusText}>All systems operational</span>
        </div>
      </main>
    </div>
  );
}
