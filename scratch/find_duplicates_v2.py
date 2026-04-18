import re

def find_duplicate_keys_with_lines(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    langs = ['en', 'hi', 'bn']
    current_lang = None
    keys_in_lang = {} # lang -> {key -> [line_nums]}
    
    for i, line in enumerate(lines):
        line_num = i + 1
        # Detect language block start
        lang_match = re.search(r"'(en|hi|bn)':\s*\{", line)
        if lang_match:
            current_lang = lang_match.group(1)
            keys_in_lang[current_lang] = {}
            continue
        
        if current_lang:
            # Detect key
            key_match = re.search(r"^\s*'(\w+)':", line)
            if key_match:
                key = key_match.group(1)
                if key not in keys_in_lang[current_lang]:
                    keys_in_lang[current_lang][key] = []
                keys_in_lang[current_lang][key].append(line_num)
            
            # Detect block end (rough check)
            if line.strip() == "},":
                # Check for nested maps if any, but localization.dart is simple
                if len(line) - len(line.lstrip()) <= 4: # low indentation means end of main block
                    current_lang = None

    for lang in keys_in_lang:
        print(f"Language: {lang}")
        for key, line_nums in keys_in_lang[lang].items():
            if len(line_nums) > 1:
                print(f"  Duplicate key '{key}' found at lines: {line_nums}")

if __name__ == "__main__":
    find_duplicate_keys_with_lines(r'd:\GKK APP\GKK ADMIN ALL APP\USER\lib\core\localization.dart')
