# Build stage
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code (all packages)
COPY main.go ./
COPY types/ ./types/
COPY github/ ./github/
COPY layout/ ./layout/
COPY generator/ ./generator/
COPY handler/ ./handler/
COPY utils/ ./utils/
COPY config/ ./config/

# Build the binary for target platform
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o plugin-server main.go

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates git openssh-client

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/plugin-server .

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1

CMD ["./plugin-server"]

