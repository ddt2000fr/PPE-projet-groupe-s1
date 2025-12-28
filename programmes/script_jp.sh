#!/usr/bin/env bash

#SECURISATION
set -o nounset
set -o pipefail

# VÉRIFICATIONS

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 fichier_urls langue"
  exit 1
fi

URL_FILE="$1"
LANGUE="$2"

MOTIFS="心臓|中心|心"
CONTEXT_SIZE=30
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"

export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

[ ! -f "$URL_FILE" ] && { echo "Fichier introuvable : $URL_FILE"; exit 1; }

for cmd in curl pup pdftotext; do
  command -v "$cmd" >/dev/null || { echo "Commande manquante : $cmd"; exit 1; }
done

mkdir -p dump-text aspirations contextes tableaux concordances

# MÉTADONNÉES PAR DOCUMENT

declare -A HTTP_CODES
declare -A ENCODINGS

# FONCTIONS

clean_line() {
  echo "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

extract_url() {
  echo "$1" | grep -oE '^https?://[^[:space:]　]+'
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

  echo "$html" \
    | pup 'article text{}, main text{}, body text{}' \
    | sed '/window\./d;/INIT_DATA/d;/function(/d' \
    | sed 's/[[:space:]]\+/ /g' \
    > "$out"
}

generate_aspiration() {
  local url="$1" dump="$2" out="$3"

  {
    echo "<!DOCTYPE html><html lang='ja'><meta charset='UTF-8'><body>"
    echo "<h2>Source : <a href='$url'>$url</a></h2>"
    grep -E "$MOTIFS" "$dump" | sed 's/^/<p>/;s/$/<\/p>/' \
      || echo "<p>Aucune occurrence</p>"
    echo "</body></html>"
  } > "$out"
}

extract_contexts() {
  grep -o -E ".{0,${CONTEXT_SIZE}}(${MOTIFS}).{0,${CONTEXT_SIZE}}" "$1" \
    > "$2" || > "$2"
}

# TRAITEMENT DES URLS

i=1

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  line=$(clean_line "$raw_line")
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  url=$(extract_url "$line")
  [ -z "$url" ] && continue

  echo "→ [$LANGUE-$i] $url"

  DUMP="dump-text/${LANGUE}-${i}.txt"
  ASP="aspirations/${LANGUE}-${i}.html"
  CTX="contextes/${LANGUE}-${i}.txt"

  if [[ "$url" =~ \.pdf$ ]]; then
    download_pdf "$url" "$DUMP" "$i"
  else
    download_html "$url" "$DUMP" "$i"
  fi

  if [ ! -s "$DUMP" ]; then
    echo "  ⚠ Aucun texte extrait"
    HTTP_CODES[$i]="Erreur"
    > "$ASP"
    > "$CTX"
    i=$((i+1))
    continue
  fi

  generate_aspiration "$url" "$DUMP" "$ASP"
  extract_contexts "$DUMP" "$CTX"

  i=$((i+1))
done < "$URL_FILE"

# CONCORDANCES

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
echo ".motif { text-align: center; width: 10%; font-weight: bold; background: #fff9c4; }"
echo ".right { text-align: left; width: 45%; color: #444; }"
echo ".source { font-size: 12px; color: #777; margin-bottom: 15px; }"
echo "</style></head><body>"

echo "<h1>Concordances — ${LANGUE}</h1>"
echo "<p><strong>Motifs :</strong> $(echo "$MOTIFS" | sed 's/|/ | /g')</p>"
echo "<p><strong>Contexte :</strong> ±${CONTEXT_SIZE} caractères</p>"

doc_num=1

for idx in $(seq 1 $((i-1))); do
  ctx="contextes/${LANGUE}-${idx}.txt"
  dump="dump-text/${LANGUE}-${idx}.txt"

  [ ! -s "$ctx" ] && continue

  url=$(sed -n "${idx}p" "$URL_FILE" | grep -oE '^https?://[^[:space:]　]+')
  [ -z "$url" ] && url="URL inconnue"

  occ=$(wc -l < "$ctx" | tr -d ' ')
  [ "$occ" -eq 0 ] && continue

  echo "<h2>Document $doc_num — $occ occurrence(s)</h2>"
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

# TABLEAU HTML FINAL

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
echo "a { text-decoration: none; color: #0066cc; }"
echo "a:hover { text-decoration: underline; }"
echo "</style></head><body>"

echo "<h1>Tableau — ${LANGUE}</h1>"
echo "<p style='font-size:18px;'>📊 <a href='$CONCORDANCE' target='_blank'><strong>Voir les concordances</strong></a></p>"

echo "<table>"
echo "<tr>
<th class='center'>#</th>
<th>URL</th>
<th class='center'>HTTP</th>
<th class='center'>Encodage</th>
<th class='center'>Occurrences</th>
<th class='center'>Dump TXT</th>
<th class='center'>HTML</th>
<th class='center'>Contextes</th>
</tr>"

for idx in $(seq 1 $((i-1))); do
  url=$(sed -n "${idx}p" "$URL_FILE" | grep -oE '^https?://[^[:space:]　]+')
  [ -z "$url" ] && continue

  dump="dump-text/${LANGUE}-${idx}.txt"
  asp="aspirations/${LANGUE}-${idx}.html"
  ctx="contextes/${LANGUE}-${idx}.txt"

  occ=0
  [ -f "$dump" ] && occ=$(grep -o -E "$MOTIFS" "$dump" 2>/dev/null | wc -l | tr -d ' ')

  echo "<tr>
<td class='center'>$idx</td>
<td class='url'><a href='$url' target='_blank'>$url</a></td>
<td class='center'>${HTTP_CODES[$idx]:-N/A}</td>
<td class='center'>${ENCODINGS[$idx]:-N/A}</td>
<td class='center'><strong>$occ</strong></td>
<td class='center'><a href='../$dump' target='_blank'>TXT</a></td>
<td class='center'><a href='../$asp' target='_blank'>HTML</a></td>
<td class='center'><a href='../$ctx' target='_blank'>CTX</a></td>
</tr>"
done

echo "</table>"
echo "</body></html>"
} > "$OUT"

echo "Tableau HTML généré : $OUT"

