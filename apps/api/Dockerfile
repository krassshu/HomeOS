# syntax=docker/dockerfile:1
# Obraz Core API. Kontekst budowania to root repo (docker build -f apps/api/Dockerfile .).

FROM docker.io/library/node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d AS base
# Bez corepack: wersja pnpm ma być identyczna z packageManager w root package.json.
RUN npm install -g pnpm@11.18.0
# Store pnpm żyje w cache mount BuildKit, więc nie powiększa warstw obrazu.
ENV npm_config_store_dir=/pnpm/store
WORKDIR /app

FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc tsconfig.base.json ./
COPY apps/api/package.json apps/api/
# Skrypty preinstall Prisma muszą się wykonać (allowBuilds w pnpm-workspace.yaml).
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
  pnpm install --frozen-lockfile --filter @homeintelcore/api

FROM deps AS build
COPY apps/api apps/api
RUN pnpm --filter @homeintelcore/api exec prisma generate \
  && pnpm --filter @homeintelcore/api build

FROM base AS prod-deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY apps/api/package.json apps/api/
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
  pnpm install --frozen-lockfile --prod --ignore-scripts --filter @homeintelcore/api

FROM docker.io/library/node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d AS runtime
ENV NODE_ENV=production
# W kontenerze API musi nasłuchiwać poza loopbackiem; main.ts domyślnie bierze 127.0.0.1.
ENV HOST=0.0.0.0
WORKDIR /app
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=prod-deps /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=build /app/apps/api/dist ./apps/api/dist
COPY apps/api/package.json ./apps/api/package.json
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
  CMD ["node","-e","fetch('http://127.0.0.1:'+(process.env.PORT||'3000')+'/api/v1/health/live').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
CMD ["node","apps/api/dist/main.js"]
