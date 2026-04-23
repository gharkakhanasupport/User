import os
import re

def fix_with_opacity(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace withOpacity(val) with withValues(alpha: val)
                # We use a regex to capture the argument
                new_content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Fixed: {path}")

if __name__ == "__main__":
    fix_with_opacity(r"d:\GKK APP\GKK ADMIN ALL APP\USER\lib")
