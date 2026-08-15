// defineConfig comes from vitest/config rather than vite so the `test` block
// below is typed. Vite's own build behaviour is unchanged — vitest/config
// re-exports vite's defineConfig with the test options merged in.
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
    plugins: [react()],
    resolve: {
        alias: {
            "@": path.resolve(__dirname, "./src"),
        },
    },
    test: {
        environment: "jsdom",
        setupFiles: ["./src/test/setup.ts"],
        // Explicit imports (`import { describe, it } from "vitest"`) instead of
        // globals: tsconfig.json pins `types: ["vite/client"]`, and adding
        // globals would mean editing that to keep `tsc --noEmit` passing.
        globals: false,
        css: false,
        restoreMocks: true,
    },
    build: {
        rollupOptions: {
            output: {
                manualChunks: {
                    "vendor-react": ["react", "react-dom", "react-router-dom"],
                    "vendor-ui": ["@radix-ui/react-dialog", "@radix-ui/react-select", "@radix-ui/react-tabs", "@radix-ui/react-alert-dialog", "@radix-ui/react-dropdown-menu"],
                    "vendor-misc": ["axios", "jotai", "lucide-react", "react-hook-form"],
                },
            },
        },
    },
});
