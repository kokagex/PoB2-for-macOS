#!/usr/bin/env python3
"""
Scrape Japanese gem descriptions from poe2db.tw for Path of Building 2.
Outputs: src/Locales/ja_gem_descriptions.lua

Usage:
    python3 scripts/scrape_gem_descriptions.py

Requires: requests, beautifulsoup4
    pip3 install requests beautifulsoup4
"""

import re
import sys
import time
import requests
from bs4 import BeautifulSoup

BASE_URL = "https://poe2db.tw"
GEMS_URL = f"{BASE_URL}/jp/Gems"
OUTPUT_PATH = "PathOfBuilding.app/Contents/Resources/src/Locales/ja_gem_descriptions.lua"

# Known gem name mappings: PoB internal name -> poe2db URL slug
# (for gems where the name doesn't directly map to the URL)
SLUG_OVERRIDES = {}

def fetch_page(url, retries=3, delay=1.0):
    """Fetch a page with retries and rate limiting."""
    for attempt in range(retries):
        try:
            resp = requests.get(url, timeout=30, headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) PoB2macOS-i18n/1.0"
            })
            if resp.status_code == 200:
                return resp.text
            elif resp.status_code == 404:
                return None
            else:
                print(f"  HTTP {resp.status_code} for {url}, retrying...")
        except requests.RequestException as e:
            print(f"  Error fetching {url}: {e}, retrying...")
        time.sleep(delay * (attempt + 1))
    return None

def name_to_slug(name):
    """Convert gem name to URL slug."""
    if name in SLUG_OVERRIDES:
        return SLUG_OVERRIDES[name]
    # Remove apostrophes, replace spaces with underscores
    slug = name.replace("'", "").replace(" ", "_")
    return slug

def extract_description_from_page(html):
    """Extract the Japanese gem description from an individual gem page."""
    if not html:
        return None
    soup = BeautifulSoup(html, "html.parser")

    # Primary: div.secDescrText contains the gem description
    desc_div = soup.find("div", class_="secDescrText")
    if desc_div:
        text = desc_div.get_text(strip=True)
        if text and len(text) > 5:
            return text

    return None

def extract_gems_from_listing(html):
    """Extract gem names and URLs from the listing page."""
    soup = BeautifulSoup(html, "html.parser")
    gems = {}

    # Find all links that point to individual gem pages
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if href.startswith("/jp/") and len(href) > 5:
            # Skip known non-gem pages
            skip_patterns = ["/jp/Gems", "/jp/Skill_Gems", "/jp/Support_Gems",
                           "/jp/Meta_", "/jp/search", "/jp/Modifiers"]
            if any(href.startswith(p) for p in skip_patterns):
                continue
            # Get the display text
            text = a.get_text(strip=True)
            if text and len(text) > 1:
                gems[href] = text

    return gems

def extract_descriptions_from_listing(html):
    """Try to extract descriptions directly from the listing page cards."""
    soup = BeautifulSoup(html, "html.parser")
    descriptions = {}

    # Look for card elements that contain gem info
    cards = soup.find_all("div", class_=re.compile(r"card|gem-card|item-card"))
    for card in cards:
        # Try to find English name and description
        links = card.find_all("a", href=True)
        for link in links:
            href = link["href"]
            if href.startswith("/jp/"):
                name_text = link.get_text(strip=True)
                # Look for description text in the card
                parent = link.find_parent(class_=re.compile(r"card"))
                if parent:
                    desc_elem = parent.find(class_=re.compile(r"desc|description|text"))
                    if desc_elem:
                        desc = desc_elem.get_text(strip=True)
                        if desc and len(desc) > 10:
                            descriptions[name_text] = desc

    return descriptions

def get_pob_gem_names():
    """Read PoB gem names from the existing ja.lua translations."""
    gem_names = []
    try:
        with open("PathOfBuilding.app/Contents/Resources/src/Locales/ja.lua", "r", encoding="utf-8") as f:
            in_gems = False
            for line in f:
                if "gems = {" in line:
                    in_gems = True
                    continue
                if in_gems:
                    if line.strip() == "},":
                        break
                    # Extract English gem name from ["Name"] = "翻訳"
                    m = re.match(r'\s*\["(.+?)"\]\s*=\s*"', line)
                    if m:
                        gem_names.append(m.group(1))
    except FileNotFoundError:
        print("Warning: ja.lua not found, using empty gem list")
    return gem_names

def generate_lua_file(descriptions):
    """Generate the Lua file from descriptions dict."""
    lines = ['-- Japanese gem descriptions for Path of Building 2',
             '-- Source: poe2db.tw/jp/',
             '-- Auto-generated by scripts/scrape_gem_descriptions.py',
             '',
             'return {']

    for name in sorted(descriptions.keys()):
        desc = descriptions[name]
        # Escape any special Lua characters in the description
        desc = desc.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        lines.append(f'\t["{name}"] = "{desc}",')

    lines.append('}')
    lines.append('')

    return '\n'.join(lines)

def main():
    print("=== PoE2DB Japanese Gem Description Scraper ===")
    print()

    # Step 1: Get PoB gem names
    print("Step 1: Reading PoB gem names from ja.lua...")
    gem_names = get_pob_gem_names()
    print(f"  Found {len(gem_names)} gem names in PoB")

    if not gem_names:
        print("Error: No gem names found. Make sure ja.lua exists with a gems section.")
        sys.exit(1)

    # Step 2: Fetch individual gem pages and extract descriptions
    print(f"\nStep 2: Fetching descriptions for {len(gem_names)} gems from poe2db.tw...")
    descriptions = {}
    failed = []

    for i, name in enumerate(gem_names):
        slug = name_to_slug(name)
        url = f"{BASE_URL}/jp/{slug}"

        if (i + 1) % 50 == 0 or i == 0:
            print(f"  Progress: {i+1}/{len(gem_names)}")

        html = fetch_page(url)
        if html:
            desc = extract_description_from_page(html)
            if desc:
                descriptions[name] = desc
            else:
                failed.append((name, "no description found"))
        else:
            failed.append((name, "page not found"))

        # Rate limiting: be respectful
        time.sleep(0.5)

    print(f"\n  Successfully extracted: {len(descriptions)}/{len(gem_names)}")
    if failed:
        print(f"  Failed: {len(failed)}")
        for name, reason in failed[:20]:
            print(f"    - {name}: {reason}")
        if len(failed) > 20:
            print(f"    ... and {len(failed) - 20} more")

    # Step 3: Generate Lua file
    print(f"\nStep 3: Generating {OUTPUT_PATH}...")
    lua_content = generate_lua_file(descriptions)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(lua_content)
    print(f"  Written {len(descriptions)} descriptions to {OUTPUT_PATH}")

    print("\nDone!")

if __name__ == "__main__":
    main()
