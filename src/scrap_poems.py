import pandas as pd
from selenium import webdriver
from bs4 import BeautifulSoup
from tqdm import tqdm
import time

topics = [('love', 20, 136), ('nature', 45, 232), ('religion', 56, 93), ('relationships', 38, 253), ('arts & sciences', 65, 195)]
dfs = []
skipped = 0

driver = webdriver.Chrome()

for topic, id, nb_pages in topics:
    poems = []
    for i in tqdm(range(nb_pages)):
        s = f"https://www.poetryfoundation.org/poems/browse#page={i+1}&sort_by=recently_added&topics={id}"
        driver.get(s)
        time.sleep(2)

        soup_menu = BeautifulSoup(driver.page_source, features="lxml")
        ol = soup_menu.find("ol", {"class": "c-vList c-vList_bordered c-vList_bordered_thorough"})

        lis = ol.find_all("li")
        for li in lis:
            link = li.find("a").get("href")
            driver.get(link)
            time.sleep(1)

            soup_poem = BeautifulSoup(driver.page_source, features="lxml")
            div = soup_poem.find("div", {"class": "o-poem isActive"})
            if not div:
                skipped += 1
                continue

            text_divs = div.find_all("div")
            poems.append(''.join([text_div.text for text_div in text_divs]).replace("\n ", "\n"))
        
    df = pd.DataFrame(columns=["poem"], data=poems)
    df["topic"] = topic
    dfs.append(df)

print(f"skipped : {skipped}")
final_df = pd.concat(dfs)
final_df.to_csv("art&sciences.csv")

driver.quit()