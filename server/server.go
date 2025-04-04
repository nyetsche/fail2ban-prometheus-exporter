package server

import (
	"log"
	"net/http"
	"time"

	"gitlab.com/hctrdev/fail2ban-prometheus-exporter/cfg"
	"gitlab.com/hctrdev/fail2ban-prometheus-exporter/collector/f2b"
	"gitlab.com/hctrdev/fail2ban-prometheus-exporter/collector/textfile"
)

func StartServer(
	appSettings *cfg.AppSettings,
	f2bCollector *f2b.Collector,
	textFileCollector *textfile.Collector,
) chan error {
	http.HandleFunc("/", AuthMiddleware(
		rootHtmlHandler,
		appSettings.AuthProvider,
	))
	http.HandleFunc(metricsPath, AuthMiddleware(
		func(w http.ResponseWriter, r *http.Request) {
			metricHandler(w, r, textFileCollector)
		},
		appSettings.AuthProvider,
	))
	http.HandleFunc("/health",
		func(w http.ResponseWriter, r *http.Request) {
			healthHandler(w, r, f2bCollector)
		},
	)
	log.Printf("metrics available at '%s'", metricsPath)

	svrErr := make(chan error)
	go func() {
		httpServer := &http.Server{
			Addr:              appSettings.MetricsAddress,
			ReadHeaderTimeout: 10 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      10 * time.Second,
			IdleTimeout:       30 * time.Second,
		}
		svrErr <- httpServer.ListenAndServe()
	}()
	log.Print("ready")
	return svrErr
}
