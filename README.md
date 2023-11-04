# Tachyon

A fast and simple alternative for `build_runner` to generate dart code.

## Getting started

Check out the [example](https://github.com/spideythewebhead/tachyon/tree/main/example) folder to see how you can create a custom code generator
and use it

## List of plugins

- data_class_plugin (https://pub.dev/packages/data_class_plugin)
- http_client_plugin (https://pub.dev/packages/http_client_plugin)
- riverpod_tachyon_plugin (https://pub.dev/packages/riverpod_tachyon_plugin)

## Issues with VSCode

When running a flutter app from VSCode the code generator may not receive a file modification event.
To resolve that you can enable the following option (Preview Hot Reload On Save Watcher)

<img src="https://raw.githubusercontent.com/spideythewebhead/tachyon/main/images/vscode_watcher_option.png">