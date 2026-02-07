# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/web-portal .

FROM gcr.io/distroless/base-debian12
WORKDIR /
COPY --from=build /out/web-portal /web-portal
EXPOSE 8081
USER 65532:65532
ENTRYPOINT ["/web-portal"]

