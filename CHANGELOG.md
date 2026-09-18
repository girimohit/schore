# Changelog & Performance Optimization Log

## [Unreleased]

### 1. In-Memory Token Caching in Mobile SecureStorage & ApiClient
- **What Changed**: Implemented singleton pattern with in-memory caching (`_cachedAccessToken`, `_cachedRefreshToken`) inside `SecureStorage` in Flutter mobile app.
- **Why**: Avoids hitting Flutter platform channel IPC (Android KeyStore / iOS Keychain decryption) on every single Dio HTTP request, dropping header injection latency from ~20-50ms down to ~0.001ms.
- **Under the Hood**:
  - `init()` loads tokens once from encrypted disk into RAM.
  - `getAccessToken()` serves synchronously from memory after first boot.
  - `saveTokens()` immediately updates RAM cache while persisting to disk via `Future.wait`.
  - `clearTokens()` wipes memory and disk in parallel.
