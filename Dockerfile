# syntax=docker/dockerfile:1
# check=error=true

# The production image for Stash. A lab host runs it with Docker, started by a NixOS module in
# patchworklabsorg/infra. See docs/deploy.md for the env vars and the web and worker commands.
#
#   docker build -t stash .
#   docker run -p 3000:3000 --env-file <file> stash                           # web
#   docker run --env-file <file> stash bundle exec good_job start             # worker
#
# The worker runs the capture tools, so the image carries Chromium, git, yt-dlp, gallery-dl,
# ffmpeg and LibreOffice. The web process never runs them.

ARG RUBY_VERSION=4.0.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

LABEL org.opencontainers.image.description="Stash: the Patchwork Labs archive"
LABEL org.opencontainers.image.source="https://github.com/patchworklabsorg/stash"

WORKDIR /rails

# Runtime packages: libpq for pg, jemalloc for memory use, and the capture tools.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libpq5 libyaml-0-2 ca-certificates \
      chromium fonts-liberation fonts-noto-color-emoji fonts-noto-cjk \
      git ffmpeg python3 pipx \
      libreoffice-impress libreoffice-writer libreoffice-calc libreoffice-draw && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# yt-dlp and gallery-dl from PyPI, pinned by pipx into /opt/pipx. yt-dlp's pre-release channel
# gets extractor fixes first.
ENV PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
RUN pipx install --pip-args="--pre" "yt-dlp[default,curl-cffi]" && \
    pipx install "gallery-dl" && \
    pipx inject gallery-dl "requests[socks]"

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    BROWSER_PATH="/usr/bin/chromium"

# The build stage compiles the gems and the assets. None of its build tools reach the final image.
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev pkg-config unzip && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUN_INSTALL=/usr/local/bun
ENV PATH=/usr/local/bun/bin:$PATH
ARG BUN_VERSION=1.3.13
RUN curl -fsSL https://bun.sh/install | bash -s -- "bun-v${BUN_VERSION}"

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# SECRET_KEY_BASE_DUMMY gives a dummy secret, so the assets compile without any of the app's secrets.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && rm -rf node_modules

FROM base

# A non-root user. The app writes to log/, tmp/ and the capture work directories under /tmp.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# The entrypoint migrates the database when the command is the web server.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
