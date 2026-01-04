import numpy as np
from wordcloud import WordCloud
import matplotlib.pyplot as plt
from PIL import Image

mask = np.array(Image.open("heart_mask.png"))
mask = 255 - mask

frequencies = {}
with open("/Users/prune/Downloads/projet_encadre/projetfinal/URLs/cooccurrentsjp.txt", encoding="utf-8") as f:
    next(f)  
    
    for line in f:
        parts = line.strip().split("\t")
        
        if len(parts) >= 6:
            token = parts[0]
            cofreq = int(parts[4])
            frequencies[token] = cofreq

font_path = "/System/Library/Fonts/PingFang.ttc"

stop_tokens = {
    "あそこ", "あっ", "あの", "あのかた", "あの人", "あり", "あります", "ある", "あれ",
    "い", "いう", "います", "いる", "う", "うち", "え", "お", "および", "おり", "おります",
    "か", "かつて", "から", "が", "き", "ここ", "こちら", "こと", "この", "これ", "これら",
    "さ", "さらに", "し", "しかし", "する", "ず", "せ", "せる", "そこ", "そして", "その",
    "その他", "その後", "それ", "それぞれ", "それで", "た", "ただし", "たち", "ため",
    "たり", "だ", "だっ", "だれ", "つ", "て", "で", "でき", "できる", "です", "では",
    "でも", "と", "という", "といった", "とき", "ところ", "として", "とともに", "とも",
    "と共に", "どこ", "どの", "な", "ない", "なお", "なかっ", "ながら", "なく", "なっ",
    "など", "なに", "なら", "なり", "なる", "なん", "に", "において", "における",
    "について", "にて", "によって", "により", "による", "に対して", "に対する",
    "に関する", "の", "ので", "のみ", "は", "ば", "へ", "ほか", "ほとんど", "ほど",
    "ます", "また", "または", "まで", "も", "もの", "ものの", "や", "よう", "より",
    "ら", "られ", "られる", "れ", "れる", "を", "ん"
    "、", "。", "，", "（", "）", "(", ")", "「", "」", "『", "』", "【", "】",
    "・", "…", "―", "－", "—", ",", ".", "!", "?", "；", "：", "003", "e", "u"
}

TARGETS = ["心", "中心", "心臓"]
max_freq = max(frequencies.values()) if frequencies else 1
for t in TARGETS:
    frequencies[t] = max_freq * 2

frequencies = {
    tok: freq
    for tok, freq in frequencies.items()
    if tok not in stop_tokens
}

wc = WordCloud(
    font_path=font_path,
    mask=mask,
    background_color="white",
    min_font_size=10,
    max_words=200
)

wc.generate_from_frequencies(frequencies)

plt.figure(figsize=(12, 10))
plt.imshow(wc, interpolation="bilinear")
plt.axis("off")
plt.tight_layout(pad=0)
plt.show()

# Sauvegarder (optionnel)
wc.to_file("wordcloud_heart.png")