#!/usr/bin/env bash

set -o nounset
set -o pipefail

# Vérifie les arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 fichier_urls langue"
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
CONC_DIR="$ROOT_DIR/concordances"

# Vérifications supplémentaires
[ -z "$LANGUE" ] && { echo "Erreur: Langue non spécifiée"; exit 1; }
[ -z "$ROOT_DIR" ] && { echo "Erreur: Répertoire racine non trouvé"; exit 1; }

echo "Configuration:"
echo "  ROOT_DIR: $ROOT_DIR"
echo "  LANGUE: $LANGUE"
echo "  TBL_DIR: $TBL_DIR"

mkdir -p "$DUMP_DIR" "$ASP_DIR" "$CTX_DIR" "$TBL_DIR" "$CONC_DIR"
CONC_UNICO="$CONC_DIR/concordance_pt.html"
echo "<html><head><meta charset='utf-8'><style>
body { font-family: sans-serif; margin: 20px; }
h1 { border-bottom: 2px solid #333; padding-bottom: 5px; }
table { width: 100%; border-collapse: collapse; margin: 10px 0; }
td { border: 1px solid #ddd; padding: 8px; }
.left { text-align: right; width: 45%; color: #444; }
.motif { text-align: center; width: 10%; font-weight: bold; background: #fff9c4; color: #e91e63; }
.right { text-align: left; width: 45%; color: #444; }
</style></head><body>
<h1>Concordances - portugais</h1>
<p><strong>Motifs :</strong>coração|coracao|corações|coracoes</p>
<p><strong>Contexte :</strong> une ligne</p>" > "$CONC_UNICO"

# Cherche le mot et toutes ses variations
MOTIFS="(coração|coracao|corações|coracoes)"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

for cmd in curl pup; do
  command -v "$cmd" >/dev/null || { echo "Erreur: Commande '$cmd' manquante"; exit 1; }
done

declare -A TAB_URLS
declare -A TAB_HTTP
declare -A TAB_ENC
declare -A TAB_TOKENS
declare -A TAB_COMPTE

# Fonctions
create_context_txt() {
    local idx="$1"
    local word="$2"
    local dump_path="$3"
    local out_path="$CTX_DIR/${LANGUE}-${idx}.txt"
    
    > "$out_path"
    grep -o -E ".{0,40}\b($word)\b.{0,40}" "$dump_path" > "$out_path" 2>/dev/null
}

download_pdf() {
    local url="$1" out="$2"
    curl -k -L -s -A "$UA" "$url" -o temp.pdf 2>/dev/null
    if [ -f temp.pdf ]; then
        pdftotext -layout temp.pdf "$out" 2>/dev/null
        rm -f temp.pdf
        return 0
    fi
    return 1
}

append_to_concordance() {
    local idx="$1"
    local word="$2"
    local url="$3"
    local dump_path="$4"
    local nb_occ="$5"

    echo "<h2>Document $idx — $nb_occ occurrences.</h2>" >> "$CONC_UNICO"
    grep -o -E ".{0,40}\b($word)\b.{0,40}" "$dump_path" | while read -r line_ctx; do
        left=$(echo "$line_ctx" | sed -E "s/\b($word)\b.*//")
        word_match=$(echo "$line_ctx" | grep -oE "\b($word)\b" | head -1)
        right=$(echo "$line_ctx" | sed -E "s/.*\b($word)\b//")
        echo "<table><tr><td class='left'>${left:-&nbsp;}</td><td class='motif'>$word_match</td><td class='right'>${right:-&nbsp;}</td></tr></table>" >> "$CONC_UNICO"
    done
}

# TRAITEMENT DES URLS
i=1

while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  url=$(echo "$line" | grep -oE 'https?://[^[:space:]]+' | head -1)
  [ -z "$url" ] && continue

echo -ne "Analyse de $i... \r"

  TAB_URLS[$i]="$url"

  # Chemin des fichiers
  DUMP_PATH="$DUMP_DIR/${LANGUE}-${i}.txt"
  ASP_PATH="$ASP_DIR/${LANGUE}-${i}.html"
  CTX_TXT_PATH="$CTX_DIR/${LANGUE}-${i}.txt"

  # Pour traiter les PDFs
  if [[ "$url" =~ \.pdf$ ]]; then
    echo " PDF detecté "
    if download_pdf "$url" "$DUMP_PATH"; then
        TAB_HTTP[$i]="200"
        TAB_ENC[$i]="PDF"
    else
        TAB_HTTP[$i]="000"
        TAB_ENC[$i]="ERREUR"
        > "$DUMP_PATH"
    fi
 fi
 
# Telecharge et fais l'extraction du texte
response=$(curl -k -L -s -w "\n%{http_code}\n%{content_type}" -A "$UA" --connect-timeout 10 "$url" 2>/dev/null)
html=$(echo "$response" | sed '$d;$d')
http_code=$(echo "$response" | tail -2 | head -1)
content_type=$(echo "$response" | tail -1)

# Mettre le code a jour
TAB_HTTP[$i]="$http_code"

# Pour l'erreur en code HTTP
if [[ "$http_code" -ge 400 ]]; then
   echo "Page avec erreur HTTP ($http_code) - le traitement sera limité."
   TAB_TOKENS[$i]=0
   TAB_COMPTE[$i]=0
fi

# Extraction encoding
charset=$(echo "$content_type" | grep -oE "charset=[^ ;]+" | cut -d= -f2)
[ -z "$charset" ] && charset="UTF-8"
TAB_ENC[$i]=$(echo "$charset" | tr '[:lower:]' '[:upper:]')

# Texte plus clean avec pup
texte=$(echo "$html" | pup 'article text{}, main text{}, body text{}' | sed '/window\./d;/INIT_DATA/d;/function(/d' | sed 's/[[:space:]]\+/ /g')

if echo "$texte" | grep -q -P "Ã[¡§³´µ·¸¹º]|Ã[€-¿]"; then
    if echo "$texte" | iconv -f ISO-8859-1 -t UTF-8 2>/dev/null > "$DUMP_PATH"; then
        echo "  Convertido: ISO-8859-1 → UTF-8"
    elif echo "$texte" | iconv -f WINDOWS-1252 -t UTF-8 2>/dev/null > "$DUMP_PATH"; then
        echo "  Convertido: WINDOWS-1252 → UTF-8"
    else
        echo "$texte" > "$DUMP_PATH"
    fi
else
    echo "$texte" > "$DUMP_PATH"
fi

# Compter les tokens dans le dump textuel
  tr -d '\000' < "$DUMP_PATH" > "${DUMP_PATH}.tmp" && mv "${DUMP_PATH}.tmp" "$DUMP_PATH"
  tokens=$(cat "$DUMP_PATH" 2>/dev/null | wc -w || echo "0")
  TAB_TOKENS[$i]="$tokens"
  
  # Compter les occurrences du mot
  compte=$(grep -oiP "\b($MOTIFS)\b" "$DUMP_PATH" 2>/dev/null | wc -l || echo "0")
  TAB_COMPTE[$i]="$compte"

  create_context_txt "$i" "$MOTIFS" "$DUMP_PATH"
  append_to_concordance "$i" "$MOTIFS" "$url" "$DUMP_PATH" "$compte"

  # Créer l'aspiration avec les occurrences
  {
    echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Aspiration $i - $LANGUE</title></head><body>"
    echo "<h2>Source : <a href='$url'>$url</a></h2>"
    echo "<p><strong>Occurrences trouvées :</strong> $compte</p><hr>"
    grep -Ei "$MOTIFS" "$DUMP_PATH" 2>/dev/null | sed 's/^/<p>/;s/$/<\/p>/' || echo "<p>Aucune occurrence trouvée</p>"
    echo "</body></html>"
  } > "$ASP_PATH"

  i=$((i+1))
done < "$URL_FILE"

# Vérification finale avant génération
if [ -z "$TBL_DIR" ] || [ -z "$LANGUE" ]; then
    echo "ERREUR: TBL_DIR ou LANGUE est vide!" >&2
    echo "TBL_DIR: '$TBL_DIR'" >&2
    echo "LANGUE: '$LANGUE'" >&2
    exit 1
fi

# generation du tableau
OUT="$TBL_DIR/${LANGUE}.html"
echo "Génération du tableau: $OUT"

{
echo -e '<!DOCTYPE html>
<html data-theme="light">

<head>
    <title> Coração </title>
    <link rel="stylesheet" href="../css/main.css" />
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
</head>

<body>
    <nav class="navbar has-background-light">
        <div class="container is-max-desktop">
            <div class="navbar-brand">
                <div class="navbar-item">
                    <a role="button" class="navbar-burger" data-target="navMenu" aria-label="menu"
                        aria-expanded="false">
                        <span aria-hidden="true"></span>
                        <span aria-hidden="true"></span>
                        <span aria-hidden="true"></span>
                        <span aria-hidden="true"></span>
                    </a>
                    <h1 class="subtitle"><a href="../">coeur</a></h1>
                </div>
            </div>

            <div class="navbar-end navbar-menu" id="navMenu">
                <a class="navbar-item" href="../index.html">
                    Présentation
                </a>
                <a class="navbar-item" href="../tableaux/tableaux.html">
                    Tableaux
                </a>
                <a class="navbar-item" href="../concordances/concordancier.html">
                    Concordancier
                </a>
                <a class="navbar-item" href="../programmes/modedemplois.html">
                    Mode d&apos;emploi
                </a>
                <a class="navbar-item" href="../tableaux/analyse_textuelle.html">
                    Analyse textuelle
                </a>
                <a class="navbar-item" href="https://github.com/ddt2000fr/PPE-projet-groupe-s1">
                    <img src="../assets/github.svg" width="20" />
                </a>
            </div>
        </div>
    </nav>

    <section class="hero heart-hero">
        <!-- Cœurs flottants -->
        <span class="heart-float" style="top:10%; left:5%; font-size:1rem;">♡</span>
        <span class="heart-float" style="top:30%; left:25%; font-size:1.2rem;">♡</span>
        <span class="heart-float" style="top:50%; left:60%; font-size:0.9rem;">♡</span>
        <span class="heart-float" style="top:70%; left:40%; font-size:1.1rem;">♡</span>
        <span class="heart-float" style="top:80%; left:75%; font-size:0.8rem;">♡</span>
        <div class="container is-max-desktop">
            <div class="hero-body">
                <p class="title">Coração</p>
                <p class="subtitle">Tableau des URLs pour le portugais</p>
            </div>
        </div>
    </section>

    <section class="section has-background-white-ter">
        <div class="container is-max-desktop">
            <div class="content">
                <p class="title has-text-pink">Tableau portugais</p>
                <p class="subtitle">📊 <a href="../concordances/concordance_pt.html" target="_blank"><strong>Voir les concordances</strong></a></p>
            </div>
        </div>
    </section>

    <section class="section">
        <div class="container is-max-desktop">
            <div class="table-container">
                <table class="table is-striped is-hoverable is-fullwidth">
                    <thead>
                        <tr>
                            <th class="has-text-centered">#</th>
                            <th>URL</th>
                            <th class="has-text-centered">HTTP</th>
                            <th class="has-text-centered">Encodage</th>
                            <th class="has-text-centered">Occurrences</th>
                            <th class="has-text-centered">HTML</th>
                            <th class="has-text-centered">Dump TXT</th>
                            <th class="has-text-centered">Contextes</th>
                        </tr>
                    </thead>
                    <tbody>'

for idx in $(seq 1 $((i-1))); do
    url_final="${TAB_URLS[$idx]}"
    [ -z "$url_final" ] && continue
    
    http_code="${TAB_HTTP[$idx]}"
    
    # Si c'est une erreur HTTP
    if [[ "$http_code" -ge 400 ]]; then
        echo "<tr>
            <td class='has-text-centered'>$idx</td>
            <td style='max-width: 400px; word-wrap: break-word;'><a href='$url_final' target='_blank'>$url_final</a></td>
            <td class='has-text-centered'>$http_code</td>
            <td colspan='5'>Erreur HTTP $http_code</td>
        </tr>"
        continue
    fi
    
    count="${TAB_COMPTE[$idx]:-0}"
    
    echo "<tr>
        <td class='has-text-centered'>$idx</td>
        <td style='max-width: 400px; word-wrap: break-word;'><a href='$url_final' target='_blank'>$url_final</a></td>
        <td class='has-text-centered'>${TAB_HTTP[$idx]}</td>
        <td class='has-text-centered'>${TAB_ENC[$idx]}</td>
        <td class='has-text-centered'>$count</td>
        <td class='has-text-centered'><a href='../aspirations/${LANGUE}-${idx}.html' target='_blank'>HTML</a></td>
        <td class='has-text-centered'><a href='../dumps-text/${LANGUE}-${idx}.txt' target='_blank'>TXT</a></td>
        <td class='has-text-centered'><a href='../contextes/${LANGUE}-${idx}.txt' target='_blank'>CTX</a></td>
    </tr>"
done

echo '</tbody>
                </table>
            </div>
        </div>
    </section>

    <script>
        document.addEventListener("DOMContentLoaded", () => {
            const $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll(".navbar-burger"), 0);
            $navbarBurgers.forEach(el => {
                el.addEventListener("click", () => {
                    const target = el.dataset.target;
                    const $target = document.getElementById(target);
                    el.classList.toggle("is-active");
                    $target.classList.toggle("is-active");
                });
            });
        });
    </script>

</body>
</html>'
} > "$OUT"
echo "</body></html>" >> "$CONC_UNICO"
    echo "Tableau généré avec succès: $OUT"
 