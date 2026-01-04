import os
import re
from janome.tokenizer import Tokenizer

def tokenize_japanese_text(text):
    t = Tokenizer()
    sentences = re.split(r'[。！？]\s*', text.strip())
    tokens_lines = []
    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        tokens = t.tokenize(sentence, wakati=True)
        tokens_lines.extend(tokens)
        tokens_lines.append("")  
    return tokens_lines

def merge_txt_in_folder(folder_path, output_file):
    all_lines = []
    txt_files = [f for f in os.listdir(folder_path) if f.endswith(".txt")]
    
    if not txt_files:
        print("Aucun fichier .txt trouvé dans le dossier.")
        return
    
    for filename in txt_files:
        file_path = os.path.join(folder_path, filename)
        print(f"Traitement : {filename}")
        with open(file_path, "r", encoding="utf-8") as f:
            text = f.read()
        tokens_lines = tokenize_japanese_text(text)
        all_lines.extend(tokens_lines)
    
    with open(output_file, "w", encoding="utf-8") as out:
        out.write("\n".join(all_lines))
    
    print(f"Fichier final créé : {output_file}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage : python merge_all_japanese_txt.py <dossier_des_txt> <fichier_sortie>")
        sys.exit(1)
    
    folder_path = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.isdir(folder_path):
        print(f"Erreur : le dossier '{folder_path}' n'existe pas.")
        sys.exit(1)

    merge_txt_in_folder(folder_path, output_file)
