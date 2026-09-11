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
        },
      },
    ],
  },
});
