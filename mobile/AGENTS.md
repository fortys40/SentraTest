# Sentra mobile app

The project guide — goals, architecture, file structure, dependencies, commands
and working rules — is [../AGENTS.md](../AGENTS.md). Read it before changing
anything here.

Expo-specific reminders:

- Expo ships breaking changes every SDK release. Check the installed package's
  types or `https://docs.expo.dev/versions/v57.0.0/` before using an Expo or
  React Native API; do not rely on memory.
- Add packages with `npx expo install <package>` so versions match the SDK.
- Routes live in `src/app/` only. Keep components, hooks and logic outside it.
- `ios/` and `android/` are generated. Never create or edit them by hand;
  configure native behaviour in `app.json`.
- Run `npm test`, `npm run typecheck` and `npx expo-doctor` before declaring a
  task done.
