# syntax=docker/dockerfile:1

FROM oven/bun:1-slim AS base
WORKDIR /app

FROM base AS deps
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM deps AS build
COPY . .
RUN bun run build

# --- runtime -----------------------------------------------------------
# `vite preview` (not a plain `node`/`bun` script) is the production
# entrypoint: TanStack Start's preview-server-plugin loads dist/server
# and serves it through Vite, so vite.config.ts + full node_modules
# (including devDependencies like vite/react plugins) must ship too.
FROM base AS runtime
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/src ./src
COPY --from=build /app/scripts ./scripts
COPY package.json vite.config.ts tsconfig.json ./

# SQLite db (./data.db) and local file uploads (./uploads) should be
# bind-mounted at `docker run` so they survive restarts/redeploys, e.g.:
#   docker run -v ./data.db:/app/data.db -v ./uploads:/app/uploads ...
RUN mkdir -p uploads/images
VOLUME ["/app/uploads"]

EXPOSE 3000
CMD ["bun", "--bun", "vite", "preview", "--port", "3000", "--host", "0.0.0.0"]
