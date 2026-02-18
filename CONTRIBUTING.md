# How to contribute

Contributions are welcome. Please follow these guidelines when submitting a pull request.

## Getting started

* You need a [GitHub account](https://github.com/signup/free)
* Check [existing issues](https://github.com/cspenn/terminal-notifier-next/issues) before opening a new one
  * For bugs, describe the issue and include steps to reproduce it
  * Mention the earliest version affected
* Fork the repository if you want to submit a fix

## Building

Requires Xcode Command Line Tools (macOS 10.15+).

```bash
# Build the release binary
swift build -c release

# Build and package as an .app bundle
./scripts/build-bundle.sh
```

See [README.md](README.md) for full installation instructions.

## Making changes

* Create a topic branch from `master` for your work (e.g. `fix/piped-stdin` or `feature/new-flag`)
* Keep commits logical and well-described
* Run `swift build -c release` before submitting to confirm a clean build
* If adding a new flag, update the help text in `Notifier.swift` and the README

## Submitting a pull request

* Push your branch to your fork and open a pull request against `master`
* Reference the issue your PR addresses
* Do not merge your own pull request — wait for a review

## Additional resources

* [GitHub documentation](https://docs.github.com)
* [GitHub pull request documentation](https://docs.github.com/en/pull-requests)
