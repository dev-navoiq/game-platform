#!/bin/bash

# Script to post Story #52 update to GitHub Issue
# Usage: ./post-to-github.sh

ISSUE_NUMBER="52"
REPO="dev-navoiq/game-platform"
COMMENT_FILE="docs/GITHUB-ISSUE-52-UPDATE.md"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ gh CLI is not installed"
    echo ""
    echo "Install it with:"
    echo "  brew install gh"
    echo ""
    echo "Or manually post the comment:"
    echo "  1. Open: https://github.com/$REPO/issues/$ISSUE_NUMBER"
    echo "  2. Copy content from: $COMMENT_FILE"
    echo "  3. Paste as a comment"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub"
    echo "Run: gh auth login"
    exit 1
fi

# Post the comment
echo "Posting comment to Issue #$ISSUE_NUMBER..."
gh issue comment $ISSUE_NUMBER \
    --repo $REPO \
    --body-file $COMMENT_FILE

if [ $? -eq 0 ]; then
    echo "✅ Comment posted successfully!"
    echo "View at: https://github.com/$REPO/issues/$ISSUE_NUMBER"
else
    echo "❌ Failed to post comment"
    echo ""
    echo "Manual fallback:"
    echo "  1. Open: https://github.com/$REPO/issues/$ISSUE_NUMBER"
    echo "  2. Copy content from: $COMMENT_FILE"
    echo "  3. Paste as a comment"
fi
