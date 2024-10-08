# Fluent Bit Configuration JSON/YAML Schema

This provides a schema for manipulating Fluent Bit YAML Configurations to get intellisense and validation. 

The inputs, filters, processors, and outputs are generated dynamically from the Fluent Bit JSON "schema". 

It is especially useful when used with tools like VSCode's YAML extension.

![image](https://github.com/user-attachments/assets/2b46091a-4fcb-47c5-b2ea-6844297b61ab)

To use with vscode, simply add the following comment to the top of your config:
`# yaml-language-server: $schema=https://github.com/JustinGrote/FluentBitJsonSchema/releases/latest/download/fluentbit.schema.json`

If you like this, please thumbs up this issue and petition fluent-bit to generate their own config:
https://github.com/fluent/fluent-bit/issues/9289
