import requests
from bs4 import BeautifulSoup
import re

links = [
    "https://www.pinterest.com/pin/438326976257252296/",
    "https://www.pinterest.com/pin/73816881389488819/",
    "https://www.pinterest.com/pin/1548181186726539/",
    "https://www.pinterest.com/pin/38491771812928938/",
    "https://www.pinterest.com/pin/68749379519/"
]

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
}

for idx, url in enumerate(links, 1):
    try:
        response = requests.get(url, headers=headers, timeout=15)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Try og:title, og:description, og:image
        og_title = soup.find("meta", property="og:title")
        og_desc = soup.find("meta", property="og:description")
        og_image = soup.find("meta", property="og:image")
        
        title = og_title["content"] if og_title else soup.title.string if soup.title else "No Title"
        desc = og_desc["content"] if og_desc else "No Description"
        img = og_image["content"] if og_image else "No Image"
        
        print(f"Pin {idx}:")
        print(f"  Title: {title.strip()}")
        print(f"  Description: {desc.strip()}")
        print(f"  Image: {img.strip()}")
        print("-" * 40)
    except Exception as e:
        print(f"Pin {idx} Error: {e}")
