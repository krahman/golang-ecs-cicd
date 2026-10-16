package main

import (
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/livez", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("hello from EKS")) })
	s := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Println("listening on :8080")
	if err := s.ListenAndServe(); err != nil {
		log.Println(err)
		os.Exit(1)
	}
}
