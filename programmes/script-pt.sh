#!/usr/bin/env bash

set -o nounset
set -o pipefail

# 1. VERIFICAÇÃO DE ARGUMENTOS E CAMINHOS
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 arquivo_urls lingua"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
URL_FILE="$1"
[ ! -f "$URL_FILE" ] && URL_FILE="$ROOT_DIR/$1"

LANGUE="$2"
DUMP_DIR="$ROOT_DIR/dumps-text"
ASP_DIR="$ROOT_DIR/aspirations"
CTX_DIR="$ROOT_DIR/contextes"
TBL_DIR="$ROOT_DIR/tableaux"

mkdir -p "$DUMP_DIR" "$ASP_DIR" "$CTX_DIR" "$TBL_DIR"

# 2. CONFIGURAÇÕES TÉCNICAS
MOTIFS="cora[cç][ãa]o|cora[cç][õo]es"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"

# Arrays para armazenar os dados e evitar desalinhamento na tabela
declare -A TAB_URLS
declare -A TAB_HTTP
declare -A TAB_ENC

i=1
echo "Analyse en cours pour le portugais..."

while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  url=$(echo "$line" | grep -oE 'https?://[^[:space:]]+' | head -1)
  [ -z "$url" ] && continue

  # Armazena a URL exata para usar na tabela depois
  TAB_URLS[$i]="$url"

  # Coleta metadados (HTTP e Encoding)
  header=$(curl -L -s -I -A "$UA" "$url" --connect-timeout 10 || echo "HTTP/1.1 000 Error")
  TAB_HTTP[$i]=$(echo "$header" | grep "HTTP/" | tail -1 | awk '{print $2}')
  
  charset=$(echo "$header" | grep -i "Content-Type" | grep -oE "charset=[^ ;]+" | cut -d= -f2 | tr -d '"' | tr -d "'")
  [ -z "$charset" ] && charset="UTF-8"
  TAB_ENC[$i]=$(echo "$charset" | tr '[:lower:]' '[:upper:]')

  # Caminhos dos arquivos
  DUMP_PATH="$DUMP_DIR/${LANGUE}-${i}.txt"
  ASP_PATH="$ASP_DIR/${LANGUE}-${i}.html"
  CTX_PATH="$CTX_DIR/${LANGUE}-${i}.txt"

  # Processamento do conteúdo
  curl -L -s -A "$UA" "$url" -o "temp.html"
  
  # Dump textual com Lynx e conversão de encoding para UTF-8
  lynx -dump -nolist -display_charset=utf-8 -assume_charset="${TAB_ENC[$i]}" "temp.html" 2>/dev/null | iconv -f "${TAB_ENC[$i]}" -t "UTF-8//IGNORE" > "$DUMP_PATH" 2>/dev/null || lynx -dump -nolist "temp.html" > "$DUMP_PATH"

  # Extração de contextos (Grep)
  grep -E -o ".{0,100}(${MOTIFS}).{0,100}" "$DUMP_PATH" > "$CTX_PATH" || > "$CTX_PATH"
  
  # Geração da Aspiração (Página com destaques)
  {
    echo "<!DOCTYPE html><html><head><meta charset='UTF-8'></head><body>"
    echo "<h2>Source : <a href='$url'>$url</a></h2><hr>"
    grep -Ei "$MOTIFS" "$DUMP_PATH" | sed 's/^/<p>/;s/$/<\/p>/' || echo "<p>Aucune occurrence</p>"
    echo "</body></html>"
  } > "$ASP_PATH"

  rm -f "temp.html"
  i=$((i+1))
done < "$URL_FILE"

# 3. GERAÇÃO DO HTML FINAL (O TABLEAU)
OUT="$TBL_DIR/${LANGUE}.html"
CSS_PATH="../css/main.css"

{
echo "<!DOCTYPE html>
<html lang='pt'>
<head>
    <meta charset='UTF-8'>
    <title>Tableau Portugais</title>
    <link rel='stylesheet' href='$CSS_PATH'>
</head>
<body>
    <header class='hero heart-hero is-small'>
        <div class='hero-body has-text-centered'>
            <h1 class='title has-text-white'>Coração</h1>
            <p class='subtitle has-text-white'>Tableau des URLs pour le portugais</p>
        </div>
    </header>

    <main class='section'>
        <div class='container box'>
            <h2 class='title is-4 has-text-pink'>Tableau portugais</h2>
            
            <div class='field is-grouped'>
                <p class='control'>
                    <a href='../concordances/${LANGUE}-concordances.html' class='button is-pink is-light'>
                        <span>📊 Voir les concordances</span>
                    </a>
                </p>
            </div>

            <table class='table is-fullwidth is-hoverable is-striped'>
                <thead>
                    <tr>
                        <th>#</th>
                        <th>URL</th>
                        <th>HTTP</th>
                        <th>Encodage</th>
                        <th>Occurrences</th>
                        <th>HTML</th>
                        <th>Dump TXT</th>
                        <th>Contextes</th>
                    </tr>
                </thead>
                <tbody>"

for idx in $(seq 1 $((i-1))); do
    url_final="${TAB_URLS[$idx]}"
    dump_file="$DUMP_DIR/${LANGUE}-${idx}.txt"
    
    # Contagem real das palavras no arquivo dump
    count=$(grep -Eio "$MOTIFS" "$dump_file" 2>/dev/null | wc -l | tr -d ' ')

    echo "<tr>
        <td>$idx</td>
        <td><a href='$url_final' target='_blank' style='display:block; max-width:300px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;'>$url_final</a></td>
        <td><span class='tag is-light'>${TAB_HTTP[$idx]}</span></td>
        <td>${TAB_ENC[$idx]}</td>
        <td><span class='has-text-weight-bold'>$count</span></td>
        <td><a href='../aspirations/${LANGUE}-${idx}.html' class='has-text-info'>HTML</a></td>
        <td><a href='../dumps-text/${LANGUE}-${idx}.txt' class='has-text-info'>TXT</a></td>
        <td><a href='../contextes/${LANGUE}-${idx}.txt' class='has-text-info'>CTX</a></td>
    </tr>"
done

echo "                </tbody>
            </table>
        </div>
    </main>

    <footer class='footer heart-footer has-text-centered'>
        <p>Projet PPE - Analyse du mot 'Coração'</p>
    </footer>
</body>
</html>"
} > "$OUT"

echo "Succès ! Tableau généré em: $OUT"