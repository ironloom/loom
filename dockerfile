FROM alpine:edge AS aarch64_alpine_builder

RUN apk update
RUN apk add zig

WORKDIR /loom/
COPY . /loom/

WORKDIR /loom/zig-out
WORKDIR /loom/zig-out/final
WORKDIR /loom/

RUN zig build example=cameras -Dtarget=aarch64-macos --release=safe
RUN zig build example=cameras -Dtarget=x86_64-windows --release=safe


FROM --platform=linux/amd64 ubuntu:22.04  AS x86_64_ubuntu_builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl pkgconf ca-certificates \
    libx11-dev libxcursor-dev libxext-dev libxfixes-dev \
    libxi-dev libxinerama-dev libxrandr-dev libxrender-dev \
    libgl1-mesa-dev

WORKDIR /opt/zig
WORKDIR /

RUN curl -L https://ziglang.org/download/0.15.1/zig-x86_64-linux-0.15.1.tar.xz \
    | tar -xJ -C /opt/zig --strip-components=1 \
    && ln -s /opt/zig/zig /usr/local/bin/zig

WORKDIR /loom
COPY . /loom

WORKDIR /loom/zig-out
WORKDIR /loom/zig-out/final
WORKDIR /loom/

RUN rm -rf .zig-cache/
RUN zig build -Dtarget=x86_64-linux-gnu --release=safe --seed 0

FROM scratch AS final

COPY --from=aarch64_alpine_builder /loom/zig-out/bin .
COPY --from=x86_64_ubuntu_builder /loom/zig-out/bin .
