# Bor's Drop-in Utils (OpenMW)

## 1.2

- Replaced MultiNumber and MultiTextLine with a merged MultiInput renderer for easier maintaining. It is advised to switch from MultiNumber to MultiInput since the former had a breaking issue when using "min" and "max" arguments
- Two Column Set: Bumped version to 3
- Two Column Set: Made input field required for deleting entries. If no input field is present, RMB won't do anything
- Two Column Set: Added "input" argument to the docs. Whoops

## 1.1

- Two Column Set: Bumped version to 2
- Two Column Set: Made input field optional, enabled by default
- Yaml Folder Parser: Fixed the parser not actually being deterministic. Now it is
- Yaml Folder Parser: Added annotations
- Added new settings renderer: Order List
- Demo script: fixed the settings section name typo

## 1.0

Initial release
