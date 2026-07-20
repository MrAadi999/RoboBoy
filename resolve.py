import requests

links = [
    "https://pin.it/625GN1hld",
    "https://pin.it/5ZcHQ34aq",
    "https://pin.it/7s32EXqaI",
    "https://pin.it/PCiwz4aq5",
    "https://pin.it/2OSC0Oa2A"
]

for idx, url in enumerate(links, 1):
    try:
        response = requests.head(url, allow_redirects=True, timeout=10)
        print(f"Link {idx}: {response.url}")
    except Exception as e:
        print(f"Link {idx} Error: {e}")
