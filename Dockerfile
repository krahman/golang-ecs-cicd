# syntax=docker/dockerfile:1
ARG GO_VERSION=1.25
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags='-s -w' -o /out/server ./cmd/api
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]
