import spacy
import os  

nlp = spacy.load("pt_core_news_sm")

for i in range(1, 51):
    name = "contextes/pt-" + str(i) + ".txt"
    new_name = "projet_PALS/contextes_segmentés/pt-" + str(i) + ".txt"
    
    os.makedirs(os.path.dirname(new_name), exist_ok=True)
    
    with open(name, "r", encoding="utf-8") as f1:
        text = f1.read()
        doc = nlp(text)
    
    with open(new_name, "w", encoding="utf-8") as f2:
        for sent in doc.sents:
            for token in sent:
                f2.write(token.lemma_.lower() + "\n")
            
            f2.write("\n")
    
    print(f"Textes segmentés: pt-{i}.txt")