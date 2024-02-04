#!/bin/bash

JSON_FILE="external.json"

download_public() {
    local url=$1
    local path=$2

    mkdir -p "$(dirname "$path")"
    echo "Downloading from public URL: $url"
    curl -L "$url" -o "$path"
}

download_private() {
    local token=$1
    local repo=$2
    local file=$3
    local path=$4

    mkdir -p "$(dirname "$path")"

    # Fetch the latest release
    latest_release_api_url="https://api.github.com/repos/$repo/releases/latest"
    
    # Get the asset ID for the required file from the latest release
    asset_id=$(curl -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" "$latest_release_api_url" | jq -r ".assets[] | select(.name==\"$file\") | .id")

    if [ -z "$asset_id" ]; then
        echo "Asset $file not found in the latest release of $repo"
        return 1
    fi

    # Constructing download URL for the asset
    download_url="https://api.github.com/repos/$repo/releases/assets/$asset_id"

    echo "Downloading asset ID $asset_id from $repo"

    # Download the asset
    curl -JL -H "Authorization: token $token" -H "Accept: application/octet-stream" "$download_url" -o "$path"
}

# Parse public-repo section and download files
jq -r '.["public-repo"][] | "\(.url) \(.["output-path"])"' "$JSON_FILE" | while read -r url path; do
    download_public "$url" "$path"
done

# Parse private-repo section and download files
jq -r '.["private-repo"][] | "\(.["token"]) \(.repo) \(.file) \(.["output-path"])"' "$JSON_FILE" | while read -r token repo file path; do
    download_private "$token" "$repo" "$file" "$path"
done
