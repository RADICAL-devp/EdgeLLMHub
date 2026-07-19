import urllib.request
import json
import os

repo_id = "mlc-ai/Llama-3.2-3B-Instruct-q4f16_1-MLC"
api_url = f"https://huggingface.co/api/models/{repo_id}/tree/main"
base_download_url = f"https://huggingface.co/{repo_id}/resolve/main"
output_dir = "/Users/devanshparashar/dev-playground/projects/apps/doctor_app/ios/Llama-3.2-3B-Instruct-q4f16_1-MLC"

os.makedirs(output_dir, exist_ok=True)

print("Fetching file list...")
req = urllib.request.Request(api_url)
with urllib.request.urlopen(req) as response:
    files = json.loads(response.read().decode())

total_files = len(files)
print(f"Found {total_files} files to download.")

for i, f in enumerate(files):
    path = f['path']
    # Skip directories or git attributes if any
    if f['type'] != 'file':
        continue
    
    file_url = f"{base_download_url}/{path}"
    out_path = os.path.join(output_dir, path)
    
    if os.path.exists(out_path) and os.path.getsize(out_path) == f.get('size', -1):
        print(f"Skipping {path} (already downloaded)")
        continue
        
    print(f"Downloading [{i+1}/{total_files}] {path}...")
    urllib.request.urlretrieve(file_url, out_path)

print("\nDownload complete! The model is saved at:")
print(output_dir)
