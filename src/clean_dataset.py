import pandas as pd
import string
from nltk.corpus import stopwords

stop_words = stopwords.words("english")

df = pd.read_csv("../our_data/our_dataset.csv", index_col=0)
df["poem"] = df["poem"].str.replace("\n", " ").str.lower().str.translate(str.maketrans('', '', string.punctuation + "‘’")).replace("\d+",  "", regex=True)
df["poem"] = df["poem"].apply(lambda poem: " ".join([word for word in poem.split() if word not in stop_words]))
df = df[df["poem"].str.len() > 20].reset_index(drop=True)
df["poem"] = df["poem"].apply(lambda poem : ''.join([i if ord(i) < 128 else ' ' for i in poem])) # remove non ascii chars
df["poem"] = df["poem"].apply(lambda poem : ' '.join([w if len(w) != 1 else '' for w in poem.split()])) # remove single char words

df.to_csv("clean_dataset.csv")