# flutter_tts — local patch

A copy of [`flutter_tts`](https://github.com/dlutton/flutter_tts) 4.2.5, the
latest release, carrying **one change**.

## Why

Upstream's `android/build.gradle` applies the Kotlin Gradle Plugin itself:

```groovy
ext.kotlin_version = '2.2.20'
classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
apply plugin: 'kotlin-android'
kotlinOptions { jvmTarget = ... }
```

Flutter warns about that on every build —

> WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin
> (KGP): flutter_tts. Future versions of Flutter will fail to build if your app
> uses plugins that apply KGP.

— and a future release will refuse to build at all. This app already uses
built-in Kotlin (`android/settings.gradle.kts` declares KGP `apply false`), so
flutter_tts was the only thing left holding it back, and there is no newer
release to move to.

## What changed

`android/build.gradle` only, following Flutter's own
[migration guide for plugin authors](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors):
the KGP classpath, the `kotlin-android` plugin and the `kotlinOptions` block
are gone, replaced by a `kotlin { compilerOptions { … } }` block that the
ambient built-in Kotlin provides. The 815-line `FlutterTtsPlugin.kt` and every
line of Dart are untouched.

The vendored `pubspec.yaml` declares only the `android` and `web` platforms,
because only those two directories are copied here. HeadShorts is Android-only
(see CLAUDE.md §10), so nothing is lost.

## When to delete this

The moment `flutter_tts` publishes a release that does not apply KGP. Then:

1. delete this directory,
2. delete the `dependency_overrides` entry in the app's `pubspec.yaml`,
3. bump the `flutter_tts` version in `dependencies`.

Nothing else in the app refers to this patch.
