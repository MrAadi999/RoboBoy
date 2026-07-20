import requests
import os

images = {
    "boy_music.jpg": "https://i.pinimg.com/736x/e7/71/1a/e7711a2a3283728539f3ab023147864e.jpg",
    "olindl.jpg": "https://i.pinimg.com/736x/19/57/02/195702403d1d73f53cb5ca0cfd773298.jpg",
    "psycho_mind.jpg": "https://i.pinimg.com/736x/3b/b5/8f/3bb58f88b27d77695831e9553301646a.jpg"
}

dest_dir = "/Users/adityakumar/RoboBoy/static/images"
os.makedirs(dest_dir, exist_ok=True)

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
}

for name, url in images.items():
    path = os.path.join(dest_dir, name)
    try:
        print(f"Downloading {url} to {path}...")
        response = requests.get(url, headers=headers, timeout=20)
        if response.status_code == 200:
            with open(path, "wb") as f:
                f.write(response.content)
            print(f"Successfully saved {name}")
        else:
            print(f"Failed to download {name}: Status code {response.status_code}")
    except Exception as e:
        print(f"Error downloading {name}: {e}")
