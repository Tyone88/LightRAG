#!/bin/bash
# LightRAG Document Ingestion Script
# Uploads all Aion knowledge base documents

API="http://localhost:9621/documents"
SUCCESS=0
FAIL=0
TOTAL=0

upload_file() {
    local file="$1"
    local basename=$(basename "$file")
    TOTAL=$((TOTAL + 1))

    response=$(curl -s -w "\n%{http_code}" -X POST "$API/upload" \
        -F "file=@$file" 2>/dev/null)

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        SUCCESS=$((SUCCESS + 1))
        echo "  OK  $basename"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL $basename (HTTP $http_code)"
    fi
}

upload_text() {
    local file="$1"
    local source="$2"
    TOTAL=$((TOTAL + 1))

    # Read file content, escape for JSON
    content=$(python3 -c "
import json, sys
with open('$file', 'r', errors='replace') as f:
    print(json.dumps(f.read()))
" 2>/dev/null)

    if [ -z "$content" ] || [ "$content" = '""' ]; then
        FAIL=$((FAIL + 1))
        echo "  SKIP $source (empty)"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$API/text" \
        -H "Content-Type: application/json" \
        -d "{\"text\": $content, \"source\": \"$source\"}" 2>/dev/null)

    http_code=$(echo "$response" | tail -1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        SUCCESS=$((SUCCESS + 1))
        echo "  OK  $source"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL $source (HTTP $http_code)"
    fi
}

echo "=========================================="
echo "  Aion LightRAG Document Ingestion"
echo "=========================================="
echo ""

# 1. Business Core Documents (HIGH PRIORITY)
echo "[1/5] Business Core Documents..."
for f in \
    /root/.openclaw/workspace/MEMORY.md \
    /root/.openclaw/workspace/USER.md \
    /root/.openclaw/workspace/SOUL.md \
    /root/.openclaw/workspace/aion/AION_BUSINESS_VISION.md \
    /root/.openclaw/workspace/aion/CONTENT_BOT_PLAYBOOK.md \
    /root/.openclaw/workspace/aion/WSI_STRATEGIC_ACTION_PLAN.md; do
    [ -f "$f" ] && upload_file "$f"
done
echo ""

# 2. YouTube Transcripts (54 .md + 3 .txt converted)
echo "[2/5] YouTube Transcripts (.md files)..."
for f in /root/.openclaw/workspace/aion/knowledge-base/youtube-transcripts/*.md; do
    [ -f "$f" ] && upload_file "$f"
done
echo ""

echo "[2b/5] YouTube Transcripts (.txt converted from .docx)..."
for f in /root/.openclaw/workspace/aion/knowledge-base/youtube-transcripts/*.txt; do
    [ -f "$f" ] && upload_file "$f"
done
echo ""

# 3. CC Prompt History (build journey)
echo "[3/5] CC Prompt History..."
for f in /root/.openclaw/workspace/cc-prompts/CC*.md; do
    [ -f "$f" ] && upload_file "$f"
done
echo ""

# 4. Client Intel
echo "[4/5] Client Intel..."
for f in \
    /root/gulf-agent/DEMO_SCRIPT.md \
    /root/gulf-agent/MEETING_PREP.md; do
    [ -f "$f" ] && upload_file "$f"
done
echo ""

# 5. System documentation
echo "[5/5] System Documentation..."
for f in \
    /root/AION-SYSTEM-MAP.md \
    /root/DATABASE-SCHEMAS.md; do
    [ -f "$f" ] && upload_file "$f"
done
echo ""

echo "=========================================="
echo "  INGESTION COMPLETE"
echo "  Total: $TOTAL | Success: $SUCCESS | Failed: $FAIL"
echo "=========================================="
