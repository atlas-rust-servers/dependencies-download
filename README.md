# Pterodactyl's dependencies downloader
Dependency downloader that helps keep files up to date by downloading the latest version on server startup.

## How to use
1. Create a file `external.json` at the server's root
2. Add dependencies as you please following the json format below

### Json Format
```json
{
  "public-repo": [
    {
      "url": "PATH_TO_URL",
      "output-path": "PATH_TO_DIRECTORY"
    }
  ],
  "private-repo": [
    {
      "token": "YOUR_TOKEN",
      "file": "YOUR_FILENAME",
      "repo": "YOUR_ORGANIZATION_NAME_/_YOUR_REPOSITORY_NAME",
      "output-path": "PATH_TO_DIRECTORY"
    }
  ]
}
```
