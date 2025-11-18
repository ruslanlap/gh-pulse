#!/bin/bash
# quicktag.sh - Quick rebuild and push tag (no prompts)
# Usage: ./quicktag.sh [version]

set -e
VERSION="${1:-0.1.0}"
TAG="v${VERSION}"

echo "🚀 Quick rebuild tag: ${TAG}"
echo ""

# Commit changes if any
if [[ -n $(git status -s) ]]; then
    echo "📝 Committing changes..."
    git add .
    git commit -m "chore: prepare release ${TAG}" || true
fi

# Delete existing tags
echo "🗑️  Removing old tags..."
git tag -d "${TAG}" 2>/dev/null || true
git push origin ":refs/tags/${TAG}" 2>/dev/null || true

# Clean and rebuild
echo "🏗️  Building package..."
rm -rf dist/ build/ *.egg-info
uv build

# Create and push tag
echo "🏷️  Creating tag ${TAG}..."
git tag -a "${TAG}" -m "Release ${TAG}"

echo "⬆️  Pushing to GitHub..."
git push origin master || git push origin main
git push origin "${TAG}"

echo ""
echo "✅ Done!"
echo ""
echo "📦 Built: $(ls dist/)"
echo "🏷️  Tag: ${TAG}"
echo ""
echo "Next: https://github.com/ruslanlap/gitpulse/releases/new"
