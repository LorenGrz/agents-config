---
name: react-native-mobile
description: Use this skill when building, reviewing, or refactoring React Native TypeScript apps with navigation, mobile state, forms, permissions, platform differences, native APIs, and release-aware engineering practices.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
    - react-native
  focus:
    - mobile architecture
    - navigation
    - platform APIs
    - release quality
  triggers:
    - React Native
    - mobile app
    - Expo
    - native module
    - iOS
    - Android
---

# React Native Mobile

## Objective

Build React Native apps that handle mobile constraints deliberately: navigation, permissions, device APIs, offline behavior, platform differences, and release readiness.

## Architecture Rules

- Keep screens thin; move data loading, permissions, and device integrations into hooks or services.
- Use the repository's navigation library and route typing conventions.
- Keep reusable UI components platform-aware but not business-aware.
- Handle loading, empty, error, offline, and permission-denied states explicitly.
- Avoid assuming iOS and Android behavior is identical; check platform-specific APIs and layout differences.

## Native And Device APIs

- Request permissions at the point of need and explain denied states in the UI.
- Clean up subscriptions, app-state listeners, geolocation watches, timers, and native event listeners.
- Avoid blocking the JS thread with expensive synchronous work.
- Use secure storage for sensitive tokens when the project provides it; do not store secrets in plain async storage.

## Styling And UX

- Respect safe areas, keyboard avoidance, and touch target sizes.
- Test small screens and large screens.
- Use platform-native affordances when the project already has conventions for them.

## Validation

- Run typecheck, lint, unit tests, and platform-specific checks when scripts exist.
- For navigation or native API changes, verify both iOS and Android behavior when available.
- For Expo projects, prefer existing Expo scripts and config conventions.
