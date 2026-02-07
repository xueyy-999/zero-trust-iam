package main

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

type ScoreRequest struct {
	UserID           string   `json:"userId"`
	Roles            []string `json:"roles"`
	Resource         string   `json:"resource"`
	Action           string   `json:"action"`
	IP               string   `json:"ip"`
	UserAgent        string   `json:"userAgent"`
	Geo              string   `json:"geo"`
	TimeISO          string   `json:"time"`
	FailedLoginCount int      `json:"failedLoginCount"`
}

type ScoreResponse struct {
	Score   int      `json:"score"`
	Reasons []string `json:"reasons"`
}

type Metrics struct {
	TotalRequests   int64
	SuccessRequests int64
	FailedRequests  int64
	HighRiskCount   int64
	MediumRiskCount int64
	LowRiskCount    int64
}

var (
	auditLogger *AuditLogger
	metrics     Metrics
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func computeScore(req ScoreRequest) (int, []string) {
	reasons := make([]string, 0, 8)
	score := 0

	// Simple rules
	if req.FailedLoginCount > 3 {
		score += min(20+req.FailedLoginCount*5, 40)
		reasons = append(reasons, "many_failed_logins")
	}
	if req.Geo != "CN" && req.Geo != "" {
		score += 20
		reasons = append(reasons, "geo_anomaly")
	}
	if req.Action == "admin" || contains(req.Roles, "admin") {
		score += 20
		reasons = append(reasons, "privileged_action")
	}
	if req.UserAgent == "" {
		score += 10
		reasons = append(reasons, "missing_ua")
	}
	// Night time heuristic (22:00-06:00)
	if t, err := time.Parse(time.RFC3339, req.TimeISO); err == nil {
		hour := t.UTC().Hour()
		if hour >= 22 || hour < 6 {
			score += 10
			reasons = append(reasons, "night_time")
		}
	}

	// normalize [0,100]
	score = max(0, min(100, int(math.Round(float64(score)))))
	return score, reasons
}

func scoreHandler(w http.ResponseWriter, r *http.Request) {
	atomic.AddInt64(&metrics.TotalRequests, 1)

	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		atomic.AddInt64(&metrics.FailedRequests, 1)
		return
	}

	// Limit body to 1MB
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)

	ct := r.Header.Get("Content-Type")
	if ct != "" && !strings.HasPrefix(ct, "application/json") {
		w.WriteHeader(http.StatusUnsupportedMediaType)
		_, _ = w.Write([]byte("unsupported content type"))
		atomic.AddInt64(&metrics.FailedRequests, 1)
		return
	}

	var req ScoreRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("invalid json"))
		atomic.AddInt64(&metrics.FailedRequests, 1)
		return
	}

	score, reasons := computeScore(req)

	// Update metrics based on risk level
	if score >= 70 {
		atomic.AddInt64(&metrics.HighRiskCount, 1)
	} else if score >= 40 {
		atomic.AddInt64(&metrics.MediumRiskCount, 1)
	} else {
		atomic.AddInt64(&metrics.LowRiskCount, 1)
	}

	// Log to audit if enabled
	if auditLogger != nil {
		go func() {
			decision := "allow"
			if score >= 70 {
				decision = "deny"
			}
			_ = auditLogger.Log(AuditLog{
				UserID:           req.UserID,
				Action:           req.Action,
				Resource:         req.Resource,
				RiskScore:        score,
				Decision:         decision,
				IP:               req.IP,
				Geo:              req.Geo,
				FailedLoginCount: req.FailedLoginCount,
				Timestamp:        time.Now(),
			})
		}()
	}

	atomic.AddInt64(&metrics.SuccessRequests, 1)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ScoreResponse{Score: score, Reasons: reasons})
}

func contains(arr []string, v string) bool {
	for _, x := range arr {
		if x == v {
			return true
		}
	}
	return false
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int64{
		"total_requests":    atomic.LoadInt64(&metrics.TotalRequests),
		"success_requests":  atomic.LoadInt64(&metrics.SuccessRequests),
		"failed_requests":   atomic.LoadInt64(&metrics.FailedRequests),
		"high_risk_count":   atomic.LoadInt64(&metrics.HighRiskCount),
		"medium_risk_count": atomic.LoadInt64(&metrics.MediumRiskCount),
		"low_risk_count":    atomic.LoadInt64(&metrics.LowRiskCount),
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if _, err := strconv.Atoi(port); err != nil {
		port = "8080"
	}

	// Initialize audit logger if MySQL DSN is provided
	dsn := os.Getenv("MYSQL_DSN")
	if dsn != "" {
		var err error
		auditLogger, err = NewAuditLogger(dsn)
		if err != nil {
			log.Printf("WARNING: failed to initialize audit logger: %v", err)
		} else {
			defer auditLogger.Close()
			log.Println("audit logging enabled")
		}
	} else {
		log.Println("audit logging disabled (no MYSQL_DSN)")
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/score", scoreHandler)
	http.HandleFunc("/metrics", metricsHandler)
	addr := "0.0.0.0:" + port
	log.Printf("risk-service listening on %s", addr)
	srv := &http.Server{
		Addr:              addr,
		Handler:           nil,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
