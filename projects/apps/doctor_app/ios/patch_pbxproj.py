import re
import sys
import os

def patch_pbxproj(pbxproj_path):
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # We need to add library search paths and OTHER_LDFLAGS for MLC LLM
    # In a real scenario we'd use a robust parser like mod-pbxproj, but for 
    # brevity we'll inject into build settings using regex.

    # 1. Add Library Search Paths
    search_path_inject = r'"$(PROJECT_DIR)/build/lib",'
    if 'LIBRARY_SEARCH_PATHS' not in content:
        # Add basic LIBRARY_SEARCH_PATHS if missing
        content = re.sub(
            r'(buildSettings = \{)',
            r'\1\n\t\t\t\tLIBRARY_SEARCH_PATHS = (\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"$(PROJECT_DIR)/build/lib",\n\t\t\t\t);',
            content
        )
    elif search_path_inject not in content:
        content = re.sub(
            r'(LIBRARY_SEARCH_PATHS = \(\n[^\)]*)',
            r'\1\t\t\t\t\t"$(PROJECT_DIR)/build/lib",\n',
            content
        )

    # 2. Add Linker flags
    flags = [
        "-Wl,-all_load",
        "-lmodel_iphone",
        "-lmlc_llm",
        "-ltvm_runtime",
        "-ltokenizers_cpp",
        "-lsentencepiece",
        "-lc++"
    ]
    
    for flag in flags:
        if flag not in content:
            content = re.sub(
                r'(OTHER_LDFLAGS = \(\n[^\)]*)',
                fr'\1\t\t\t\t\t"{flag}",\n',
                content
            )

    with open(pbxproj_path, 'w') as f:
        f.write(content)
    print("Patched pbxproj successfully.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python patch_pbxproj.py <path_to_pbxproj>")
        sys.exit(1)
    patch_pbxproj(sys.argv[1])
