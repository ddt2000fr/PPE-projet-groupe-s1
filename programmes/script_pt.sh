#!/bin/bash

if [ $# -ne 2 ]
then
        echo "Le scripte attend exactement deux arguments: le chemin verl le fichier d'URL et le chemin vers le fichier de sortie"
        exit
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

FICHIER_URL=$1
FICHIER_SORTIE="$PROJECT_DIR/tableaux/$2"

mkdir -p "$PROJECT_DIR/aspirations" "$PROJECT_DIR/dumps-text" "$PROJECT_DIR/contextes" "$PROJECT_DIR/concordances"

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
                    <h1 class="subtitle"><a href=".">coeur</a></h1>
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
        <span class="heart-float" style="top:10%; left:5%; font-size:1rem;">♡</span>
        <span class="heart-float" style="top:30%; left:25%; font-size:1.2rem;">♡</span>
        <span class="heart-float" style="top:50%; left:60%; font-size:0.9rem;">♡</span>
        <span class="heart-float" style="top:70%; left:40%; font-size:1.1rem;">♡</span>
        <span class="heart-float" style="top:80%; left:75%; font-size:0.8rem;">♡</span>
        <div class="container is-max-desktop">
            <div class="hero-body">
                <p class="title">coração</p>
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
                    <tbody>' > "$FICHIER_SORTIE"

lineno=1
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

while read -r line || [ -n "$line" ];
do
    line=$(echo "$line" | tr -d '\r' | xargs)
    [[ -z "$line" ]] && continue

    HTTP_code=$(curl -L -k -s -A "$UA" --max-time 15 "$line" \
         -o "$PROJECT_DIR/aspirations/pt-${lineno}.html" \
         -w "%{http_code}")

    [ -z "$HTTP_code" ] && HTTP_code="Erreur"

    encoding=$(grep -oiP 'charset=["'\'']?\K[A-Za-z0-9_\-]+' "$PROJECT_DIR/aspirations/pt-${lineno}.html" | head -n 1 | tr '[:lower:]' '[:upper:]')
    [ -z "$encoding" ] && encoding="UTF-8"

if [[ "$HTTP_code" == "200" ]]; then
        lynx -dump -nolist "$PROJECT_DIR/aspirations/pt-${lineno}.html" | \
            sed -n '/^References$/q;p' | \
            sed -E 's/\[[0-9]+\]//g' | \
            sed 's/(BUTTON)//g' | \
            grep -viE 'oEmbed|JSON|XML|@|{[[:space:]]*"@context"|http' \
            > "$PROJECT_DIR/dumps-text/pt-${lineno}.txt" 2>/dev/null
    
        grep -iE 'coração|coracao|corações|coracoes' "$PROJECT_DIR/dumps-text/pt-${lineno}.txt" | \
            grep -viE 'oEmbed|JSON|XML|{[[:space:]]*"' | \
            sed -E 's/^[[:space:]]+//' > "$PROJECT_DIR/contextes/pt-${lineno}.txt"
            
        words=$(grep -oiE 'coração|coracao|corações|coracoes' "$PROJECT_DIR/dumps-text/pt-${lineno}.txt" | wc -l)
    else
        words=0
        echo "" > "$PROJECT_DIR/contextes/pt-${lineno}.txt"
    fi

    echo -e "<tr>\n<td class='has-text-centered'>${lineno}</td><td style='max-width: 400px; word-wrap: break-word;'><a href='${line}' target='_blank'>${line}</a></td><td class='has-text-centered'>${HTTP_code}</td><td class='has-text-centered'>${encoding}</td><td class='has-text-centered'>${words}</td><td class='has-text-centered'><a href='../aspirations/pt-${lineno}.html' target='_blank'>HTML</a></td><td class='has-text-centered'><a href='../dumps-text/pt-${lineno}.txt' target='_blank'>TXT</a></td><td class='has-text-centered'><a href='../contextes/pt-${lineno}.txt'  target='_blank'>CTX</a></td>\n</tr>" >> "$FICHIER_SORTIE"
    lineno=$((lineno + 1))
done < "$FICHIER_URL"

echo -e '</tbody>
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
</html>' >> "$FICHIER_SORTIE"

echo -e '<!DOCTYPE html>
<html><meta charset="UTF-8">
<head><style>
body { font-family: sans-serif; margin: 20px; }
h1 { border-bottom: 2px solid #4CAF50; padding-bottom: 5px; }
h2 { margin-top: 30px; color: #333; }
table { width: 100%; border-collapse: collapse; margin: 10px 0; table-layout: fixed; }
td { border: 1px solid #ddd; padding: 8px; overflow: hidden; }
.left { text-align: right; width: 45%; color: #444; }
.motif { text-align: center; width: 10%; font-weight: bold; background: #fff9c4; }
.right { text-align: left; width: 45%; color: #444; }
</style></head><body>
<h1>Concordances — portugais</h1>
<p><strong>Motifs :</strong> coração|coracao|corações|coracoes</p>
<p><strong>Contexte :</strong> une ligne</p>' > "$PROJECT_DIR/concordances/concordance_pt.html"

fileno=1
for file in $(ls "$PROJECT_DIR/contextes/pt-"* | sort -V); do
    [[ -f "$file" ]] || continue
    occurrencesno=$(wc -l < "$file")
    [ "$occurrencesno" -eq 0 ] && continue

    echo -e "<h2>Document ${fileno} — ${occurrencesno} occurrences</h2>" >> "$PROJECT_DIR/concordances/concordance_pt.html"

    while IFS= read -r line; do
        left=$(echo "$line" | sed -E 's/^(.*)(coração|coracao|corações|coracoes).*/\1/i')
        word=$(echo "$line" | grep -oiE 'coração|coracao|corações|coracoes' | head -n 1)
        right=$(echo "$line" | sed -E 's/.*(coração|coracao|corações|coracoes)(.*)/\2/i')
        
        echo -e "<table><tr><td class='left'>${left}</td><td class='motif'>${word}</td><td class='right'>${right}</td></tr></table>" >> "$PROJECT_DIR/concordances/concordance_pt.html"
    done < "$file"
    fileno=$((fileno + 1))
done

echo -e '</body></html>' >> "$PROJECT_DIR/concordances/concordance_pt.html"