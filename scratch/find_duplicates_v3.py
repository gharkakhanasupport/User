import re
import os

def find_duplicates(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # We want to find keys in each language block
    # Blocks are delimited by 'en': {, 'hi': {, 'bn': {
    langs = ['en', 'hi', 'bn']
    current_lang = None
    all_keys = {} # lang -> set of keys

    print(f"Analyzing {file_path}")
    for i, line in enumerate(lines):
        line_num = i + 1
        # Check for lang start
        for lang in langs:
            if f"'{lang}': {{" in line:
                current_lang = lang
                all_keys[lang] = {}
                break
        
        if current_lang:
            # Match any 'key': or "key":
            match = re.search(r"['\"](\w+)['\"]:\s*", line)
            if match:
                key = match.group(1)
                if key in all_keys[current_lang]:
                    print(f"DUPLICATE KEY '{key}' in '{current_lang}' at line {line_num}. Previous sighting at line {all_keys[current_lang][key]}")
                else:
                    all_keys[current_lang][key] = line_num

if __name__ == "__main__":
    find_duplicates(r"d:\GKK APP\GKK ADMIN ALL APP\USER\lib\core\localization.dart")
