import requests
from bs4 import BeautifulSoup
import re

url = "https://mpu.mjc.ac.kr/Main/default.aspx"
res = requests.get(url)
res.encoding = 'utf-8'
soup = BeautifulSoup(res.text, "html.parser")

with open("mpu_main.html", "w", encoding="utf-8") as f:
    f.write(res.text)

