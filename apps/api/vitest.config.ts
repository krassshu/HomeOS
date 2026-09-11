import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    projects: [
      {
        test: {
          name: 'unit',
          include: ['test/unit/**/*.spec.ts'],
        },
      },
      {
        // Integracja podnosi prawdziwy PostgreSQL 18 przez Testcontainers; wymaga Dockera.
        test: {
          name: 'integration',
          include: ['test/integration/**/*.spec.ts'],
          testTimeout: 120_000,
          hookTimeout: 180_000,
          fileParallelism: false,
          env: {
            // Reaper Testcontainers przypięty tak samo jak pozostałe obrazy (index amd64+arm64).
            TESTCONTAINERS_RYUK_CONTAINER_IMAGE:
              'docker.io/testcontainers/ryuk:0.14.0@sha256:7c1a8a9a47c780ed0f983770a662f80deb115d95cce3e2daa3d12115b8cd28f0',
          },
        },
      },
    ],
  },
});
