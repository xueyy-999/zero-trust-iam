package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestComputeScore(t *testing.T) {
	tests := []struct {
		name          string
		req           ScoreRequest
		expectedScore int
		expectedLen   int
	}{
		{
			name: "low risk - normal access",
			req: ScoreRequest{
				UserID:           "user1",
				Roles:            []string{"user"},
				Resource:         "orders",
				Action:           "read",
				IP:               "192.168.1.1",
				UserAgent:        "Mozilla/5.0",
				Geo:              "CN",
				TimeISO:          "2024-01-15T14:00:00Z",
				FailedLoginCount: 0,
			},
			expectedScore: 0,
			expectedLen:   0,
		},
		{
			name: "medium risk - geo anomaly",
			req: ScoreRequest{
				UserID:           "user1",
				Roles:            []string{"user"},
				Resource:         "orders",
				Action:           "read",
				IP:               "1.2.3.4",
				UserAgent:        "Mozilla/5.0",
				Geo:              "US",
				TimeISO:          "2024-01-15T14:00:00Z",
				FailedLoginCount: 0,
			},
			expectedScore: 20,
			expectedLen:   1,
		},
		{
			name: "high risk - multiple factors",
			req: ScoreRequest{
				UserID:           "admin1",
				Roles:            []string{"admin"},
				Resource:         "users",
				Action:           "admin",
				IP:               "1.2.3.4",
				UserAgent:        "",
				Geo:              "US",
				TimeISO:          "2024-01-15T23:00:00Z",
				FailedLoginCount: 5,
			},
			expectedScore: 100,
			expectedLen:   5,
		},
		{
			name: "failed logins",
			req: ScoreRequest{
				UserID:           "user1",
				Roles:            []string{"user"},
				Resource:         "orders",
				Action:           "read",
				IP:               "192.168.1.1",
				UserAgent:        "Mozilla/5.0",
				Geo:              "CN",
				TimeISO:          "2024-01-15T14:00:00Z",
				FailedLoginCount: 4,
			},
			expectedScore: 40,
			expectedLen:   1,
		},
		{
			name: "night time access",
			req: ScoreRequest{
				UserID:           "user1",
				Roles:            []string{"user"},
				Resource:         "orders",
				Action:           "read",
				IP:               "192.168.1.1",
				UserAgent:        "Mozilla/5.0",
				Geo:              "CN",
				TimeISO:          "2024-01-15T03:00:00Z",
				FailedLoginCount: 0,
			},
			expectedScore: 10,
			expectedLen:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			score, reasons := computeScore(tt.req)
			if score != tt.expectedScore {
				t.Errorf("expected score %d, got %d", tt.expectedScore, score)
			}
			if len(reasons) != tt.expectedLen {
				t.Errorf("expected %d reasons, got %d: %v", tt.expectedLen, len(reasons), reasons)
			}
		})
	}
}

func TestScoreHandler(t *testing.T) {
	tests := []struct {
		name           string
		method         string
		contentType    string
		body           interface{}
		expectedStatus int
	}{
		{
			name:        "valid request",
			method:      http.MethodPost,
			contentType: "application/json",
			body: ScoreRequest{
				UserID:           "user1",
				Roles:            []string{"user"},
				Resource:         "orders",
				Action:           "read",
				IP:               "192.168.1.1",
				UserAgent:        "Mozilla/5.0",
				Geo:              "CN",
				TimeISO:          time.Now().UTC().Format(time.RFC3339),
				FailedLoginCount: 0,
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:           "invalid method",
			method:         http.MethodGet,
			contentType:    "application/json",
			body:           nil,
			expectedStatus: http.StatusMethodNotAllowed,
		},
		{
			name:           "invalid content type",
			method:         http.MethodPost,
			contentType:    "text/plain",
			body:           "invalid",
			expectedStatus: http.StatusUnsupportedMediaType,
		},
		{
			name:           "invalid json",
			method:         http.MethodPost,
			contentType:    "application/json",
			body:           "invalid json",
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var body []byte
			if tt.body != nil {
				if str, ok := tt.body.(string); ok {
					body = []byte(str)
				} else {
					body, _ = json.Marshal(tt.body)
				}
			}

			req := httptest.NewRequest(tt.method, "/score", bytes.NewReader(body))
			if tt.contentType != "" {
				req.Header.Set("Content-Type", tt.contentType)
			}

			w := httptest.NewRecorder()
			scoreHandler(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, w.Code)
			}

			if tt.expectedStatus == http.StatusOK {
				var resp ScoreResponse
				if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
					t.Errorf("failed to decode response: %v", err)
				}
				if resp.Score < 0 || resp.Score > 100 {
					t.Errorf("score out of range: %d", resp.Score)
				}
			}
		})
	}
}

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	healthHandler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	if w.Body.String() != "ok" {
		t.Errorf("expected body 'ok', got '%s'", w.Body.String())
	}
}

func TestMetricsHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	w := httptest.NewRecorder()

	metricsHandler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	var metrics map[string]int64
	if err := json.NewDecoder(w.Body).Decode(&metrics); err != nil {
		t.Errorf("failed to decode metrics: %v", err)
	}

	expectedKeys := []string{
		"total_requests",
		"success_requests",
		"failed_requests",
		"high_risk_count",
		"medium_risk_count",
		"low_risk_count",
	}

	for _, key := range expectedKeys {
		if _, ok := metrics[key]; !ok {
			t.Errorf("missing metric key: %s", key)
		}
	}
}

func TestContains(t *testing.T) {
	tests := []struct {
		name     string
		arr      []string
		value    string
		expected bool
	}{
		{"found", []string{"a", "b", "c"}, "b", true},
		{"not found", []string{"a", "b", "c"}, "d", false},
		{"empty array", []string{}, "a", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := contains(tt.arr, tt.value)
			if result != tt.expected {
				t.Errorf("expected %v, got %v", tt.expected, result)
			}
		})
	}
}
