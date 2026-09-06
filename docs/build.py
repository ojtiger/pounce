#!/usr/bin/env python3
"""소개 페이지를 언어별로 찍어낸다.

문구만 아래 LANGS 에서 고치고 `python3 docs/build.py` 를 돌리면
index.html(한국어)과 en/ ja/ zh/ 가 같은 구조로 다시 만들어진다.
"""
import os, pathlib

SITE = "https://ojtiger.github.io/pounce/"
REPO = "https://github.com/ojtiger/pounce"
LATEST = REPO + "/releases/latest"
BREW = "brew install --cask ojtiger/tap/pounce"
VERSION = "0.3.0"

LANGS = {
  "ko": {
    "dir": "", "hreflang": "ko", "name": "한국어",
    "title": "맥 알림창 위치 변경 — Pounce",
    "desc": "macOS 알림창이 뜨는 위치를 화면 가운데로 옮기는 맥 앱. 우측 상단 알림 배너를 원하는 자리로 바꿉니다. 무료, 오픈소스, macOS 14 이상.",
    "ogdesc": "macOS 알림 배너를 화면 가운데로 옮기는 맥 앱. 무료, 오픈소스.",
    "h1": "맥 알림창 위치 변경",
    "lede": "맥 알림을 놓치지 않게, 원하는 자리로 옮겨 보여줍니다.",
    "labels": ["정보", "설치", "스크린샷", "질문"],
    "copy": "복사", "copied": "복사됨", "copyAria": "설치 명령 복사",
    "download": "직접 내려받기",
    "alt": "Pounce 설정 창. 미리보기 안에서 알림 카드가 화면 가운데에 표시되고, 아홉 자리 중 위치를 고르는 격자가 보입니다.",
    "schemaName": "맥 알림창 위치 변경",
    "schemaDesc": "macOS 알림 배너를 화면 가운데 등 원하는 위치로 옮겨 보여주는 맥 앱.",
    "faq": [
      ("맥 설정에서 알림창 위치 못 바꾸나요?",
       "못 바꿉니다. 애플이 오른쪽 위로 박아뒀고 설정에 그런 항목이 없습니다. 그래서 만들었습니다."),
      ("가운데에 뜨면 거슬리지 않나요?",
       "시간 지나면 알아서 사라집니다. 마우스를 올려두면 안 사라지고 기다립니다. 그래도 거슬리면 아래 가운데로 내리세요. 자리는 아홉 개 다 됩니다."),
      ("알림 내용이 밖으로 나가나요?",
       "안 나갑니다. 전부 이 맥 안에서 끝납니다. 밖으로 나가는 건 새 버전 나왔나 보는 것 하나뿐이고, 그것도 설정에서 끄면 됩니다."),
      ("어떤 맥에서 되나요?",
       "macOS 14 소노마부터. M 시리즈든 인텔이든 됩니다. macOS 26 에서는 시스템 유리를, 그 아래에서는 서리 유리를 씁니다."),
    ],
  },
  "en": {
    "dir": "en/", "hreflang": "en", "name": "English",
    "title": "Move macOS notifications where you want — Pounce",
    "desc": "A Mac app that moves macOS notification banners from the top-right corner to the center of your screen, or any of nine spots. Free, open source, macOS 14 and later.",
    "ogdesc": "A Mac app that moves macOS notification banners to the center of your screen. Free and open source.",
    "h1": "Move macOS notifications",
    "lede": "Notifications show up where you are actually looking, so you stop missing them.",
    "labels": ["About", "Install", "Screenshot", "FAQ"],
    "copy": "Copy", "copied": "Copied", "copyAria": "Copy the install command",
    "download": "Download directly",
    "alt": "The Pounce settings window. The preview shows a notification card in the middle of the screen, with a grid for picking one of nine positions.",
    "schemaName": "Pounce — move macOS notifications",
    "schemaDesc": "A Mac app that moves macOS notification banners to the center of the screen, or anywhere else you pick.",
    "faq": [
      ("Can I change the notification position in macOS settings?",
       "You cannot. Apple pins banners to the top right and there is no setting for it. That is why this app exists."),
      ("Is a card in the middle of the screen distracting?",
       "It leaves on its own after a few seconds, and it waits while your pointer is on it. If it still gets in the way, move it to the bottom center. There are nine spots."),
      ("Does anything leave my Mac?",
       "No. Everything happens on this Mac. The only outgoing request is the check for a new version, and you can turn that off."),
      ("Which Macs does it run on?",
       "macOS 14 Sonoma and later, Apple silicon and Intel alike. macOS 26 uses the system glass material, earlier versions frosted glass."),
    ],
  },
  "ja": {
    "dir": "ja/", "hreflang": "ja", "name": "日本語",
    "title": "Mac の通知の位置を変更 — Pounce",
    "desc": "Mac の通知バナーを右上から画面中央へ、または好きな位置へ移して表示する Mac アプリ。無料、オープンソース、macOS 14 以降。",
    "ogdesc": "Mac の通知バナーを画面中央へ移して表示する Mac アプリ。無料、オープンソース。",
    "h1": "Mac の通知の位置を変更",
    "lede": "通知を見逃さないように、目を向けている場所に表示します。",
    "labels": ["概要", "インストール", "スクリーンショット", "よくある質問"],
    "copy": "コピー", "copied": "コピーしました", "copyAria": "インストールコマンドをコピー",
    "download": "直接ダウンロード",
    "alt": "Pounce の設定ウインドウ。プレビューに画面中央の通知カードと、九か所から位置を選ぶグリッドが表示されている。",
    "schemaName": "Pounce — Mac の通知の位置を変更",
    "schemaDesc": "Mac の通知バナーを画面中央など好きな位置へ移して表示する Mac アプリ。",
    "faq": [
      ("Mac の設定で通知の位置を変えられませんか？",
       "変えられません。Apple がバナーを右上に固定していて、その設定項目がありません。そのために作りました。"),
      ("中央に出ると邪魔になりませんか？",
       "時間が経てば自動で消えます。ポインタを乗せている間は消えずに待ちます。それでも気になるなら下中央へ。位置は九か所から選べます。"),
      ("通知の内容が外部に送信されますか？",
       "されません。すべてこの Mac の中で完結します。外に出るのは新しいバージョンの確認だけで、それも設定でオフにできます。"),
      ("どの Mac で動きますか？",
       "macOS 14 Sonoma 以降。Apple シリコンでも Intel でも動きます。macOS 26 ではシステムのガラス、それ以前ではすりガラスを使います。"),
    ],
  },
  "zh": {
    "dir": "zh/", "hreflang": "zh-Hans", "name": "简体中文",
    "title": "更改 Mac 通知位置 — Pounce",
    "desc": "把 Mac 通知横幅从右上角移到屏幕中央，或九个位置中的任意一个的 Mac 应用。免费、开源，支持 macOS 14 及以上。",
    "ogdesc": "把 Mac 通知横幅移到屏幕中央的 Mac 应用。免费、开源。",
    "h1": "更改 Mac 通知位置",
    "lede": "把通知放到你真正在看的位置，不再错过。",
    "labels": ["关于", "安装", "截图", "常见问题"],
    "copy": "复制", "copied": "已复制", "copyAria": "复制安装命令",
    "download": "直接下载",
    "alt": "Pounce 设置窗口。预览中通知卡片显示在屏幕中央，下方是从九个位置中选择的网格。",
    "schemaName": "Pounce — 更改 Mac 通知位置",
    "schemaDesc": "把 Mac 通知横幅移到屏幕中央或其他位置显示的 Mac 应用。",
    "faq": [
      ("Mac 系统设置里能改通知位置吗？",
       "不能。苹果把横幅固定在右上角，设置里没有这一项。所以才有了这个应用。"),
      ("显示在正中间会不会碍事？",
       "过几秒会自动消失，鼠标放上去就会等你。还是觉得碍事，就挪到底部居中，九个位置随便选。"),
      ("通知内容会被传到外面吗？",
       "不会。全部在这台 Mac 上完成。唯一的外部请求是检查新版本，而且可以关掉。"),
      ("哪些 Mac 能用？",
       "macOS 14 Sonoma 及以上，Apple 芯片和 Intel 都可以。macOS 26 使用系统玻璃效果，更早的版本使用毛玻璃。"),
    ],
  },
}

