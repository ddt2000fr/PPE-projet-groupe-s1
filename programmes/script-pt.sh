#!/usr/bin/env bash

set -o nounset
set -o pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 fichier_urls langue"
  exit 1
fi

URL_FILE="$1"
LANGUE="$2"

#Recherche du mot et toutes ses variations
MOTIFS="cora(c|ç)(ã|a)o|cora(c|ç)(õ|o)es"
CONTEXT_SIZE=150
UA="Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"

export LANG=pt_PT.UTF-8
export LC_ALL=pt_PT.UTF-8

[ ! -f "$URL_FILE" ] && { echo "Fichier introuvable : $URL_FILE"; exit 1; }

for cmd in curl lynx pdftotext; do
  command -v "$cmd" >/dev/null || { echo "Commande manquante : $cmd"; exit 1; }
done

mkdir -p dumps-text aspirations contextes tableaux concordances

declare -A HTTP_CODES
declare -A ENCODINGS

clean_line() {
  echo "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

extract_url() {
  echo "$1" | grep -oE '^https?://[^[:space:]]+'
}

download_pdf() {
  local url="$1" out="$2" idx="$3"
  HTTP_CODES[$idx]=$(curl -L -s -w "%{http_code}" -A "$UA" "$url" -o tmp.pdf)
  ENCODINGS[$idx]="PDF"
  pdftotext -layout tmp.pdf "$out" 2>/dev/null
  rm -f tmp.pdf
}

download_html() {
  local url="$1" out="$2" idx="$3"
  local response html http_code content_type encoding

  response=$(curl -L -s -w "\n%{http_code}\n%{content_type}" -A "$UA" "$url")
  html=$(echo "$response" | sed '$d;$d')
  http_code=$(echo "$response" | tail -2 | head -1)
  content_type=$(echo "$response" | tail -1)

  HTTP_CODES[$idx]="$http_code"

  encoding=$(echo "$content_type" | grep -oE "charset=[^ ;]+" | cut -d= -f2)
  [ -z "$encoding" ] && encoding="UTF-8"
  ENCODINGS[$idx]="$encoding"

  echo "$html" > "temp_${idx}.html"
  
  if [[ ! "$encoding" =~ [Uu][Tt][Ff]-?8 ]]; then
    lynx -dump -nolist "temp_${idx}.html" 2>/dev/null | iconv -f "$encoding" -t "UTF-8" > "$out" 2>/dev/null || \
    lynx -dump -nolist "temp_${idx}.html" 2>/dev/null > "$out"
  else
    lynx -dump -nolist "temp_${idx}.html" 2>/dev/null > "$out"
  fi
  
  sed -i 's/[[:space:]]\+/ /g' "$out"
  
  rm -f "temp_${idx}.html"
}

extract_contexts() {
  grep -o -E ".{0,${CONTEXT_SIZE}}(${MOTIFS}).{0,${CONTEXT_SIZE}}" "$1" \
    > "$2" || > "$2"
}

i=1

echo "Début de l'analyse pour '$LANGUE'..."

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  line=$(clean_line "$raw_line")
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  url=$(extract_url "$line")
  [ -z "$url" ] && continue

  echo "→ [$LANGUE-$i] $url"

  DUMP="dumps-text/${LANGUE}-${i}.txt"
  ASP="aspirations/${LANGUE}-${i}.html"
  CTX="contextes/${LANGUE}-${i}.txt"

  if [[ "$url" =~ \.pdf$ ]]; then
    download_pdf "$url" "$DUMP" "$i"
  else
    download_html "$url" "$DUMP" "$i"
  fi

  if [ ! -s "$DUMP" ]; then
    echo "Aucun texte extrait"
    HTTP_CODES[$i]="Erreur"
    > "$ASP"
    > "$CTX"
    i=$((i+1))
    continue
  fi

  extract_contexts "$DUMP" "$CTX"

  {
    echo "<!DOCTYPE html><html lang='pt'><meta charset='UTF-8'><body>"
    echo "<h2>Source : <a href='$url'>$url</a></h2>"
    grep -E "$MOTIFS" "$DUMP" | sed 's/^/<p>/;s/$/<\/p>/' \
      || echo "<p>Aucune occurrence</p>"
    echo "</body></html>"
  } > "$ASP"

  i=$((i+1))
done < "$URL_FILE"

echo " $((i-1)) URLs traitées"

CONCORDANCE_FILE="concordances/${LANGUE}-concordances.html"

{
echo "<!DOCTYPE html>"
echo "<html><meta charset='UTF-8'>"
echo "<head><style>"
echo "body { font-family: sans-serif; margin: 20px; }"
echo "h1 { border-bottom: 2px solid #4CAF50; padding-bottom: 5px; }"
echo "h2 { margin-top: 30px; color: #333; }"
echo "table { width: 100%; border-collapse: collapse; margin: 10px 0; }"
echo "td { border: 1px solid #ddd; padding: 8px; }"
echo ".left { text-align: right; width: 45%; color: #444; }"
echo ".motif { text-align: center; width: 10%; font-weight: bold; background: #ffcccc; }"
echo ".right { text-align: left; width: 45%; color: #444; }"
echo ".source { font-size: 12px; color: #777; margin-bottom: 15px; }"
echo "</style></head><body>"

echo "<h1>Concordances — ${LANGUE}</h1>"
echo "<p><strong>Motif unique :</strong> coração (corações)</p>"
echo "<p><strong>Variantes inclusas :</strong> coraçao, coraçaõ, corações, coraçoes</p>"
echo "<p><strong>Contexte :</strong> ±${CONTEXT_SIZE} caractères</p>"

doc_num=1

for idx in $(seq 1 $((i-1))); do
  ctx="contextes/${LANGUE}-${idx}.txt"
  dump="dumps-text/${LANGUE}-${idx}.txt"

  [ ! -s "$ctx" ] && continue

  url=$(sed -n "${idx}p" "$URL_FILE" | grep -oE '^https?://[^[:space:]]+')
  [ -z "$url" ] && url="URL inconnue"

  occ=$(wc -l < "$ctx" | tr -d ' ')
  [ "$occ" -eq 0 ] && continue

  echo "<h2>Document $doc_num — $occ occurrence(s) de 'coração'</h2>"
  echo "<div class='source'>Source : <a href='$url' target='_blank'>$url</a></div>"

  while IFS= read -r line; do
    motif=$(echo "$line" | grep -oE "$MOTIFS" | head -1)
    [ -z "$motif" ] && continue

    left=$(echo "$line" | sed "s/${motif}.*//")
    right=$(echo "$line" | sed "s/.*${motif}//")

    echo "<table><tr>"
    echo "<td class='left'>$left</td>"
    echo "<td class='motif'>$motif</td>"
    echo "<td class='right'>$right</td>"
    echo "</tr></table>"
  done < "$ctx"

  doc_num=$((doc_num+1))
done

echo "</body></html>"
} > "$CONCORDANCE_FILE"

echo "✓ Concordances générées : $CONCORDANCE_FILE"

OUT="tableaux/${LANGUE}.html"
CONCORDANCE="../concordances/${LANGUE}-concordances.html"

{
echo "<!DOCTYPE html>"
echo "<html><meta charset='UTF-8'>"
echo "<head><style>"
echo "table { border-collapse: collapse; width: 100%; margin-top: 20px; }"
echo "th, td { border: 1px solid #ccc; padding: 8px; }"
echo "th { background: #4CAF50; color: white; }"
echo "tr:nth-child(even) { background: #f2f2f2; }"
echo ".center { text-align: center; }"
echo ".url { max-width: 400px; word-wrap: break-word; }"
echo ".count { font-weight: bold; color: #d32f2f; }"
echo "</style></head><body>"

echo "<h1>Tableau — ${LANGUE}</h1>"
echo "<p style='font-size:18px;'> <a href='$CONCORDANCE' target='_blank'><strong>📊 Voir les concordances de 'coração'</strong></a></p>"

echo "<table>"
echo "<tr>
<th class='center'>#</th>
<th>URL</th>
<th class='center'>HTTP</th>
<th class='center'>Encodage</th>
<th class='center'>Occurrences<br>coração</th>
</tr>"

for idx in $(seq 1 $((i-1))); do
  url=$(sed -n "${idx}p" "$URL_FILE" | grep -oE '^https?://[^[:space:]]+')
  [ -z "$url" ] && continue

  dump="dumps-text/${LANGUE}-${idx}.txt"

  count=0
  if [ -f "$dump" ]; then
    count=$(grep -oi "cora(c|ç)(ã|a)o|cora(c|ç)(õ|o)es" "$dump" 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "<tr>
<td class='center'>$idx</td>
<td class='url'><a href='$url' target='_blank'>$url</a></td>
<td class='center'>${HTTP_CODES[$idx]:-N/A}</td>
<td class='center'>${ENCODINGS[$idx]:-N/A}</td>
<td class='center'><span class='count'>$count</span></td>
</tr>"
done

echo "</table>"

echo "<div style='margin-top: 30px; padding: 15px; background: #f5f5f5;'>"
echo "<h3>Motif recherché :</h3>"
echo "<p><strong>coração</strong> (et pluriel <strong>corações</strong>)</p>"
echo "<p><em>Variantes incluses :</em> coraçao, coraçaõ, coraçoes, coraçõe</p>"
echo "</div>"

echo "</body></html>"
} > "$OUT"

echo "Tableau HTML généré : $OUT"