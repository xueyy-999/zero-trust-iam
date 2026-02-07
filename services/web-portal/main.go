package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"embed"
	"encoding/base64"
	"encoding/json"
	"errors"
	"html/template"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	github_oidc "github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

//go:embed templates/*
var templatesFS embed.FS

var tpl *template.Template

// Config from env
var (
	riskServiceURL string
	opaURL         string

	httpClient = &http.Client{Timeout: 5 * time.Second}

	// OIDC (Keycloak)
	oidcIssuer       string
	oidcClientID     string
	oidcClientSecret string
	oidcRedirectURL  string

	oidcEnabled  bool
	oauth2Config *oauth2.Config
	oidcVerifier *github_oidc.IDTokenVerifier

	sessionsMu sync.Mutex
	sessions   map[string]*sessionData
	statesMu   sync.Mutex
	states     map[string]time.Time
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
type sessionData struct {
	Sub   string
	Name  string
	Email string
}

func main() {
	var err error
	tpl, err = template.ParseFS(templatesFS, "templates/index.html", "templates/result.html")
	if err != nil {
		log.Fatalf("parse templates: %v", err)

	}

	riskServiceURL = os.Getenv("RISK_SERVICE_URL")
	if riskServiceURL == "" {
		riskServiceURL = "http://localhost:8080/score"
	}
	opaURL = os.Getenv("OPA_URL")
	if opaURL == "" {
		opaURL = "http://localhost:8181"

	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}
	if _, err := strconv.Atoi(port); err != nil {
		port = "8081"
	}

	// OIDC init (optional)
	oidcIssuer = os.Getenv("OIDC_ISSUER")
	oidcClientID = os.Getenv("OIDC_CLIENT_ID")
	oidcClientSecret = os.Getenv("OIDC_CLIENT_SECRET")
	oidcRedirectURL = os.Getenv("OIDC_REDIRECT_URL")
	if oidcIssuer != "" && oidcClientID != "" && oidcRedirectURL != "" {
		ctx := context.Background()
		provider, err := github_oidc.NewProvider(ctx, oidcIssuer)
		if err != nil {
			log.Printf("OIDC disabled: init provider failed: %v", err)
		} else {
			oauth2Config = &oauth2.Config{
				ClientID:     oidcClientID,
				ClientSecret: oidcClientSecret,
				Endpoint:     provider.Endpoint(),
				RedirectURL:  oidcRedirectURL,
				Scopes:       []string{github_oidc.ScopeOpenID, "profile", "email"},
			}
			oidcVerifier = provider.Verifier(&github_oidc.Config{ClientID: oidcClientID})
			oidcEnabled = true
			sessions = make(map[string]*sessionData)
			states = make(map[string]time.Time)
			// Start cleanup goroutine to prevent memory leaks
			go cleanupExpiredStates()
			log.Printf("OIDC enabled: issuer=%s client_id=%s redirect=%s", oidcIssuer, oidcClientID, oidcRedirectURL)
		}
	} else {
		log.Printf("OIDC disabled: missing envs OIDC_ISSUER/CLIENT_ID/REDIRECT_URL")
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/check", checkHandler)
	// OIDC routes
	http.HandleFunc("/login", loginHandler)
	http.HandleFunc("/callback", callbackHandler)
	http.HandleFunc("/logout", logoutHandler)

	addr := ":" + port
	log.Printf("web-portal listening on %s (risk=%s, opa=%s)", addr, riskServiceURL, opaURL)
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

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	ses := getSession(r)
	data := map[string]any{
		"Now":      time.Now().UTC().Format(time.RFC3339),
		"RiskURL":  riskServiceURL,
		"OPAURL":   opaURL,
		"OIDC":     oidcEnabled,
		"LoggedIn": ses != nil,
	}
	if ses != nil {
		data["User"] = *ses
	}
	_ = tpl.ExecuteTemplate(w, "index.html", data)
}

func checkHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	if err := r.ParseForm(); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("invalid form"))
		return
	}
	rolesStr := strings.TrimSpace(r.FormValue("roles"))
	var roles []string
	if rolesStr != "" {
		for _, p := range strings.Split(rolesStr, ",") {
			p = strings.TrimSpace(p)
			if p != "" {
				roles = append(roles, p)
			}
		}
	}
	failedCount, _ := strconv.Atoi(strings.TrimSpace(r.FormValue("failedLoginCount")))
	timeISO := strings.TrimSpace(r.FormValue("time"))
	if timeISO == "" {
		timeISO = time.Now().UTC().Format(time.RFC3339)
	}
	req := ScoreRequest{
		UserID:           strings.TrimSpace(r.FormValue("userId")),
		Roles:            roles,
		Resource:         strings.TrimSpace(r.FormValue("resource")),
		Action:           strings.TrimSpace(r.FormValue("action")),
		IP:               strings.TrimSpace(r.FormValue("ip")),
		UserAgent:        strings.TrimSpace(r.FormValue("userAgent")),
		Geo:              strings.TrimSpace(r.FormValue("geo")),
		TimeISO:          timeISO,
		FailedLoginCount: failedCount,
	}

	scoreResp, err := callRiskService(req)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		_, _ = w.Write([]byte("risk service error: " + err.Error()))
		return
	}

	allow, opaErr := callOPA(req, scoreResp.Score)
	ses := getSession(r)
	data := map[string]any{
		"Req":      req,
		"Score":    scoreResp.Score,
		"Reasons":  scoreResp.Reasons,
		"Allow":    allow,
		"OPAErr":   opaErr,
		"OIDC":     oidcEnabled,
		"LoggedIn": ses != nil,
	}
	if ses != nil {
		data["User"] = *ses
	}
	_ = tpl.ExecuteTemplate(w, "result.html", data)
}

