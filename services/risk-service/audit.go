package main

import (
	"database/sql"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

type AuditLog struct {
	ID               int64
	UserID           string
	Action           string
	Resource         string
	RiskScore        int
	Decision         string
	IP               string
	Geo              string
	FailedLoginCount int
	Timestamp        time.Time
}

type AuditLogger struct {
	db *sql.DB
}

func NewAuditLogger(dsn string) (*AuditLogger, error) {
	if dsn == "" {
		return nil, nil
	}

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		db.Close()
		return nil, err
	}

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Hour)

	if err := createAuditTable(db); err != nil {
		db.Close()
		return nil, err
	}

	if appLogger != nil {
		appLogger.Info("audit logger initialized successfully")
	}
	return &AuditLogger{db: db}, nil
}

func createAuditTable(db *sql.DB) error {
	query := `
	CREATE TABLE IF NOT EXISTS audit_logs (
		id BIGINT AUTO_INCREMENT PRIMARY KEY,
		user_id VARCHAR(255) NOT NULL,
		action VARCHAR(100) NOT NULL,
		resource VARCHAR(255) NOT NULL,
		risk_score INT NOT NULL,
		decision VARCHAR(50) NOT NULL,
		ip VARCHAR(45),
		geo VARCHAR(10),
		failed_login_count INT DEFAULT 0,
		timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		INDEX idx_user_id (user_id),
		INDEX idx_timestamp (timestamp),
		INDEX idx_risk_score (risk_score)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	`
	_, err := db.Exec(query)
	return err
}

func (a *AuditLogger) Log(entry AuditLog) error {
	if a == nil || a.db == nil {
		return nil
	}

	query := `
		INSERT INTO audit_logs 
		(user_id, action, resource, risk_score, decision, ip, geo, failed_login_count, timestamp)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := a.db.Exec(query,
		entry.UserID,
		entry.Action,
		entry.Resource,
		entry.RiskScore,
		entry.Decision,
		entry.IP,
		entry.Geo,
		entry.FailedLoginCount,
		entry.Timestamp,
	)

	if err != nil {
		if appLogger != nil {
			appLogger.Error("failed to write audit log: %v", err)
		}
		return err
	}

	return nil
}

func (a *AuditLogger) Close() error {
	if a == nil || a.db == nil {
		return nil
	}
	return a.db.Close()
}

func (a *AuditLogger) GetRecentLogs(limit int) ([]AuditLog, error) {
	if a == nil || a.db == nil {
		return nil, nil
	}

	query := `
		SELECT id, user_id, action, resource, risk_score, decision, 
		       ip, geo, failed_login_count, timestamp
		FROM audit_logs
		ORDER BY timestamp DESC
		LIMIT ?
	`

	rows, err := a.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		err := rows.Scan(
			&log.ID,
			&log.UserID,
			&log.Action,
			&log.Resource,
			&log.RiskScore,
			&log.Decision,
			&log.IP,
			&log.Geo,
			&log.FailedLoginCount,
			&log.Timestamp,
		)
		if err != nil {
			return nil, err
		}
		logs = append(logs, log)
	}

	return logs, rows.Err()
}
