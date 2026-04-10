# Atlas Dependency Manager

Automatic dependency downloader for Atlas Rust servers. Downloads the latest release assets from GitHub on every server boot, with validation and retries.

## Features

- Downloads from public and private GitHub repos
- Validates every file (exists + non-empty)
- Retries failed downloads up to 3 times
- Blocks server startup if any dependency is missing
- Clean console output with per-file status

## Config

Create `external.json` at the server root:

```json
{
  "public-repo": [
    {
      "url": "https://github.com/org/repo/releases/latest/download/Plugin.dll",
      "output-path": "/home/container/RustDedicated_Data/Managed/Plugin.dll"
    }
  ],
  "private-repo": [
    {
      "token": "ghp_your_token",
      "repo": "org/repo-name",
      "file": "Extension.dll",
      "output-path": "/home/container/RustDedicated_Data/Managed/Extension.dll"
    }
  ]
}
```

## Usage

This script is fetched automatically by the [Atlas Egg](https://github.com/atlas-rust-servers/atlas-egg) on every server boot. No manual setup needed — just configure your `external.json`.
