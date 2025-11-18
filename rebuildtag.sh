#!/bin/bash

# rebuildtag.sh - Rebuild and push git tag for gh-pulse release
# Usage: ./rebuildtag.sh [version]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get version from argument or use default
VERSION="${1:-0.1.0}"
TAG="v${VERSION}"

echo -e "${BLUE}🚀 Rebuilding tag ${TAG} for gh-pulse${NC}\n"

# Step 1: Add and commit any pending changes
echo -e "${YELLOW}Step 1: Checking for uncommitted changes...${NC}"
if [[ -n $(git status -s) ]]; then
    echo -e "${GREEN}Found uncommitted changes. Staging files...${NC}"
    git add .
    git status -s
    echo ""
    read -p "Commit these changes? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter commit message: " COMMIT_MSG
        git commit -m "$COMMIT_MSG"
        echo -e "${GREEN}✓ Changes committed${NC}\n"
    else
        echo -e "${RED}Aborted. Please commit changes manually.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ No uncommitted changes${NC}\n"
fi

# Step 2: Check if tag exists locally
echo -e "${YELLOW}Step 2: Checking for existing local tag...${NC}"
if git tag -l | grep -q "^${TAG}$"; then
    echo -e "${YELLOW}Tag ${TAG} exists locally. Deleting...${NC}"
    git tag -d "${TAG}"
    echo -e "${GREEN}✓ Local tag deleted${NC}\n"
else
    echo -e "${GREEN}✓ No existing local tag${NC}\n"
fi

# Step 3: Check if tag exists on remote
echo -e "${YELLOW}Step 3: Checking for existing remote tag...${NC}"
if git ls-remote --tags origin | grep -q "refs/tags/${TAG}"; then
    echo -e "${YELLOW}Tag ${TAG} exists on remote. Deleting...${NC}"
    git push origin ":refs/tags/${TAG}" 2>/dev/null || echo "Remote tag already deleted or doesn't exist"
    echo -e "${GREEN}✓ Remote tag deleted${NC}\n"
else
    echo -e "${GREEN}✓ No existing remote tag${NC}\n"
fi

# Step 4: Verify version in pyproject.toml
echo -e "${YELLOW}Step 4: Verifying version in pyproject.toml...${NC}"
PYPROJECT_VERSION=$(grep '^version = ' pyproject.toml | cut -d'"' -f2)
echo "pyproject.toml version: ${PYPROJECT_VERSION}"
echo "Tag version: ${VERSION}"
if [ "$PYPROJECT_VERSION" != "$VERSION" ]; then
    echo -e "${RED}⚠️  Version mismatch!${NC}"
    echo -e "${YELLOW}Update pyproject.toml version to ${VERSION}? (y/n)${NC}"
    read -p "" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i "s/^version = .*/version = \"${VERSION}\"/" pyproject.toml
        git add pyproject.toml
        git commit -m "chore: bump version to ${VERSION}"
        echo -e "${GREEN}✓ Version updated and committed${NC}\n"
    else
        echo -e "${RED}Version mismatch not resolved. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Version matches${NC}\n"
fi

# Step 5: Clean and rebuild package
echo -e "${YELLOW}Step 5: Rebuilding package...${NC}"
echo "Cleaning old builds..."
rm -rf dist/ build/ *.egg-info src/*.egg-info

echo "Building with uv..."
if command -v uv &> /dev/null; then
    uv build
else
    echo -e "${RED}uv not found. Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Package rebuilt${NC}\n"

# Step 6: Verify build
echo -e "${YELLOW}Step 6: Verifying build...${NC}"
if [ -d "dist" ] && [ "$(ls -A dist/*.whl 2>/dev/null)" ]; then
    echo "Build artifacts:"
    ls -lh dist/
    echo -e "${GREEN}✓ Build verified${NC}\n"
else
    echo -e "${RED}Build failed - no dist files found${NC}"
    exit 1
fi

# Step 7: Check with twine (optional)
echo -e "${YELLOW}Step 7: Checking package with twine (optional)...${NC}"
if command -v twine &> /dev/null; then
    twine check dist/*
    echo -e "${GREEN}✓ Twine check passed${NC}\n"
else
    echo -e "${YELLOW}⚠️  twine not installed. Skipping validation.${NC}"
    echo -e "${YELLOW}Install with: pip install twine${NC}\n"
fi

# Step 8: Create new tag
echo -e "${YELLOW}Step 8: Creating new tag...${NC}"
git tag -a "${TAG}" -m "Release ${TAG} - gh-pulse"
echo -e "${GREEN}✓ Tag ${TAG} created${NC}\n"

# Step 9: Push everything
echo -e "${YELLOW}Step 9: Ready to push to GitHub${NC}"
echo "This will:"
echo "  - Push commits to origin/master"
echo "  - Push tag ${TAG} to origin"
echo ""
read -p "Push to GitHub? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Pushing commits..."
    git push origin master || git push origin main

    echo "Pushing tag..."
    git push origin "${TAG}"

    echo -e "${GREEN}✓ Successfully pushed to GitHub${NC}\n"
else
    echo -e "${YELLOW}Skipped push. You can push manually with:${NC}"
    echo "  git push origin master"
    echo "  git push origin ${TAG}"
    echo ""
fi

# Step 10: Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Tag rebuild complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo -e "${YELLOW}1. Wait for GitHub Actions to publish (if configured)${NC}"
echo "   Check: https://github.com/ruslanlap/gitpulse/actions"
echo ""
echo -e "${YELLOW}2. Or manually upload to PyPI:${NC}"
echo "   twine upload dist/*"
echo ""
echo -e "${YELLOW}3. Create GitHub Release:${NC}"
echo "   https://github.com/ruslanlap/gitpulse/releases/new"
echo "   - Select tag: ${TAG}"
echo "   - Upload: dist/*.whl and dist/*.tar.gz"
echo ""
echo -e "${YELLOW}4. Verify installation:${NC}"
echo "   pip install --upgrade gh-pulse"
echo "   gh-pulse --version"
echo ""
echo -e "${GREEN}Package: gh-pulse ${VERSION}${NC}"
echo -e "${GREEN}Tag: ${TAG}${NC}"
echo -e "${GREEN}Build location: $(pwd)/dist/${NC}"
echo ""

# Optional: Show what's in dist
echo -e "${BLUE}Built packages:${NC}"
ls -lh dist/ 2>/dev/null || echo "No dist directory"
