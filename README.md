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

## Checkout the main branches of git references

```bash
gg_clone_dependencies --checkout-main-branch
```

## Checkout exact branch of git references

```bash
gg_clone_dependencies --no-checkout-main-branch
```

## Clone the dependencies to a specified directory

```bash
gg_clone_dependencies --target ~/tmp
```

## Execute clone dependencie in a given directory

```bash
gg_clone_dependencies --input ~/dev/gg
```

## Exclude dependencies from cloning

```bash
gg_clone_dependencies --exclude flutter
```
