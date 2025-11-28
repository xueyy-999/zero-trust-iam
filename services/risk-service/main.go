package main

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
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
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	// Limit body to 1MB
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)

	ct := r.Header.Get("Content-Type")
	if ct != "" && !strings.HasPrefix(ct, "application/json") {
		w.WriteHeader(http.StatusUnsupportedMediaType)
		_, _ = w.Write([]byte("unsupported content type"))
		return
	}

	var req ScoreRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("invalid json"))
		return
	}

	score, reasons := computeScore(req)

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

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if _, err := strconv.Atoi(port); err != nil {
		port = "8080"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/score", scoreHandler)
	addr := "0.0.0.0:" + port
	log.Printf("risk-service listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
