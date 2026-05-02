package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"cloud.google.com/go/pubsub"
	"context"
)

func main() {
	projectID := flag.String("project", "stayrelevantid", "GCP Project ID")
	topicID := flag.String("topic", "aeroscale-event-queue", "Pub/Sub Topic ID")
	count := flag.Int("count", 500, "Number of messages to publish")
	batch := flag.Int("batch", 10, "Batch size for concurrent publishing")
	delay := flag.Duration("delay", 10*time.Millisecond, "Delay between message sends")
	flag.Parse()

	ctx := context.Background()
	client, err := pubsub.NewClient(ctx, *projectID)
	if err != nil {
		log.Fatalf("failed to create pubsub client: %v", err)
	}
	defer client.Close()

	topic := client.Topic(*topicID)
	defer topic.Stop()

	var published int64
	var failed int64

	start := time.Now()

	fmt.Printf("publishing %d messages to topic %s (project: %s, batch: %d, delay: %s)\n",
		*count, *topicID, *projectID, *batch, *delay)

	var wg sync.WaitGroup

	for i := 0; i < *count; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()

			payload := fmt.Sprintf(`{"id":"msg-%04d","payload":{"action":"process","index":%d,"timestamp":%d}}`,
				idx, idx, time.Now().UnixMilli())

			msg := &pubsub.Message{
				Data: []byte(payload),
			}

			_, err := topic.Publish(ctx, msg).Get(ctx)
			if err != nil {
				atomic.AddInt64(&failed, 1)
				fmt.Fprintf(os.Stderr, "failed to publish msg-%04d: %v\n", idx, err)
			} else {
				n := atomic.AddInt64(&published, 1)
				if n%50 == 0 {
					fmt.Printf("published %d/%d messages...\n", n, int64(*count))
				}
			}
		}(i)

		if *delay > 0 && (i+1)%*batch == 0 {
			time.Sleep(*delay)
		}
	}

	wg.Wait()

	elapsed := time.Since(start)
	fmt.Printf("\ndone! published: %d, failed: %d, total: %d, elapsed: %s\n",
		atomic.LoadInt64(&published), atomic.LoadInt64(&failed), int64(*count), elapsed.Round(time.Millisecond))
}
