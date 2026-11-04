#!/usr/bin/env bash
set -euo pipefail

# Default configuration
TARGET_DIR="assets/images/crafting_payload_section_injection"
MODE="encoded-wikilink" # Options: encoded-wikilink | wikilink | markdown

usage() {
    echo "Usage: $0 <markdown-file> [target-image-dir] [--encoded-wikilink|--wikilink|--markdown]"
    echo ""
    echo "Examples:"
    echo "  $0 post.md"
    echo "  $0 post.md assets/images/crafting_payload_section_injection --encoded-wikilink"
    echo "  $0 post.md assets/images/crafting_payload_section_injection --wikilink"
    echo "  $0 post.md assets/images/crafting_payload_section_injection --markdown"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

MD_FILE="$1"

if [[ ! -f "$MD_FILE" ]]; then
    echo "[!] Error: File '$MD_FILE' not found."
    exit 1
fi

# Parse optional second and third arguments
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --encoded-wikilink)
            MODE="encoded-wikilink"
            ;;
        --wikilink)
            MODE="wikilink"
            ;;
        --markdown)
            MODE="markdown"
            ;;
        *)
            # Strip trailing slash if user provided one in custom path
            TARGET_DIR="${1%/}"
            ;;
    esac
    shift
done

# Regex pattern matching ![image.png](image%202.png) through ![image.png](image%2012.png)
SEARCH_REGEX='!\[image\.png\]\(image%20([2-9]|1[0-2])\.png\)'

case "$MODE" in
    encoded-wikilink)
        # Output: ![[assets/images/crafting_payload_section_injection/image%202.png]]
        REPLACE_STR="![[${TARGET_DIR}/image%20\\1.png]]"
        ;;
    wikilink)
        # Output: ![[assets/images/crafting_payload_section_injection/image 2.png]]
        REPLACE_STR="![[${TARGET_DIR}/image \\1.png]]"
        ;;
    markdown)
        # Output: ![image.png](assets/images/crafting_payload_section_injection/image%202.png)
        REPLACE_STR="![image.png](${TARGET_DIR}/image%20\\1.png)"
        ;;
esac

# Create backup (.bak) and apply in-place replacement
sed -i.bak -E "s|${SEARCH_REGEX}|${REPLACE_STR}|g" "$MD_FILE"

echo "[+] Updated image paths (2 to 12) in '$MD_FILE' using mode: $MODE"
echo "[+] Target directory: $TARGET_DIR"
echo "[+] Backup saved to: ${MD_FILE}.bak"