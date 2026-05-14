FROM golang:1.22-alpine AS builder

WORKDIR /src

# go.mod / go.sum 同梱前提 (デモ用のためコメントアウト可)
COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/payment-api ./cmd/payment-api

FROM gcr.io/distroless/static-debian12:nonroot
USER nonroot:nonroot
COPY --from=builder /out/payment-api /payment-api
EXPOSE 8080
ENTRYPOINT ["/payment-api"]