STYLE = """  :root {
    color-scheme: light dark;
    --bg: #f6f6f7; --panel: #ffffff; --ink: #16161a; --dim: #6b6b74;
    --line: rgba(0,0,0,.10); --accent: #2f6df6;
  }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #0e0e11; --panel: #17171c; --ink: #f2f2f5; --dim: #9a9aa4;
            --line: rgba(255,255,255,.12); --accent: #6f9dff; }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 16px/1.7 -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Hiragino Sans",
          "PingFang SC", "Malgun Gothic", system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .wrap { max-width: 720px; margin: 0 auto; padding: 0 22px; }
  .group { padding: 34px 0; border-top: 1px solid var(--line); }
  .group:first-child { border-top: 0; padding: 72px 0 34px; }
  .group:last-of-type { padding-bottom: 64px; }
  .langs { display: flex; gap: 14px; font-size: 12px; padding: 22px 0 0; }
  .langs a { color: var(--dim); text-decoration: none; }
  .langs a:hover { color: var(--ink); }
  .langs .here { color: var(--ink); font-weight: 600; }
  .label {
    font-size: 11px; font-weight: 600; letter-spacing: .12em; color: var(--dim);
    margin: 0 0 16px; text-transform: uppercase;
  }
  .mark { display: flex; align-items: center; gap: 13px; margin-bottom: 26px; }
  .mark img { width: 56px; height: 56px; }
  .mark span { font-size: 19px; font-weight: 600; letter-spacing: -.01em; }
  h1 { font-size: 34px; line-height: 1.3; letter-spacing: -.02em; margin: 0 0 14px; }
  .lede { font-size: 17px; color: var(--dim); margin: 0; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
  .cmd {
    display: flex; align-items: center; gap: 10px; margin: 0 0 12px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 11px; padding: 12px 12px 12px 15px;
  }
  .beer { font-size: 17px; line-height: 1; }
  .cmd code { flex: 1; font-size: 14px; overflow-x: auto; white-space: nowrap; }
  .cmd button {
    flex: none; font: inherit; font-size: 13px; font-weight: 500; color: var(--ink);
    background: transparent; border: 1px solid var(--line); border-radius: 7px;
    padding: 5px 12px; cursor: pointer;
  }
  .cmd button:hover { background: var(--bg); }
  .cmd button.done { color: var(--accent); border-color: var(--accent); }
  .dl { margin: 0; font-size: 14px; }
  .shot { display: block; width: 100%; max-width: 520px; height: auto; margin: 0 auto; }
  h2 { font-size: 20px; }
  h3 { font-size: 16px; margin: 24px 0 6px; }
  h3:first-of-type { margin-top: 0; }
  p { margin: 0 0 14px; }
  a { color: var(--accent); }"""

