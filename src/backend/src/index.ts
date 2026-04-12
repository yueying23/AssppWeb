import express from "express";
import { createServer } from "http";
import path from "path";
import fs from "fs";
import { config } from "./config.js";
import { httpsRedirect } from "./middleware/httpsRedirect.js";
import { accessAuth } from "./middleware/accessAuth.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { setupWsProxy } from "./services/wsProxy.js";
import authRoutes from "./routes/auth.js";
import searchRoutes from "./routes/search.js";
import downloadRoutes from "./routes/downloads.js";
import packageRoutes from "./routes/packages.js";
import installRoutes from "./routes/install.js";
import settingsRoutes from "./routes/settings.js";
import bagRoutes from "./routes/bag.js";

// Validate environment configuration on startup
function validateConfig() {
  const warnings: string[] = [];
  const errors: string[] = [];

  // JWT_SECRET validation
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === "change-me-in-production") {
    if (process.env.NODE_ENV === "production") {
      errors.push("JWT_SECRET must be set in production environment");
    } else {
      warnings.push("JWT_SECRET is using default value (not recommended for production)");
    }
  }

  // PORT validation
  if (config.port < 1 || config.port > 65535) {
    errors.push(`Invalid PORT: ${config.port} (must be 1-65535)`);
  }

  // DOWNLOAD_THREADS validation
  const threads = parseInt(process.env.DOWNLOAD_THREADS || "8", 10);
  if (threads < 1 || threads > 32) {
    warnings.push(`DOWNLOAD_THREADS=${threads} is outside recommended range (1-32)`);
  }

  // Log warnings
  if (warnings.length > 0) {
    console.warn("⚠️  Configuration warnings:");
    warnings.forEach((w) => console.warn(`   - ${w}`));
  }

  // Halt on errors
  if (errors.length > 0) {
    console.error("❌ Configuration errors:");
    errors.forEach((e) => console.error(`   - ${e}`));
    process.exit(1);
  }
}

const app = express();

// Middleware
app.use(httpsRedirect);
app.use(express.json({ limit: "50mb" }));

// Public API routes (no auth required)
app.use("/api/health", settingsRoutes);

// Protected API routes
app.use("/api", accessAuth);
app.use("/api", authRoutes);
app.use("/api", searchRoutes);
app.use("/api", downloadRoutes);
app.use("/api", packageRoutes);
app.use("/api", installRoutes);
app.use("/api", settingsRoutes);
app.use("/api", bagRoutes);

// Serve static frontend files
const publicDir = path.resolve(import.meta.dirname, "../public");
app.use(express.static(publicDir));

// SPA fallback: serve index.html for non-API routes
app.get("*", (req, res, next) => {
  if (req.path.startsWith("/api")) {
    return next();
  }
  const indexPath = path.join(publicDir, "index.html");
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    next();
  }
});

// Error handler (must be last)
app.use(errorHandler);

// Create HTTP server
const server = createServer(app);

// WebSocket proxy for Apple TCP connections
setupWsProxy(server);

// Ensure data directory exists
fs.mkdirSync(config.dataDir, { recursive: true });

// Validate configuration before starting
validateConfig();

server.listen(config.port, () => {
  console.log(`✅ Server listening on port ${config.port}`);
  console.log(`📂 Data directory: ${path.resolve(config.dataDir)}`);
  if (process.env.NODE_ENV === "production") {
    console.log(`🔒 Access protection: ${config.accessPassword ? "enabled" : "disabled"}`);
  }
});

export { app, server };
