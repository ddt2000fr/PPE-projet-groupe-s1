if [ $# -ne 2 ]
then
        echo "Le scripte attend exactement deux arguments: le chemin verl le fichier d'URL et le chemin vers le fichier de sortie"
        exit
fi

FICHIER_URL=$1
FICHIER_SORTIE=$2

echo -e '<!DOCTYPE html>
<html data-theme="light">

<head>
    <title> Сердце </title>
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
                <p class="title">Сердце</p>
                <p class="subtitle">Tableau des URLs pour le russe</p>
            </div>
        </div>
    </section>

    <section class="section has-background-white-ter">
        <div class="container is-max-desktop">
            <div class="content">
                <p class="title has-text-pink">Tableau russe</p>
                <p class="subtitle">📊 <a href="../concordances/concordance_ru.html" target="_blank"><strong>Voir les concordances</strong></a></p>
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
                    <tbody>' > $FICHIER_SORTIE

lineno=1
while read -r line;
do
    curl -i -L $line -o "../aspirations/ru-${lineno}.html"
    HTTP_code=$(egrep "^HTTP\/[0-9.]+\s+([0-9]{3})" "../aspirations/ru-${lineno}.html" | sed -E 's/^HTTP\/[0-9.]+ ([0-9]{3}).*/\1/')
    encoding=$(head -n 13 "../aspirations/ru-${lineno}.html" | egrep -oi "charset=["'\''']?[A-Za-z0-9_\-]+["'\'' ]?" | sed -E 's/.*charset=["'\'' ]?([^"'\'' >]+).*/\1/i')
    if [[ $encoding =~ (UTF|utf)-8 ]]
    then
        lynx -dump -nolist "$line" > "../dumps-text/ru-${lineno}.txt"
        egrep 'сердц(е|а|у|ем|ец|цами|цах)' "../dumps-text/ru-${lineno}.txt" | sed -E 's/\[[0-9]+\]//g' > "../contextes/ru-${lineno}.txt"
        words=$(egrep -o 'сердц(е|а|у|ем|ец|цами|цах)' "../dumps-text/ru-${lineno}.txt" | wc -l)
    else
        encoding=$(file -i "../aspirations/ru-${lineno}.html" | sed -n 's/.*charset=//p')
        echo $encoding
        lynx -dump -nolist "../aspirations/ru-${lineno}.html" | iconv -f "$encoding" -t "UTF-8" > "../dumps-text/ru-${lineno}.txt"
        egrep 'сердц(е|а|у|ем|ец|цами|цах)' "../dumps-text/ru-${lineno}.txt" > "../contextes/ru-${lineno}.txt"
        words=$(egrep -o 'сердц(е|а|у|ем|ец|цами|цах)' "../dumps-text/ru-${lineno}.txt" | wc -l)
    fi
    echo -e "<tr>\n<td class='has-text-centered'>${lineno}</td><td style='max-width: 400px; word-wrap: break-word;'><a href='${line}' target='_blank'>${line}</a></td><td class='has-text-centered'>${HTTP_code}</td><td class='has-text-centered'>${encoding}</td><td class='has-text-centered'>${words}</td><td class='has-text-centered'><a href='../aspirations/ru-${lineno}.html' target='_blank'>HTML</a></td><td class='has-text-centered'><a href='../dumps-text/ru-${lineno}.txt' target='_blank'>TXT</a></td><td class='has-text-centered'><a href='../contextes/ru-${lineno}.txt'  target='_blank'>CTX</a></td>\n</tr>" >> $FICHIER_SORTIE;
    lineno=$(expr $lineno + 1)
done < $FICHIER_URL

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
</html>' >> $FICHIER_SORTIE

echo -e '<!DOCTYPE html>
<html><meta charset="UTF-8">
<head><style>
body { font-family: sans-serif; margin: 20px; }
h1 { border-bottom: 2px solid #4CAF50; padding-bottom: 5px; }
h2 { margin-top: 30px; color: #333; }
table { width: 100%; border-collapse: collapse; margin: 10px 0; }
td { border: 1px solid #ddd; padding: 8px; }
.left { text-align: right; width: 45%; color: #444; }
.motif { text-align: center; width: 10%; font-weight: bold; background: #fff9c4; }
.right { text-align: left; width: 45%; color: #444; }
.source { font-size: 12px; color: #777; margin-bottom: 15px; }
</style></head><body>
<h1>Concordances — russe</h1>
<p><strong>Motifs :</strong> сердц(е|а|у|ем|ец|цами|цах)</p>
<p><strong>Contexte :</strong> une ligne</p>' > "../concordances/concordance_ru.html"

fileno=1

for file in /home/tupikina/Documents/Cours/Plurital/Trial/contextes/ru*; do
    [[ -f "$file" ]] || continue
    occurrencesno=$(wc -l < "$file")
    echo -e "<h2>Document ${fileno} — ${occurrencesno} occurrences</h2>" >> "../concordances/concordance_ru.html"

    while IFS= read -r line; do

        left=$(echo "$line" | sed -E 's/(.*)(сердц(е|а|у|ем|ец|цами|цах)).*/\1/')
        word=$(echo "$line" | sed -E 's/.*(сердц(е|а|у|ем|ец|цами|цах)).*/\1/')
        right=$(echo "$line" | sed -E 's/.*сердц(е|а|у|ем|ец|цами|цах)(.*)/\2/')
        echo -e "<table><tr><td class='left'>${left}</td><td class='motif'>${word}</td><td class='right'>${right}</td></tr></table>" >> "../concordances/concordance_ru.html"
    done < $file
    fileno=$(expr $fileno + 1)
done

echo -e '</body></html>' >> "../concordances/concordance_ru.html"