SCRIPT = """document.getElementById('copy').addEventListener('click', function () {
  var text = document.getElementById('install').textContent, button = this;
  function done() {
    button.textContent = COPIED;
    button.classList.add('done');
    setTimeout(function () { button.textContent = COPY; button.classList.remove('done'); }, 1600);
  }
  function fallback() {
    var field = document.createElement('textarea');
    field.value = text;
    document.body.appendChild(field);
    field.select();
    try { document.execCommand('copy'); done(); } catch (e) {}
    document.body.removeChild(field);
  }
  if (navigator.clipboard) { navigator.clipboard.writeText(text).then(done, fallback); } else { fallback(); }
});"""


def page(code, L):
    up = "../" if L["dir"] else ""
    url = SITE + L["dir"]
    alternates = "\n".join(
        '<link rel="alternate" hreflang="%s" href="%s">' % (o["hreflang"], SITE + o["dir"])
        for o in LANGS.values())
    switcher = "\n    ".join(
        ('<span class="here">%s</span>' if c == code else '<a href="%s">%%s</a>' % (SITE + o["dir"])) % o["name"]
        for c, o in LANGS.items())
    faq_html = "\n".join(
        "  <h3>%s</h3>\n  <p>%s</p>\n" % (q, a) for q, a in L["faq"])
    faq_ld = ",\n".join(
        '    { "@type": "Question", "name": %s,\n'
        '      "acceptedAnswer": { "@type": "Answer", "text": %s } }' % (json_str(q), json_str(a))
        for q, a in L["faq"])
    return TEMPLATE % {
        "lang": L["hreflang"], "title": L["title"], "desc": L["desc"], "ogdesc": L["ogdesc"],
        "url": url, "site": SITE, "up": up, "alternates": alternates, "switcher": switcher,
        "h1": L["h1"], "lede": L["lede"],
        "l0": L["labels"][0], "l1": L["labels"][1], "l2": L["labels"][2], "l3": L["labels"][3],
        "brew": BREW, "copy": L["copy"], "copied": L["copied"], "copyAria": L["copyAria"],
        "download": L["download"], "latest": LATEST, "alt": L["alt"],
        "schemaName": L["schemaName"], "schemaDesc": L["schemaDesc"], "version": VERSION,
        "faq": faq_html, "faqLd": faq_ld, "style": STYLE, "script": SCRIPT,
        "copyJs": json_str(L["copy"]), "copiedJs": json_str(L["copied"]),
    }


