#!/bin/bash
# ==============================================================================
# Clinical Intelligence API — Sample curl Commands
# ==============================================================================
# Prerequisites:
#   1. Start the server: ./gradlew :clinical-intelligence:run
#   2. Set your OpenAI API key: export OPENAI_API_KEY="sk-..."
#   3. Server runs on http://localhost:8080
# ==============================================================================

BASE_URL="http://localhost:8080"

# ---- Step 1: Login to get JWT token ----
echo "=== Step 1: Authenticate ==="
TOKEN=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"doctor","password":"password"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")

echo "JWT Token: ${TOKEN:0:20}..."
echo ""

# ---- Step 2: Generate a basic summary (no context enrichment) ----
echo "=== Step 2: Generate Basic Summary ==="
curl -s -X POST "$BASE_URL/api/v1/summary/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d @src/main/resources/examples/sample-consultation-input.json | \
  python3 -m json.tool

echo ""

# ---- Step 3: Generate a context-enriched summary (uses vector DB) ----
# NOTE: Run Step 2 first so the vector store has at least one embedding
echo "=== Step 3: Generate Context-Enriched Summary ==="
curl -s -X POST "$BASE_URL/api/v1/summary/generate-with-context" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d @src/main/resources/examples/sample-consultation-input.json | \
  python3 -m json.tool

echo ""

# ---- Step 4: GZIP-compressed request ----
echo "=== Step 4: GZIP-Compressed Request ==="
# Compress the input file and send with Content-Encoding: gzip
gzip -c src/main/resources/examples/sample-consultation-input.json | \
  curl -s -X POST "$BASE_URL/api/v1/summary/generate" \
    -H "Content-Type: application/json" \
    -H "Content-Encoding: gzip" \
    -H "Authorization: Bearer $TOKEN" \
    --data-binary @- | \
  python3 -m json.tool

echo ""

# ---- Step 5: Get doctor's summary history ----
echo "=== Step 5: Doctor Summary History ==="
curl -s -X GET "$BASE_URL/api/v1/summary/history/DR-SINGH-001" \
  -H "Authorization: Bearer $TOKEN" | \
  python3 -m json.tool

echo ""

# ---- Step 6: Retrieve a specific summary by ID ----
# Replace SUMMARY_ID with actual ID from Step 2 response
echo "=== Step 6: Get Summary by ID (replace SUMMARY_ID) ==="
echo "curl -s -X GET \"$BASE_URL/api/v1/summary/SUMMARY_ID\" -H \"Authorization: Bearer \$TOKEN\""
echo ""

echo "=== Done ==="
