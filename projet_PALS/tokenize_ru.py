import spacy

nlp = spacy.load("ru_core_news_sm")

for i in range(1, 51):
    name = "/home/tupikina/Documents/Cours/Plurital/Trial/contextes/ru-" + str(i) + ".txt"
    new_name = "/home/tupikina/Documents/Cours/Plurital/Trial/projet_PALS/texts/ru-" + str(i) + ".txt"
    with open(name, "r", encoding="utf-8") as f1:
        text = f1.read()
        doc = nlp(text)
    with open(new_name, "w", encoding="utf-8") as f2:
        for sent in doc.sents:
            for token in sent:
                f2.write(token.text + "\n")
            f2.write("\n\n")