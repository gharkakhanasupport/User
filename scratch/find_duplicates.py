import re
import sys

def find_duplicate_keys(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find each language block
    # 'en': { ... }, 'hi': { ... }, 'bn': { ... }
    blocks = re.findall(r"'(en|hi|bn)':\s*\{([\s\S]*?)\},", content)
    
    for lang, block_content in blocks:
        print(f"Checking language: {lang}")
        keys = re.findall(r"'(\w+)':", block_content)
        seen = set()
        duplicates = set()
        for key in keys:
            if key in seen:
                duplicates.add(key)
            seen.add(key)
        
        if duplicates:
            print(f"  Found duplicates: {duplicates}")
        else:
            print("  No duplicates found.")

if __name__ == "__main__":
    find_duplicate_keys(r'd:\GKK APP\GKK ADMIN ALL APP\USER\lib\core\localization.dart')
