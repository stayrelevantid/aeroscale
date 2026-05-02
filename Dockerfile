FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /worker ./cmd/worker

FROM alpine:3.19

RUN adduser -D -u 1000 appuser

COPY --from=builder /worker /home/appuser/worker

USER appuser

ENTRYPOINT ["/home/appuser/worker"]