## Tachyon simple plugin

An example of how to create a basic plugin and using it.

## Code generator

The code generator example is in this [file](lib/generator/code_generator.dart)

Basic setup requires

1. Create a `tachyon_plugin_config.yaml` with the following entries

   1. name: the name of the package
   1. code_generator:

      1. file: the relative path of the dart file. This should be relative to the `lib` folder
      1. className: the name of your custom code generator class

   1. annotations: a list of annotation names that your code generator wants to handle

## Using the code generator

1. Create a `tachyon_config.yaml`

   1. file_generation_paths: a list of the files that you want to include in code generation (can be globs)

   1. plugins: a list of plugins to use

   1. generated_file_line_length: line length for generated files (this can be used if you commit the generated files)
