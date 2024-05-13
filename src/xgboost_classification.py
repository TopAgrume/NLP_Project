import pandas as pd
import numpy as np
import os
import nltk
nltk.download('stopwords')
from nltk.corpus import stopwords
import string
from sklearn.model_selection import train_test_split
import xgboost as xgb
from sklearn.feature_extraction.text import TfidfVectorizer

from sklearn.feature_extraction.text import CountVectorizer
from sklearn.preprocessing import LabelEncoder


topics = os.listdir("../data_raw/topics")
df_topics_list = []
for topic in topics:
    files = os.listdir(f"../data_raw/topics/{topic}")
    df_topic = pd.DataFrame(columns=["poem", "labels"])
    i = 0
    for filename in files:
        with open(f"../data_raw/topics/{topic}/{filename}", encoding="utf8") as f:
            df_topic.loc[i] = {"poem": f.read(), "labels": topic}
        i += 1
    df_topics_list.append(df_topic)

df_topics = pd.concat(df_topics_list, ignore_index=True)


stop_words = stopwords.words("english")
df = df_topics
df["poem"] = df["poem"].str.replace("\n", " ").str.lower().str.translate(str.maketrans('', '', string.punctuation + "‘’")).replace("\d+",  "", regex=True)
df["poem"] = df["poem"].apply(lambda poem: " ".join([word for word in poem.split() if word not in stop_words]))
df = df[df["poem"].str.len() > 20].reset_index(drop=True)
indices_to_remove = [3992, 9431, 11216, 12517, 12604]
df = df.drop(indices_to_remove).reset_index(drop=True)

filtered_df = df # flemme de changer la structure du truc





tfidf_vectorizer = TfidfVectorizer(max_features=1000) 
X = tfidf_vectorizer.fit_transform(filtered_df['poem'])


# encoding labels
label_encoder = LabelEncoder()
y = label_encoder.fit_transform(filtered_df['labels'])


X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)



model = xgb.XGBClassifier()
model.fit(X_train, y_train)

new_poem = ["I think i like you. Do you want to be my boyfriend ? I love every single inch of you !"]

new_poem_transformed = tfidf_vectorizer.transform(new_poem)
predicted_label = model.predict(new_poem_transformed)

predicted_label_decoded = label_encoder.inverse_transform(predicted_label)
print("Predicted Label:", predicted_label_decoded[0])




probabilities = model.predict_proba(new_poem_transformed)
labels = label_encoder.classes_

prob_dict = {label: prob for label, prob in zip(labels, probabilities[0])}

sorted_probabilities = sorted(prob_dict.items(), key=lambda x: x[1], reverse=True)

# Print probabilities for each label in descending order
for label, probability in sorted_probabilities:
    print(f"Probability of '{label}': {probability:.4f}")

from sklearn.metrics import accuracy_score
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print("Accuracy:", accuracy)
