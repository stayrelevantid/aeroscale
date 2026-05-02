package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/stayrelevantid/aeroscale/internal/health"
	"github.com/stayrelevantid/aeroscale/internal/pubsub"
)

func main() {
	projectID := os.Getenv("PROJECT_ID")
	subscriptionID := os.Getenv("PUBSUB_SUBSCRIPTION_ID")
	if projectID == "" {
		projectID = "stayrelevantid"
	}
	if subscriptionID == "" {
		subscriptionID = "aeroscale-event-subscription"
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sub, err := pubsub.NewSubscriber(projectID, subscriptionID)
	if err != nil {
		log.Fatalf("failed to create subscriber: %v", err)
	}
	defer sub.Close()

	go func() {
		if err := sub.Receive(ctx); err != nil {
			log.Printf("subscriber stopped: %v", err)
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", health.Handler)

	srv := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	go func() {
		log.Printf("health server listening on :8080")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("health server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	cancel()
	_ = srv.Shutdown(shutdownCtx)
}