func callRiskService(req ScoreRequest) (*ScoreResponse, error) {
	b, _ := json.Marshal(req)
	hreq, err := http.NewRequestWithContext(context.Background(), http.MethodPost, riskServiceURL, bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	hreq.Header.Set("Content-Type", "application/json")
	resp, err := httpClient.Do(hreq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, errors.New(fmtErrorStatus("risk-service", resp.StatusCode))
	}
	var out ScoreResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}

type opaQuery struct {
	Input any `json:"input"`
}

type opaResult struct {
	Result bool `json:"result"`
}

func callOPA(req ScoreRequest, score int) (bool, string) {
	input := map[string]any{
		"roles":    req.Roles,
		"resource": req.Resource,
		"action":   req.Action,
		"score":    score,
	}
	b, _ := json.Marshal(opaQuery{Input: input})
	hreq, err := http.NewRequestWithContext(context.Background(), http.MethodPost, opaURL+"/v1/data/authz/allow", bytes.NewReader(b))
	if err != nil {
		return false, err.Error()
	}
	hreq.Header.Set("Content-Type", "application/json")
	resp, err := httpClient.Do(hreq)
	if err != nil {
		return false, err.Error()
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, fmtErrorStatus("opa", resp.StatusCode)
	}
	var out opaResult
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return false, err.Error()
	}
	return out.Result, ""
}

func fmtErrorStatus(svc string, code int) string {
	return svc + " responded with status " + strconv.Itoa(code)
}

// --- OIDC helpers and handlers ---
func randToken() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func getSession(r *http.Request) *sessionData {
	c, err := r.Cookie("sid")
	if err != nil || c.Value == "" {
		return nil
	}
	sessionsMu.Lock()
	defer sessionsMu.Unlock()
	sd, ok := sessions[c.Value]
	if !ok {
		return nil
	}
	return sd
}

func setSession(w http.ResponseWriter, sd *sessionData) {
	sid := randToken()
	sessionsMu.Lock()
	sessions[sid] = sd
	sessionsMu.Unlock()
	http.SetCookie(w, &http.Cookie{
		Name:     "sid",
		Value:    sid,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Now().Add(8 * time.Hour),
	})
}

func clearSession(w http.ResponseWriter, r *http.Request) {
	c, err := r.Cookie("sid")
	if err == nil && c.Value != "" {
		sessionsMu.Lock()
		delete(sessions, c.Value)
		sessionsMu.Unlock()
	}
	http.SetCookie(w, &http.Cookie{
		Name:    "sid",
		Value:   "",
		Path:    "/",
		MaxAge:  -1,
		Expires: time.Unix(0, 0),
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if !oidcEnabled {
		http.NotFound(w, r)
		return
	}
	state := randToken()
	statesMu.Lock()
	states[state] = time.Now().Add(5 * time.Minute)
	statesMu.Unlock()
	url := oauth2Config.AuthCodeURL(state)
	http.Redirect(w, r, url, http.StatusFound)
}

func callbackHandler(w http.ResponseWriter, r *http.Request) {
	if !oidcEnabled {
		http.NotFound(w, r)
		return
	}
	state := r.URL.Query().Get("state")
	code := r.URL.Query().Get("code")
	if state == "" || code == "" {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("missing state or code"))
		return
	}
	statesMu.Lock()
	exp, ok := states[state]
	delete(states, state)
	statesMu.Unlock()
	if !ok || time.Now().After(exp) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("invalid state"))
		return
	}
	ctx := context.Background()
	tok, err := oauth2Config.Exchange(ctx, code)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("token exchange failed: " + err.Error()))
		return
	}
	rawID, _ := tok.Extra("id_token").(string)
	if rawID == "" {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("no id_token in token response"))
		return
	}
	idTok, err := oidcVerifier.Verify(ctx, rawID)
	if err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte("verify id_token failed: " + err.Error()))
		return
	}
	var c struct {
		Sub   string `json:"sub"`
		Email string `json:"email"`
		Name  string `json:"name"`
	}
	_ = idTok.Claims(&c)
	setSession(w, &sessionData{Sub: c.Sub, Name: c.Name, Email: c.Email})
	http.Redirect(w, r, "/", http.StatusFound)
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {
	clearSession(w, r)
	http.Redirect(w, r, "/", http.StatusFound)
}

// cleanupExpiredStates periodically removes expired state tokens to prevent memory leaks
func cleanupExpiredStates() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		now := time.Now()
		statesMu.Lock()
		for state, expiry := range states {
			if now.After(expiry) {
				delete(states, state)
			}
		}
		statesMu.Unlock()
	}
}
