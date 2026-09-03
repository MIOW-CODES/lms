# ── Build stage ──────────────────────────────────────────────────────
FROM oven/bun:1 AS build
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .
RUN bun run build

# ── Production stage ────────────────────────────────────────────────
FROM oven/bun:1-slim AS production
WORKDIR /app

# Non-root user
RUN addgroup --system --gid 1001 miow && \
    adduser  --system --uid 1001 --ingroup miow miow

# Copy built artifacts and production deps only
COPY --from=build /app/package.json /app/bun.lock ./
RUN bun install --frozen-lockfile --production

COPY --from=build /app/.output ./.output
COPY --from=build /app/public ./public

# Storage directory owned by non-root user
RUN mkdir -p /app/storage && chown -R miow:miow /app/storage

USER miow

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD bun -e "fetch('http://localhost:3000/').then(r=>{process.exit(r.ok?0:1)}).catch(()=>process.exit(1))"

CMD ["bun", "run", "preview"]
