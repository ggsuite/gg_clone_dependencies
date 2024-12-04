# gg_clone_dependencies

Tool that clones all dependencies of a dart project to the current workspace.

## Installation

```bash
dart pub get
```

Open a `terminal`.

Install tool:

```bash
dart pub global activate --source path .
```

## Checkout direct dependencies

Enter one of your dart projects, e.g. `gg_clone_dependencies`.

```bash
gg_clone_dependencies
```

By default only direct dependencies are checked out.

## Checkout all dependencies

```bash
gg_clone_dependencies --all
```
