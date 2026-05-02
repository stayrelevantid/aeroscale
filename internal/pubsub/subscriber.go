package pubsub

import (
	"context"
	"encoding/json"
	"log"

	"cloud.google.com/go/pubsub"
)

type Subscriber struct {
	client         *pubsub.Client
	subscriptionID string
}

type Message struct {
	ID      string                 `json:"id"`
	Payload map[string]interface{} `json:"payload"`
}

func NewSubscriber(projectID, subscriptionID string) (*Subscriber, error) {
	client, err := pubsub.NewClient(context.Background(), projectID)
	if err != nil {
		return nil, err
	}
	return &Subscriber{
		client:         client,
		subscriptionID: subscriptionID,
	}, nil
}

func (s *Subscriber) Close() error {
	return s.client.Close()
}

func (s *Subscriber) Receive(ctx context.Context) error {
	sub := s.client.Subscription(s.subscriptionID)

	log.Printf("listening for messages on subscription: %s", s.subscriptionID)

	err := sub.Receive(ctx, func(ctx context.Context, msg *pubsub.Message) {
		var m Message
		if err := json.Unmarshal(msg.Data, &m); err != nil {
			log.Printf("failed to unmarshal message %s: %v", msg.ID, err)
			msg.Nack()
			return
		}

		log.Printf("processing message: id=%s payload=%v", m.ID, m.Payload)
		msg.Ack()
		log.Printf("message processed: id=%s", m.ID)
	})

	return err
}