def json_str(text):
    return '"%s"' % text.replace('\\', '\\\\').replace('"', '\\"')


TEMPLATE = """<!doctype html>
<html lang="%(lang)s">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s</title>
<meta name="description" content="%(desc)s">
<link rel="canonical" href="%(url)s">
%(alternates)s
<link rel="alternate" hreflang="x-default" href="%(site)s">
<meta property="og:type" content="website">
<meta property="og:title" content="%(title)s">
<meta property="og:description" content="%(ogdesc)s">
<meta property="og:url" content="%(url)s">
<meta property="og:image" content="%(site)sog.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="%(up)sfavicon.png">
<style>
%(style)s
</style>
</head>
<body>
<div class="wrap">

<section class="group">
  <p class="label">%(l0)s</p>
  <div class="mark"><img src="%(up)sicon.png" alt="Pounce"><span>Pounce</span></div>
  <h1>%(h1)s</h1>
  <p class="lede">%(lede)s</p>
</section>

<section class="group">
  <h2 class="label">%(l1)s</h2>
  <div class="cmd">
    <span class="beer" aria-hidden="true">🍺</span>
    <code id="install">%(brew)s</code>
    <button type="button" id="copy" aria-label="%(copyAria)s">%(copy)s</button>
  </div>
  <p class="dl"><a href="%(latest)s">%(download)s</a></p>
</section>

<section class="group">
  <h2 class="label">%(l2)s</h2>
  <img class="shot" src="%(up)sscreenshot.png" width="1144" height="1568" alt="%(alt)s">
</section>

<section class="group">
  <h2 class="label">%(l3)s</h2>

%(faq)s
  <nav class="langs">
    %(switcher)s
  </nav>
</section>

</div>

<script>
var COPY = %(copyJs)s, COPIED = %(copiedJs)s;
%(script)s
</script>

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Pounce",
  "alternateName": "%(schemaName)s",
  "description": "%(schemaDesc)s",
  "applicationCategory": "UtilitiesApplication",
  "operatingSystem": "macOS 14.0 or later",
  "url": "%(url)s",
  "downloadUrl": "%(latest)s",
  "softwareVersion": "%(version)s",
  "offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD" }
}
</script>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
%(faqLd)s
  ]
}
</script>
</body>
</html>
"""

here = pathlib.Path(__file__).resolve().parent
for code, L in LANGS.items():
    target = here / L["dir"] / "index.html"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(page(code, L), encoding="utf-8")
    print("wrote", target.relative_to(here))
