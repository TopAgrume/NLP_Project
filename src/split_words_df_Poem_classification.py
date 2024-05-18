import copy
import re
import time

from itertools import chain
from nltk.corpus import brown
from nltk.probability import FreqDist 


def findmostlikelytokens(testsentence, fq):
    stack = [([], testsentence)]
    resultlist = []
    while len(stack) > 0:
        currentlist, sentence = stack.pop(0)
        if len(sentence) == 0:
            resultlist.append(currentlist)
        for i in range(0, len(sentence) + 1):
            if sentence[0:i] in fq:
                newlist = copy.deepcopy(currentlist)
                newlist.append(sentence[0:i])
                stack.append((newlist, sentence[i:]))
    finallist = sorted(resultlist, key=(lambda x: scorelist(x, fq)), reverse=True)
    if len(finallist) == 0:
        return [testsentence]
    return finallist[0]


def scorelist(liste, fq):
    summe = 0
    for value in liste:
        summe += fq[value] ** len(value)
    return summe / len(liste)


sentence = "A woman walks by the bench I'm sitting onwith her dog that looks part Lab, part Buick,stops and asks if I would like to dance.I smile, tell her of course I do. We decideon a waltz that she begins to hum"
sentence = re.sub('([.,!?()])', r' \1 ', sentence)
sentence = re.sub('\s{2,}', ' ', sentence)

start = time.time()
brown_words = brown.words()[:100000]
sentence_transformed = []
fq = FreqDist([word.lower() for word in brown_words]) 
for word in sentence.split():
    if word in brown_words:
        sentence_transformed.append([word]) 
    else:
        sentence_transformed.append(findmostlikelytokens(word, fq))
print(time.time() - start)
print(sentence)
print(" ".join(list(chain.from_iterable(sentence_transformed))))
