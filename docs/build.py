#!/usr/bin/env python3
"""소개 페이지를 언어별로 찍어낸다.

문구만 아래 LANGS 에서 고치고 `python3 docs/build.py` 를 돌리면
index.html(한국어)과 en/ ja/ zh/ 가 같은 구조로 다시 만들어진다.

맥 화면 안의 카드는 그림이 아니라 src/Card.swift 의 수치를 그대로 옮긴 것이므로,
앱의 스프링·치수·색 공식이 바뀌면 SCRIPT 와 STYLE 의 같은 숫자도 따라 고친다.
"""
import json, pathlib

SITE = "https://ojtiger.github.io/pounce/"
REPO = "https://github.com/ojtiger/pounce"
LATEST = REPO + "/releases/latest"
BREW = "brew install --cask ojtiger/tap/pounce"
VERSION = "0.9.9"

LANGS = {
  "ko": {
    "dir": "", "hreflang": "ko", "name": "한국어", "locale": "ko-KR",
    "title": "맥 알림창 위치 변경 — Pounce",
    "desc": "macOS 알림창이 뜨는 위치를 화면 가운데로 옮기는 맥 앱. 우측 상단 알림 배너를 원하는 자리로 바꿉니다. 무료, 오픈소스, macOS 14 이상.",
    "ogdesc": "macOS 알림 배너를 화면 가운데로 옮기는 맥 앱. 무료, 오픈소스.",
    "h1": "맥 알림창 위치 변경",
    "d0": "macOS 알림을 원하는 위치로",
    "lede": "맥 알림을 놓치지 않게, 원하는 자리로 옮겨 보여줍니다.",
    "copy": "복사", "copied": "복사됨", "copyAria": "설치 명령 복사",
    "download": "직접 내려받기",
    "cSpot": "위치", "cTheme": "테마", "cAccent": "강조색",
    "th0": "기본", "th1": "오로라", "th2": "네온", "closeWord": "닫기",
    "cueHold": "멈춤", "cueOpen": "펼치기", "cueClose": "닫기", "cuePast": "지난 알림",
    "featTitle": "핵심 기능",
    "faqTitle": "자주 묻는 질문",
    "faqDesc": "맥 알림창 위치를 바꾸는 Pounce 의 설치, 손쉬운 사용 권한, 업데이트, 문제 해결에 대해 자주 묻는 질문.",
    "back": "첫 화면으로",
    "faq": [
      ("설치하면 뭐가 달라지나요?",
       "알림이 뜨는 자리만 바뀝니다. 알림을 보내는 건 여전히 macOS 라서 집중 모드도, 소리도, 알림 센터 기록도 그대로입니다. Pounce 는 배너를 받아다가 고른 자리에 카드로 다시 그립니다."),
      ("알림 위치는 어디서 바꾸나요?",
       "메뉴 막대의 발바닥을 눌러 설정을 열면 화면 아홉 자리 가운데 고를 수 있습니다. 모니터가 여러 대면 어느 화면에 띄울지도 거기서 고릅니다."),
      ("손쉬운 사용 권한은 왜 달라고 하나요?",
       "그게 없으면 배너를 읽지도, 옮기지도 못합니다. 쓰는 곳은 알림 배너뿐입니다. 키 입력을 보거나 다른 앱을 들여다보지 않고, 어디로 보내는 것도 없습니다."),
      ("제 맥에서도 되나요?",
       "macOS 14 소노마부터 됩니다. 애플 실리콘이든 인텔이든 상관없습니다. 돈은 안 받고, 소스는 GitHub 에 다 있습니다."),
      ("열려는데 개발자를 확인할 수 없다고 합니다.",
       "공증을 안 받아서 그렇습니다. 홈브루로 설치하면 이 창을 볼 일이 없고, 직접 받았다면 시스템 설정 > 개인정보 보호 및 보안에서 한 번만 열어 주면 그다음부터는 바로 열립니다."),
      ("카드가 안 뜹니다.",
       "손쉬운 사용 권한이 빠진 경우가 대부분입니다. 앱을 새 버전으로 덮어쓰면 권한이 풀릴 수 있으니 설정 > 설정 탭 > 접근성 열기로 다시 켜 주세요. 그래도 안 되면 ~/Library/Logs/pounce.log 를 보내 주시면 됩니다."),
      ("카드에 있는 버튼도 그대로 눌리나요?",
       "누르면 알림이 하려던 일을 합니다. 답장처럼 입력 칸이 뜨는 버튼만 예외인데, 그 화면은 macOS 가 직접 그리기 때문에 진짜 배너를 카드가 있던 자리로 데려옵니다."),
      ("업데이트는 알아서 되나요?",
       "하루에 한 번 확인하고, 새 버전이 있으면 스스로 깔고 다시 뜹니다. 누를 건 없습니다. 싫으면 설정에서 끄고 정보 탭에서 직접 확인하면 됩니다."),
    ],
    "menus": ["메모", "파일", "편집", "포맷", "보기", "윈도우", "도움말"],
    "schemaName": "맥 알림창 위치 변경",
    "schemaDesc": "macOS 알림 배너를 화면 가운데 등 원하는 위치로 옮겨 보여주는 맥 앱.",
    "feats": [
      ("알림 위치 변경", "배너가 뜰 자리를 화면 아홉 곳 가운데 고릅니다."),
      ("긴 알림 펼치기", "카드 위에서 위아래로 굴리면 접힌 나머지가 그 자리에서 펼쳐집니다."),
      ("알림 그룹화", "같은 앱에서 온 알림은 카드 하나로 묶입니다."),
      ("밀어서 닫기", "옆으로 밀면 사라지고, 마우스를 올려 두면 그동안 기다립니다."),
      ("알림 버튼 유지", "답장처럼 입력 칸이 필요한 버튼은 진짜 배너를 카드가 있던 자리로 불러옵니다."),
      ("알림 설정 유지", "집중 모드도 소리도 알림 센터 기록도 건드리지 않습니다."),
      ("지난 알림 보기", "⌘ 를 누른 채 휠을 굴리면 알림 센터에 남아 있는 알림을 카드로 한 장씩 넘겨 봅니다. 아이폰에서 온 알림도 함께 나옵니다. 설정에서 켜고, 전체 디스크 접근 권한이 필요합니다."),
    ],
    "req": "macOS 14 이상",
    "notes": [
      {"icon": "msg", "app": "메시지", "title": "김백선", "pill": "답장",
       "body": "다음 주 화요일 출장 건으로 여쭙습니다. 기차표는 제가 왕복으로 끊어 두었고 숙소는 현장 근처로 잡았습니다. 법인카드는 월요일 오후에 총무팀에서 받으시면 되고, 영수증은 돌아오셔서 한 번에 정산하시면 됩니다. 현장 담당자분 연락처는 메일로 보내 두었는데 도착 30분 전에 전화 한 번 주시기를 바라신다고 합니다. 가시는 김에 창고 재고도 같이 보고 오시면 좋겠다고 부장님이 말씀하셨습니다. 일정표는 오늘 안에 정리해서 다시 보내 드리겠습니다."},
      {"icon": "msg", "app": "메시지", "title": "김백선", "pill": "답장",
       "body": "부장님이 오후 회의 자료를 지금 보자고 하십니다. 어제 주신 초안에서 3장 표가 지난달 수치라 다시 뽑아야 할 것 같은데, 원본 시트는 제가 열어서 고쳐 두겠습니다. 확인만 한 번 해 주시고, 인쇄를 두 시 전에 넘겨야 해서 한 시 반까지는 회신 부탁드립니다. 다음 주 워크숍 참석 명단도 아직 안 넘어왔는데, 오늘 중으로 주시면 제가 정리해서 올리겠습니다."},
      {"icon": "msg", "app": "메시지", "title": "김백선", "pill": "답장",
       "body": "오늘 저녁 여섯 시부터 아홉 시까지 결재 시스템 점검입니다. 그 전에 올려야 할 품의가 있으면 다섯 시까지 올려 주세요. 점검이 끝나면 비밀번호를 다시 설정해야 하는 계정이 있어서, 안내 메일이 오면 그대로 따라 하시면 됩니다. 내일 오전에는 보안 교육 이수 확인이 있으니 아직 안 들으신 분은 오늘 안에 들어 두셔야 합니다. 대상자 명단은 팀 채널에 올려 두었습니다."},
    ],
  },
  "en": {
    "dir": "en/", "hreflang": "en", "name": "English", "locale": "en-US", "og": "og-en.png",
    "title": "Move macOS notifications where you want — Pounce",
    "desc": "A Mac app that moves macOS notification banners from the top-right corner to the center of your screen, or any of nine spots. Free, open source, macOS 14 and later.",
    "ogdesc": "A Mac app that moves macOS notification banners to the center of your screen. Free and open source.",
    "h1": "Move macOS notifications",
    "d0": "macOS notifications, where you want them.",
    "lede": "Notifications show up where you are actually looking, so you stop missing them.",
    "copy": "Copy", "copied": "Copied", "copyAria": "Copy the install command",
    "download": "Download directly",
    "cSpot": "Position", "cTheme": "Theme", "cAccent": "Accent",
    "th0": "Default", "th1": "Aurora", "th2": "Neon", "closeWord": "Close",
    "cueHold": "Pause", "cueOpen": "Expand", "cueClose": "Dismiss", "cuePast": "Past ones",
    "featTitle": "Key features",
    "faqTitle": "Frequently asked questions",
    "faqDesc": "Questions people ask about Pounce, the Mac app that moves macOS notification banners: install, Accessibility permission, updates and troubleshooting.",
    "back": "Back to the app",
    "faq": [
      ("What actually changes?",
       "Only where the notification shows up. macOS still sends it, so Focus, sounds and Notification Center history stay exactly as they are. Pounce takes the banner and redraws it where you asked for it."),
      ("Where do I change the position?",
       "Click the paw in the menu bar to open settings and pick one of nine spots on the screen. If you have more than one display, you choose which screen the cards use there too."),
      ("Why does it want Accessibility access?",
       "Without it there is no way to read a banner or move one. That is all the permission is used for. It does not watch your typing, it does not look inside other apps, and nothing is sent anywhere."),
      ("Will it run on my Mac?",
       "If you are on macOS 14 Sonoma or later, yes — Apple silicon or Intel, either is fine. It costs nothing and the source is all on GitHub."),
      ("macOS says it cannot verify the developer.",
       "That is because the app is not notarised. Install it with Homebrew and you never see that dialog. If you downloaded it yourself, allow it once in System Settings > Privacy & Security and it opens normally after that."),
      ("No cards appear.",
       "Nine times out of ten the Accessibility permission is gone. Replacing the app with a new build can drop it, so open settings > Settings tab > Open Accessibility and switch it back on. If that does not help, send me ~/Library/Logs/pounce.log."),
      ("Do the buttons on the card still work?",
       "Press one and it does what the notification would have done. Reply is the exception: macOS draws that text field itself, so the real banner comes back to where the card was standing."),
      ("Does it update itself?",
       "It checks once a day, installs anything new on its own and comes back. Nothing to click. If you would rather it did not, turn it off in settings and check from the About tab whenever you feel like it."),
    ],
    "menus": ["Notes", "File", "Edit", "Format", "View", "Window", "Help"],
    "schemaName": "Pounce — move macOS notifications",
    "schemaDesc": "A Mac app that moves macOS notification banners to the center of the screen, or anywhere else you pick.",
    "feats": [
      ("Nine positions", "Pick where a banner lands, out of nine spots on the screen."),
      ("Expand in place", "Scroll on the card and the folded rest opens where it stands."),
      ("Grouped by app", "Notifications from the same app gather onto a single card."),
      ("Swipe to dismiss", "Push it sideways and it goes. Keep the pointer on it and it waits."),
      ("Actions kept", "Reply and the like bring the real banner back to where the card stood."),
      ("Settings kept", "Focus, sounds and Notification Center history stay as they are."),
      ("Past notifications", "Hold ⌘ and scroll to flip through what is left in Notification Center, one card at a time — iPhone notifications included. Turn it on in settings; it needs Full Disk Access."),
    ],
    "req": "macOS 14 or later",
    "notes": [
      {"icon": "msg", "app": "Messages", "title": "Baekseon Kim", "pill": "Reply",
       "body": "About the trip next Tuesday. I have booked the train both ways and found a room near the site. Pick up the company card from admin on Monday afternoon, and hand in all the receipts together when you are back. I emailed you the site contact — they would like a call about thirty minutes before you arrive. The director also asked if you could look over the warehouse stock while you are there. I will tidy up the schedule and send it again today."},
      {"icon": "msg", "app": "Messages", "title": "Baekseon Kim", "pill": "Reply",
       "body": "The director wants to go through the afternoon deck right now. The table on page 3 of yesterday's draft is still last month's numbers, so it has to be rebuilt — I will open the source sheet and fix it myself. Just look it over once and get back to me by half past one, since printing has to go in before two. The attendee list for next week's workshop has not come through either; send it today and I will tidy it up and file it."},
      {"icon": "msg", "app": "Messages", "title": "Baekseon Kim", "pill": "Reply",
       "body": "The approval system is down for maintenance tonight from six to nine. If you have anything to submit, put it in before five. Some accounts will need their password set again once it is back, and the instructions will come by email — just follow them as written. Tomorrow morning they are checking who has finished the security training, so if you have not done it yet, get it done today. The list of names is up in the team channel."},
    ],
  },
  "ja": {
    "dir": "ja/", "hreflang": "ja", "name": "日本語", "locale": "ja-JP", "og": "og-ja.png",
    "title": "Mac の通知の位置を変更 — Pounce",
    "desc": "Mac の通知バナーを右上から画面中央へ、または好きな位置へ移して表示する Mac アプリ。無料、オープンソース、macOS 14 以降。",
    "ogdesc": "Mac の通知バナーを画面中央へ移して表示する Mac アプリ。無料、オープンソース。",
    "h1": "Mac の通知の位置を変更",
    "d0": "macOS の通知を、好きな位置へ。",
    "lede": "通知を見逃さないように、目を向けている場所に表示します。",
    "copy": "コピー", "copied": "コピーしました", "copyAria": "インストールコマンドをコピー",
    "download": "直接ダウンロード",
    "cSpot": "位置", "cTheme": "テーマ", "cAccent": "アクセント",
    "th0": "標準", "th1": "オーロラ", "th2": "ネオン", "closeWord": "閉じる",
    "cueHold": "一時停止", "cueOpen": "開く", "cueClose": "閉じる", "cuePast": "過去の通知",
    "featTitle": "主な機能",
    "faqTitle": "よくある質問",
    "faqDesc": "Mac の通知バナーの位置を変える Pounce について、インストール、アクセシビリティの許可、アップデート、うまく動かないときの質問。",
    "back": "最初の画面へ",
    "faq": [
      ("入れると何が変わりますか。",
       "通知が出る場所だけです。通知を出すのは今まで通り macOS なので、集中モードも音も通知センターの履歴もそのままです。バナーを受け取って、選んだ場所に描き直すだけです。"),
      ("表示位置はどこで変えますか。",
       "メニューバーの肉球から設定を開くと、画面の九か所から選べます。ディスプレイが複数あるときは、どの画面に出すかもそこで選びます。"),
      ("アクセシビリティの許可は何に使いますか。",
       "これがないとバナーを読むことも動かすこともできません。使うのは通知バナーだけです。キー入力を見たり他のアプリを覗いたりしませんし、どこかへ送ることもありません。"),
      ("自分の Mac でも動きますか。",
       "macOS 14 Sonoma 以降なら動きます。Apple シリコンでも Intel でも大丈夫です。お金はかかりませんし、ソースは GitHub にあります。"),
      ("開発元を確認できないと出ます。",
       "公証を受けていないからです。Homebrew で入れればこの画面は出ません。自分でダウンロードした場合は、システム設定 > プライバシーとセキュリティで一度だけ許可すれば、あとは普通に開きます。"),
      ("カードが出てきません。",
       "たいていはアクセシビリティの許可が外れています。新しいビルドで上書きすると外れることがあるので、設定 > 設定タブ > アクセシビリティを開く からもう一度オンにしてください。それでも駄目なら ~/Library/Logs/pounce.log を送ってください。"),
      ("カードのボタンはそのまま使えますか。",
       "押せば通知がするはずだったことをします。返信だけは別で、入力欄は macOS 自身が描くので、本物のバナーがカードのあった場所に戻ってきます。"),
      ("アップデートは自動ですか。",
       "1 日 1 回確認して、新しいものがあれば自分で入れて立ち上げ直します。押すものはありません。嫌なら設定で切って、情報タブから好きなときに確認できます。"),
    ],
    "menus": ["メモ", "ファイル", "編集", "フォーマット", "表示", "ウインドウ", "ヘルプ"],
    "schemaName": "Pounce — Mac の通知の位置を変更",
    "schemaDesc": "Mac の通知バナーを画面中央など好きな位置へ移して表示する Mac アプリ。",
    "feats": [
      ("通知の表示位置", "バナーが出る位置を画面の九か所から選べます。"),
      ("その場で展開", "カードの上で上下にスクロールすると、たたまれた残りがその場で開きます。"),
      ("通知のグループ化", "同じアプリから来た通知は一枚のカードにまとまります。"),
      ("スワイプで閉じる", "横へ押すと消え、ポインタを乗せている間は待ちます。"),
      ("通知のアクション", "返信のようなボタンは、本物のバナーをカードのあった位置に呼び戻します。"),
      ("設定はそのまま", "集中モードも音も通知センターの履歴も触りません。"),
      ("過去の通知", "⌘ を押しながらスクロールすると、通知センターに残っている通知をカードで一枚ずつめくれます。iPhone からの通知も並びます。設定でオンにし、フルディスクアクセスが必要です。"),
    ],
    "req": "macOS 14 以降",
    "notes": [
      {"icon": "msg", "app": "メッセージ", "title": "キム・ベクソン", "pill": "返信",
       "body": "来週火曜の出張の件です。列車の切符は往復で取ってあり、宿は現場の近くにしました。法人カードは月曜の午後に総務で受け取ってください。領収書は戻られてからまとめて精算で大丈夫です。現場担当者の連絡先はメールで送りました。到着の 30 分前に一度電話がほしいとのことです。ついでに倉庫の在庫も見てきてほしいと部長が言っていました。日程表は今日中に整えて送り直します。"},
      {"icon": "msg", "app": "メッセージ", "title": "キム・ベクソン", "pill": "返信",
       "body": "部長が午後の会議資料を今すぐ見たいそうです。昨日いただいた草案の 3 ページの表が先月の数字のままなので作り直しが必要ですが、元のシートは私が開いて直しておきます。確認だけお願いします。印刷を 2 時前に回すので、1 時半までにご返信ください。来週のワークショップの参加者名簿もまだ届いていません。今日中にいただければ私が整えて提出します。"},
      {"icon": "msg", "app": "メッセージ", "title": "キム・ベクソン", "pill": "返信",
       "body": "今日の夕方 6 時から 9 時まで決裁システムのメンテナンスです。その前に出す稟議があれば 5 時までにお願いします。終わったあとパスワードの再設定が必要なアカウントがあり、案内メールが来たらその通りに進めてください。明日の午前はセキュリティ研修の受講確認があるので、まだの方は今日中に受けておいてください。対象者の名簿はチームのチャンネルに上げてあります。"},
    ],
  },
  "zh": {
    "dir": "zh/", "hreflang": "zh-Hans", "name": "简体中文", "locale": "zh-CN", "og": "og-zh.png",
    "title": "更改 Mac 通知位置 — Pounce",
    "desc": "把 Mac 通知横幅从右上角移到屏幕中央，或九个位置中的任意一个的 Mac 应用。免费、开源，支持 macOS 14 及以上。",
    "ogdesc": "把 Mac 通知横幅移到屏幕中央的 Mac 应用。免费、开源。",
    "h1": "更改 Mac 通知位置",
    "d0": "macOS 通知，放到你想要的位置。",
    "lede": "把通知放到你真正在看的位置，不再错过。",
    "copy": "复制", "copied": "已复制", "copyAria": "复制安装命令",
    "download": "直接下载",
    "cSpot": "位置", "cTheme": "主题", "cAccent": "强调色",
    "th0": "默认", "th1": "极光", "th2": "霓虹", "closeWord": "关闭",
    "cueHold": "暂停", "cueOpen": "展开", "cueClose": "关闭", "cuePast": "以往通知",
    "featTitle": "核心功能",
    "faqTitle": "常见问题",
    "faqDesc": "关于更改 Mac 通知横幅位置的应用 Pounce：安装、辅助功能权限、更新和常见故障的问答。",
    "back": "回到首页",
    "faq": [
      ("装上之后有什么不一样？",
       "只有通知出现的位置不一样。发通知的还是 macOS，所以专注模式、提示音、通知中心的记录都照旧。Pounce 只是把横幅接过来，画到你选的位置。"),
      ("在哪里改通知位置？",
       "点菜单栏上的猫爪打开设置，从屏幕的九个位置里选一个。要是接了多台显示器，在那里还能选卡片出现在哪块屏幕上。"),
      ("为什么要辅助功能权限？",
       "没有它就读不到横幅，也挪不动。权限只用在通知横幅上，不看键盘输入，不碰别的应用，也不往外发任何东西。"),
      ("我的 Mac 能用吗？",
       "macOS 14 Sonoma 以上就能用，Apple 芯片和 Intel 都行。不收钱，源代码都在 GitHub 上。"),
      ("打开时说无法验证开发者。",
       "因为没做公证。用 Homebrew 装就不会看到这个窗口；自己下载的话，在系统设置 > 隐私与安全性里放行一次，以后就能直接打开。"),
      ("卡片不出现。",
       "多半是辅助功能权限掉了。用新版本覆盖安装时可能会掉，请到设置 > 设置标签页 > 打开辅助功能 里重新打开。还是不行的话，把 ~/Library/Logs/pounce.log 发给我。"),
      ("卡片上的按钮还能用吗？",
       "按了就做通知原本要做的事。只有回复不一样，输入框是 macOS 自己画的，所以真正的横幅会回到卡片刚才所在的位置。"),
      ("会自己更新吗？",
       "每天查一次，有新版就自己装好再启动，不用你点什么。不想要的话在设置里关掉，想起来就去关于标签页手动查。"),
    ],
    "menus": ["备忘录", "文件", "编辑", "格式", "显示", "窗口", "帮助"],
    "schemaName": "Pounce — 更改 Mac 通知位置",
    "schemaDesc": "把 Mac 通知横幅移到屏幕中央或其他位置显示的 Mac 应用。",
    "feats": [
      ("通知位置", "横幅出现在哪里，从屏幕的九个位置里选。"),
      ("就地展开", "在卡片上上下滚动，折叠的部分就地展开。"),
      ("通知分组", "同一个应用的通知会集中到一张卡片上。"),
      ("滑动关闭", "向旁边一推就消失，指针停在上面就一直等。"),
      ("通知操作", "回复这类按钮会把真正的横幅带回卡片原来的位置。"),
      ("设置不变", "专注模式、提示音和通知中心的记录都不动。"),
      ("以往通知", "按住 ⌘ 滚动，就能一张张翻看通知中心里留下的通知，来自 iPhone 的也在其中。需在设置中开启，并授予完全磁盘访问权限。"),
    ],
    "req": "macOS 14 及以上",
    "notes": [
      {"icon": "msg", "app": "信息", "title": "金白善", "pill": "回复",
       "body": "想问一下下周二出差的事。火车票我已经订了往返，住的地方也订在工地附近。公务卡周一下午去行政那边领，发票等您回来一起报销就行。现场负责人的联系方式我发到您邮箱了，他希望您到之前三十分钟打个电话。部长还说，既然去了，顺便把仓库的库存也看一下。行程表我今天之内整理好再发您一份。"},
      {"icon": "msg", "app": "信息", "title": "金白善", "pill": "回复",
       "body": "部长说现在就要看下午开会的材料。昨天给的初稿里第 3 页的表还是上个月的数字，得重新做，原始表格我打开改好。您过一遍就行，打印要在两点前送出去，所以请在一点半之前回我。下周工作坊的参会名单也还没给，今天之内发我，我整理好提交。"},
      {"icon": "msg", "app": "信息", "title": "金白善", "pill": "回复",
       "body": "今天傍晚六点到九点审批系统维护。之前要提交的申请，请在五点前提交。维护结束后有些账号需要重新设置密码，通知邮件到了照着做就行。明天上午要查安全培训的完成情况，还没听的同事今天之内听完。名单已经发在团队频道里了。"},
    ],
  },
}

STYLE = """  :root {
    color-scheme: dark;
    --bg: #07070b; --ink: #f3f1ea; --dim: rgba(243,241,234,.62); --faint: rgba(243,241,234,.36);
    --line: rgba(255,255,255,.10); --panel: rgba(255,255,255,.04); --accent: #a18bff;
    --serif: ui-serif, "New York", "Iowan Old Style", AppleMyungjo, "Hiragino Mincho ProN", "Songti SC", "Noto Serif CJK KR", Georgia, serif;
    --sans: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "Malgun Gothic", system-ui, sans-serif;
    --mono: ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink); font: 17px/1.8 var(--sans);
    -webkit-font-smoothing: antialiased; overflow-x: hidden; word-break: keep-all; line-break: strict;
  }
  p { margin: 0 0 16px; }
  a { color: var(--accent); text-underline-offset: 3px; }

  /* 반딧불이. 글 뒤, 배경 위에서 천천히 떠다니며 숨 쉬듯 밝아진다 */
  .flies { position: fixed; inset: 0; z-index: -1; width: 100%; height: 100%; pointer-events: none; }

  /* 뒤 배경. 앱의 오로라와 같은 짜임 — 구름 두 장, 스크린 합성, 14초에 색상환 한 바퀴, 위상은 반대 */
  .sky { position: fixed; inset: 0; z-index: -1; pointer-events: none; overflow: hidden; }
  .sky i { position: absolute; inset: -20%; mix-blend-mode: screen; animation: hue 14s linear infinite; }
  .sky i:first-child { background: radial-gradient(ellipse 60% 60% at 18% 10%, rgba(164,60,255,.20), transparent); }
  .sky i:last-child { background: radial-gradient(ellipse 60% 60% at 92% 95%, rgba(40,120,255,.20), transparent); animation-delay: -7s; }
  @keyframes hue { to { filter: hue-rotate(360deg); } }

  .wrap { max-width: 1120px; margin: 0 auto; padding: 0 28px; }
  .top { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 22px 0; flex-wrap: wrap; }
  .mark { display: flex; align-items: center; gap: 10px; font-weight: 600; font-size: 16px; letter-spacing: -.01em;
          color: var(--ink); text-decoration: none; }
  .mark img { width: 30px; height: 30px; }
  .langs { display: flex; gap: 16px; font-size: 13px; }
  .langs a { color: var(--faint); text-decoration: none; }
  .langs a:hover, .langs .here { color: var(--ink); }

  .hero { display: block; padding: 7vh 0 100px; text-align: center; }
  h1 { font: 600 12px/1.4 var(--sans); letter-spacing: .16em; text-transform: uppercase; color: var(--faint); margin: 0 0 24px; }
  .display { font: 500 clamp(32px, 5.4vw, 68px)/1.22 var(--serif); letter-spacing: -.02em; margin: 0 auto 22px; }
  .lede { font-size: 19px; color: var(--dim); margin: 0 auto; max-width: 34em; }
  .cmd { display: flex; align-items: center; gap: 12px; max-width: 560px; margin: 34px auto 18px; text-align: left;
         background: var(--panel); border: 1px solid rgba(255,255,255,.16); border-radius: 14px; padding: 14px 14px 14px 20px; }
  .cmd code { flex: 1; min-width: 0; font: 14px/1.4 var(--mono); overflow-x: auto; white-space: nowrap; }
  .cmd button { flex: none; font: 500 13px/1 var(--sans); color: var(--bg); background: var(--ink); border: 0; border-radius: 9px; height: 32px; padding: 0 16px; cursor: pointer; }
  .cmd button.done { background: var(--accent); }
  .links { display: flex; gap: 26px; justify-content: center; font-size: 15px; margin: 0; }

  /* 맥북 프로. 화면 안의 모든 크기는 --s(화면 폭 1440pt 기준 배율)를 곱한다 */
  .mac { position: relative; max-width: 1000px; margin: 64px auto 0; }
  .lid { position: relative; padding: 1.1% 1.1% 2.4%; border-radius: 20px 20px 10px 10px; background: #0c0c0e;
         box-shadow: 0 0 0 1px rgba(255,255,255,.16), inset 0 0 0 1px rgba(255,255,255,.05), 0 50px 100px -40px rgba(0,0,0,.95); }
  /* 화면 아래 테두리의 각인 */
  .lid::before { content: "MacBook Pro"; position: absolute; left: 0; right: 0; bottom: .5%; text-align: center;
                 font: 500 clamp(6px, .82vw, 9px)/1 var(--sans); letter-spacing: .06em; color: rgba(255,255,255,.2); }
  .base { position: relative; height: clamp(9px, 1.7vw, 17px); margin: 0 -4.2%; border-radius: 0 0 12px 12px / 0 0 22px 22px;
          background: linear-gradient(#63636b, #35353b 32%, #17171a); box-shadow: 0 24px 40px -14px rgba(0,0,0,.9); }
  .base::before { content: ""; position: absolute; left: 50%; top: 0; width: 17%; height: 34%; transform: translateX(-50%); border-radius: 0 0 8px 8px; background: #17171b; }

  /* 14인치 프로의 화면 비율(3024 x 1964) */
  .screen { position: relative; aspect-ratio: 1.54; overflow: hidden; border-radius: 6px; background: #0a0d2a; text-align: left;
            --s: .67; --k: .86; font-family: var(--sans); }
  .notch { position: absolute; z-index: 1; left: 50%; top: 0; width: calc(196px * var(--s)); height: calc(25px * var(--s));
           transform: translateX(-50%); background: #000; border-radius: 0 0 calc(11px * var(--s)) calc(11px * var(--s)); }
  .notch::after { content: ""; position: absolute; left: 50%; top: calc(9px * var(--s)); width: calc(6px * var(--s)); height: calc(6px * var(--s));
                  margin-left: calc(-3px * var(--s)); border-radius: 50%; background: #16161c; box-shadow: inset 0 0 0 1px rgba(255,255,255,.07); }
  .wall { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .menubar { position: absolute; inset: 0 0 auto 0; z-index: 1; height: calc(24px * var(--s)); display: flex; align-items: center; justify-content: space-between;
             padding: 0 calc(14px * var(--s)); font-size: calc(13px * var(--s)); line-height: 1; color: rgba(255,255,255,.94);
             background: rgba(8,10,30,.30); -webkit-backdrop-filter: blur(20px); backdrop-filter: blur(20px); white-space: nowrap; }
  .menubar .l, .menubar .r { display: flex; align-items: center; gap: calc(20px * var(--s)); }
  .menubar b { font-weight: 700; }
  .menubar svg { display: block; height: calc(13px * var(--s)); width: auto; fill: currentColor; }
  .menubar .apple { height: calc(15px * var(--s)); }

  .win { position: absolute; left: 8%; top: 12%; width: 56%; height: 64%; display: flex; overflow: hidden; border-radius: calc(12px * var(--s));
         background: rgba(30,30,34,.96); box-shadow: 0 0 0 1px rgba(255,255,255,.12), 0 calc(24px * var(--s)) calc(60px * var(--s)) rgba(0,0,0,.55); }
  .win .side { width: 31%; padding: calc(16px * var(--s)) calc(14px * var(--s)); background: rgba(255,255,255,.035); border-right: 1px solid rgba(255,255,255,.07); }
  .lights { display: flex; gap: calc(8px * var(--s)); margin-bottom: calc(30px * var(--s)); }
  .lights i { width: calc(12px * var(--s)); height: calc(12px * var(--s)); border-radius: 50%; background: #ff5f57; }
  .lights i + i { background: #febc2e; }
  .lights i + i + i { background: #28c840; }
  .side u { display: block; height: calc(46px * var(--s)); margin-bottom: calc(6px * var(--s)); border-radius: calc(7px * var(--s));
            background: linear-gradient(rgba(255,255,255,.34), rgba(255,255,255,.34)) calc(12px * var(--s)) 30% / 58% calc(7px * var(--s)) no-repeat,
                        linear-gradient(rgba(255,255,255,.14), rgba(255,255,255,.14)) calc(12px * var(--s)) 72% / 76% calc(6px * var(--s)) no-repeat; }
  .side u:first-of-type { background-color: rgba(255,196,0,.34); }
  .doc { flex: 1; padding: calc(56px * var(--s)) calc(44px * var(--s)); }
  .doc b { display: block; width: 46%; height: calc(18px * var(--s)); margin-bottom: calc(30px * var(--s)); border-radius: 4px; background: rgba(255,255,255,.78); }
  .doc u { display: block; height: calc(8px * var(--s)); margin-bottom: calc(16px * var(--s)); border-radius: 4px; background: rgba(255,255,255,.2); }
  .doc u:nth-of-type(3n) { width: 82%; }
  .doc u:nth-of-type(4n) { width: 64%; margin-bottom: calc(34px * var(--s)); }
  .doc i { display: inline-block; width: 1px; height: calc(15px * var(--s)); background: #ffc400; animation: blink 1.1s steps(1) infinite; }
  @keyframes blink { 50% { opacity: 0; } }

  .dock { position: absolute; left: 50%; bottom: calc(6px * var(--s)); transform: translateX(-50%); display: flex; align-items: flex-end;
          gap: calc(6px * var(--s)); padding: calc(6px * var(--s)) calc(7px * var(--s)) calc(8px * var(--s)); border-radius: calc(20px * var(--s));
          background: rgba(255,255,255,.16); box-shadow: inset 0 0 0 1px rgba(255,255,255,.2);
          -webkit-backdrop-filter: blur(24px) saturate(1.6); backdrop-filter: blur(24px) saturate(1.6); }
  .dock > span { position: relative; width: calc(50px * var(--s)); height: calc(50px * var(--s)); }
  .dock > span.on::after { content: ""; position: absolute; left: 50%; bottom: calc(-6px * var(--s)); width: calc(4px * var(--s)); height: calc(4px * var(--s));
                           margin-left: calc(-2px * var(--s)); border-radius: 50%; background: rgba(255,255,255,.7); }
  .dock > hr { align-self: stretch; width: 1px; margin: calc(4px * var(--s)) calc(3px * var(--s)); border: 0; background: rgba(255,255,255,.25); }

  /* 앱 아이콘. 카드와 독이 같이 쓴다 */
  .ic { position: relative; display: block; width: 100%; height: 100%; border-radius: 22.5%; overflow: hidden; }
  .ic svg { position: absolute; inset: 0; width: 100%; height: 100%; }
  .ic-msg { background: linear-gradient(#5ff777, #0cbd2a); }
  .ic-cal, .ic-notes { background: #fff; }
  .ic-finder { background: linear-gradient(90deg, #1f9bff 52%, #e3f1ff 52%); }
  .ic-safari { background: #f4f5f8; }
  .ic-safari::before { content: ""; position: absolute; inset: 11%; border-radius: 50%; background: radial-gradient(circle at 50% 35%, #4cc2ff, #0a5fd8); }
  .ic-mail { background: linear-gradient(#3ab0ff, #0a66e0); }
  .ic-music { background: linear-gradient(#ff7189, #f5264c); }
  .ic-set { background: linear-gradient(#c3c6ce, #6f737c); }
  .ic-paw img { display: block; width: 100%; height: 100%; transform: scale(1.24); }

  /* 카드 자리. 앱처럼 메뉴 막대와 독을 뺀 영역에서 가장자리 24pt 안쪽 */
  .slot { position: absolute; z-index: 2; width: 480px; transform: translate(var(--tx), var(--ty)) scale(var(--k)); transform-origin: var(--ox) var(--oy); }
  .slot[data-x="l"] { left: calc(24px * var(--s)); --tx: 0px; --ox: 0%; }
  .slot[data-x="c"] { left: 50%; --tx: -50%; --ox: 50%; }
  .slot[data-x="r"] { right: calc(24px * var(--s)); --tx: 0px; --ox: 100%; }
  .slot[data-y="t"] { top: calc(48px * var(--s)); --ty: 0px; --oy: 0%; }
  .slot[data-y="m"] { top: 50%; --ty: -50%; --oy: 50%; }
  .slot[data-y="b"] { bottom: calc(96px * var(--s)); --ty: 0px; --oy: 100%; }

  /* 카드. 수치는 src/Card.swift 그대로: 480 · r28 · pad 22 · icon 56 · gap 16 */
  /* will-change·filter 를 카드에 걸면 그 안의 유리가 뒤를 못 보고 흐림이 사라진다 */
  /* 지난 알림을 넘길 때 카드를 띠로 복제해 롤에 감는다 */
  .rollfx { position: absolute; inset: 0 0 auto 0; pointer-events: none; perspective: 900px; }
  .rollfx .card { position: absolute; left: 0; top: 0; width: 100%; backface-visibility: hidden; }
  .card { position: relative; border-radius: 28px; opacity: 0; cursor: default; touch-action: pan-y; text-align: left;
          -webkit-user-select: none; user-select: none; box-shadow: 0 10px 24px rgba(0,0,0,.55);
          --r1: rgba(255,255,255,.42); --r2: rgba(255,255,255,.16); --r3: rgba(255,255,255,.10); }
  .card .clip { position: absolute; inset: 0; border-radius: inherit; overflow: hidden; clip-path: inset(0 round 28px); isolation: isolate;
                -webkit-backdrop-filter: blur(30px) saturate(1.8); backdrop-filter: blur(30px) saturate(1.8);
                background: linear-gradient(var(--wash), var(--wash)), rgba(30,30,38,.52); }
  .card .cl { position: absolute; inset: 0; display: none; mix-blend-mode: screen; animation: hue 14s linear infinite; }
  .card .cl.a { background: radial-gradient(ellipse 85% 85% at 18% 10%, var(--warm), transparent); }
  .card .cl.b { background: radial-gradient(ellipse 85% 85% at 92% 95%, var(--cool), transparent); animation-delay: -7s; }
  .card[data-theme="aurora"] .cl { display: block; }
  .card[data-theme="neon"] { box-shadow: 0 10px 38px var(--glow); --r1: rgba(var(--ac), .95); --r2: rgba(var(--ac), .40); --r3: rgba(var(--ac), .70); }
  .card[data-theme="neon"] .clip { -webkit-backdrop-filter: none; backdrop-filter: none; background: var(--solid); }
  /* 테두리는 안쪽 그림자로 긋는다. 둥근 모서리를 그대로 따라가므로 모서리가 두꺼워지지 않는다 */
  .card .rim { position: absolute; inset: 0; border-radius: inherit; pointer-events: none;
               box-shadow: inset 0 1px 0 var(--r1), inset 0 -1px 0 var(--r3), inset 0 0 0 1px var(--r2); }
  .card .sheen { position: absolute; top: -30%; left: -20%; width: 35%; height: 160%; opacity: 0; pointer-events: none; transform: skewX(-20deg);
                 background: linear-gradient(90deg, transparent, rgba(255,255,255,.44), transparent); }
  .card .sheen.go { animation: sweep .95s cubic-bezier(.3,.1,.3,1) .12s both, sweepo 1.05s linear .12s both; }
  @keyframes sweep { from { left: -55%; } to { left: 120%; } }
  @keyframes sweepo { 0% { opacity: 0; } 15%, 75% { opacity: 1; } 100% { opacity: 0; } }
  .card .in { position: relative; display: flex; gap: 16px; padding: 22px; }
  .card .ico { flex: none; width: 56px; height: 56px; filter: drop-shadow(0 3px 8px rgba(0,0,0,.35)); }
  .card .txt { min-width: 0; flex: 1; padding-right: 18px; word-break: normal; overflow-wrap: anywhere; }
  /* 한국어는 어절로 끊는다. 중국어·일본어는 글자 사이에서 끊어야 하므로 한국어에만 */
  :lang(ko) .card .txt { word-break: keep-all; }
  .card .app { display: flex; align-items: center; gap: 7px; font-size: 11px; font-weight: 600; letter-spacing: 1.3px; line-height: 16px;
               text-transform: uppercase; color: rgba(255,255,255,.5); }
  /* 남은 시간. 앱의 CountdownDot 과 같게 12시에서 시계 방향으로 비워진다 */
  .card .dot { width: 11px; height: 11px; border-radius: 50%; box-shadow: 0 0 3px rgba(var(--ac), .7);
               background: conic-gradient(rgba(255,255,255,.14) calc((1 - var(--p, 1)) * 1turn), rgb(var(--ac)) 0); }
  .card .ttl { font-size: 20px; font-weight: 700; line-height: 1.3; letter-spacing: -.01em; color: #fff; margin: 3px 0 2px; }
  .card .bod { font-size: 14.5px; line-height: 1.5; color: rgba(255,255,255,.6); overflow: hidden;
               display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 4; }
  .card .bod.open { display: block; -webkit-line-clamp: unset; }
  .card .pills { position: relative; padding: 0 22px 22px 94px; margin-top: -8px; display: flex; gap: 8px; }
  .card .pills:empty { display: none; }
  .card .pill { height: 28px; padding: 0 14px; border-radius: 14px; font: 600 13px/26px var(--sans); color: #fff;
                background: rgba(255,255,255,.14); border: 1px solid rgba(255,255,255,.20); transition: background .12s; }
  .card .pill:hover { background: rgba(255,255,255,.26); }
  /* 글자 × 는 글꼴마다 가운데가 어긋나서, 선 두 개로 직접 긋는다 */
  .card .x { position: absolute; top: 14px; right: 14px; width: 20px; height: 20px; border-radius: 50%; border: 0; padding: 0; cursor: pointer;
             display: flex; align-items: center; justify-content: center;
             background: rgba(255,255,255,.14); color: rgba(255,255,255,.75); transition: background .12s, color .12s; }
  .card .x svg { display: block; width: 9px; height: 9px; }
  .card .x:hover { background: rgba(255,255,255,.26); color: #fff; }

  /* 조작. 위치의 세 줄 높이에 테마와 강조색 두 칸을 맞춘다 */
  .deck { display: flex; justify-content: center; align-items: stretch; gap: 40px; margin-top: 30px; text-align: left; }
  .ctl { display: flex; flex-direction: column; gap: 11px; }
  .ctl > span { font: 11px/1 var(--mono); letter-spacing: .1em; text-transform: uppercase; color: var(--faint); }
  .stack { display: flex; flex-direction: column; justify-content: space-between; gap: 18px; }
  .nine { display: grid; grid-template-columns: repeat(3, 34px); gap: 4px; }
  .seg, .sw { display: flex; gap: 4px; }
  .sw { gap: 8px; }
  .deck button { font: 500 13px/1 var(--sans); color: var(--dim); background: var(--panel); border: 1px solid var(--line);
                 border-radius: 9px; height: 34px; padding: 0 14px; cursor: pointer; transition: background .15s, color .15s, border-color .15s; }
  .deck button:hover { color: var(--ink); background: rgba(255,255,255,.09); }
  .deck button[aria-pressed="true"] { color: var(--bg); background: var(--ink); border-color: var(--ink); }
  .nine button { padding: 0; font-size: 14px; }
  .deck .sw button { width: 22px; height: 22px; padding: 0; border-radius: 50%; border: 0; background: var(--c); }
  .deck .sw button:hover { background: var(--c); transform: scale(1.12); }
  .deck .sw button[aria-pressed="true"] { background: var(--c); box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px var(--c); }
  /* 손짓 안내. 마우스 한 개씩, 바퀴는 위아래로 구르고 몸통은 옆으로 밀린다 */
  .cues { display: flex; justify-content: center; gap: 52px; margin: 26px 0 0; color: var(--faint); }
  .cue { display: flex; align-items: center; gap: 14px; font-size: 13px; letter-spacing: .01em; }
  .rail { position: relative; display: block; width: 21px; height: 31px; }
  /* ⌘ 를 누른 채 굴린다 */
  .key { display: inline-grid; place-items: center; min-width: 24px; height: 24px; padding: 0 5px; margin-right: -6px;
         border: 1.5px solid currentColor; border-radius: 6px; font: 600 13px/1 var(--sans); opacity: .9; }
  .rail.h { margin: 0 15px; }
  .rail.s { margin-right: 15px; }
  /* 올려 두면 시계가 선다 — 마우스 옆에 멈춤 표 */
  .rail.s::before { display: none; }
  .rail.s::after { content: ""; right: -15px; top: 50%; width: 3px; height: 11px; margin-top: -5px; border: 0;
                   border-radius: 1px; background: currentColor; box-shadow: 6px 0 0 currentColor; opacity: .8; }
  .rail::before, .rail::after { content: ""; position: absolute; width: 6px; height: 6px;
                                border: 1.6px solid currentColor; border-width: 1.6px 1.6px 0 0; opacity: .8; }
  .rail.v::before { left: 50%; top: -11px; margin-left: -3px; transform: rotate(-45deg); }
  .rail.v::after { left: 50%; bottom: -11px; margin-left: -3px; transform: rotate(135deg); }
  .rail.h::before { left: -15px; top: 50%; margin-top: -3px; transform: rotate(-135deg); }
  .rail.h::after { right: -15px; top: 50%; margin-top: -3px; transform: rotate(45deg); }
  .mouse { position: absolute; inset: 0; border: 1.5px solid currentColor; border-radius: 11px; }
  .mouse i { position: absolute; left: 50%; top: 6px; width: 2px; height: 6px; margin-left: -1px; border-radius: 1px; background: currentColor; }
  .rail.v .mouse i { animation: wheelY 2s ease-in-out infinite; }
  .rail.h .mouse i { width: 7px; height: 2px; margin-left: -3.5px; animation: wheelX 2s ease-in-out infinite; }
  @keyframes wheelY { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(10px); } }
  @keyframes wheelX { 0%, 100% { transform: translateX(-3.5px); } 50% { transform: translateX(3.5px); } }

  /* 하는 일. 카드와 같은 유리로 빚은 알약 일곱 개 */
  /* 넓은 화면에서는 네 개·세 개 두 줄로 고정해 어느 말이든 한 줄이 외톨이가 되지 않게 한다 */
  .feats { position: relative; max-width: 1000px; margin: 0 auto; padding: 164px 0 0; text-align: center; }
  .feats h2 { font: 500 clamp(29px, 3.8vw, 50px)/1.22 var(--serif); letter-spacing: -.022em; margin: 0 0 46px; }
  .fpills { display: flex; flex-direction: column; align-items: center; gap: 14px; }
  .frow { display: flex; justify-content: center; gap: 14px; }
  /* 빛무리는 상자 안에 다 들어가야 한다. 가장자리에서 잘리면 거기 선이 생긴다 */
  .feats::before { content: ""; position: absolute; left: 50%; top: -30px; width: 160%; height: 760px; transform: translateX(-50%);
                   background: radial-gradient(ellipse 40% 44% at 50% 50%, rgba(161,139,255,.16), transparent 72%); pointer-events: none; }
  .fp { position: relative; display: inline-flex; align-items: center; gap: 11px; height: 54px; padding: 0 25px;
        border: 0; cursor: pointer; font: 500 16px/1 var(--sans); letter-spacing: -.01em; color: var(--ink); white-space: nowrap;
        border-radius: 27px;
        background: rgba(255,255,255,.045);
        -webkit-backdrop-filter: blur(22px) saturate(1.7); backdrop-filter: blur(22px) saturate(1.7);
        box-shadow: inset 0 1px 0 rgba(255,255,255,.24), inset 0 -1px 0 rgba(255,255,255,.08), inset 0 0 0 1px rgba(255,255,255,.10);
        transition: background .25s, box-shadow .35s, transform .25s; }
  .fp svg { width: 19px; height: 19px; flex: none; color: var(--faint); transition: color .25s; }
  .fp:hover, .fp:focus-visible { transform: translateY(-2px); background: rgba(255,255,255,.085); outline: 0;
              box-shadow: inset 0 1px 0 rgba(255,255,255,.32), inset 0 0 0 1px rgba(161,139,255,.45), 0 14px 34px -14px rgba(161,139,255,.55); }
  .fp:hover svg, .fp:focus-visible svg { color: var(--accent); }
  /* 눌러서 열어 둔 것 */
  .fp[aria-expanded="true"] { background: rgba(255,255,255,.10);
              box-shadow: inset 0 1px 0 rgba(255,255,255,.36), inset 0 0 0 1px rgba(161,139,255,.55), 0 14px 34px -16px rgba(161,139,255,.5); }
  .fp[aria-expanded="true"] svg { color: var(--accent); }

  /* 설명. 여섯 개 다 글로 들어 있고 누른 것 하나만 보인다 */
  .fdesc { position: relative; max-width: 660px; min-height: 62px; margin: 30px auto 0; text-align: center; }
  .fdesc p { position: absolute; left: 0; right: 0; top: 0; margin: 0; font-size: 18px; line-height: 1.7; color: var(--dim);
             opacity: 0; translate: 0 7px; pointer-events: none;
             transition: opacity .35s cubic-bezier(.2,.7,.3,1), translate .35s cubic-bezier(.2,.7,.3,1); }
  .fdesc p.on { position: relative; opacity: 1; translate: 0 0; pointer-events: auto; }
  /* 떠오르며 들어온다. transform 은 손댔을 때를 위해 비워 두고 translate 로 옮긴다 */
  .js .fp { opacity: 0; translate: 0 14px; transition: opacity .7s cubic-bezier(.2,.7,.3,1), translate .7s cubic-bezier(.2,.7,.3,1),
                                                       background .25s, box-shadow .35s, transform .25s; }
  .js .fp.in { opacity: 1; translate: 0 0; }

  /* 자주 묻는 질문 같은 글 쪽 */
  .doc { max-width: 720px; margin: 0 auto; padding: 8vh 0 0; }
  .doc h1 { font: 500 clamp(30px, 4.4vw, 52px)/1.2 var(--serif); letter-spacing: -.022em; text-transform: none;
            color: var(--ink); margin: 0 0 54px; text-align: center; }
  .doc dl { margin: 0; }
  .doc dt { font-size: 19px; font-weight: 600; letter-spacing: -.01em; margin: 0 0 10px; }
  .doc dd { margin: 0 0 34px; padding: 0 0 34px; font-size: 16.5px; line-height: 1.85; color: var(--dim);
            border-bottom: 1px solid var(--line); }
  .doc dd:last-of-type { border-bottom: 0; }
  .doc .cta { text-align: center; padding: 26px 0 0; }
  .doc .cta .cmd { margin: 0 auto 16px; }

  .foot { position: relative; text-align: center; padding: 104px 0 76px; }
  .foot img { width: 36px; height: 36px; filter: drop-shadow(0 0 22px rgba(161,139,255,.55)); }
  .foot .fname { font: 600 15px/1 var(--sans); letter-spacing: .04em; margin: 14px 0 7px; }
  .foot .fmeta { font: 11px/1 var(--mono); letter-spacing: .12em; color: var(--faint); margin: 0 0 20px; }
  .foot .flinks { display: flex; justify-content: center; gap: 24px; font-size: 13px; margin: 0; }
  .foot a { color: var(--dim); text-decoration: none; transition: color .2s, text-shadow .3s; }
  .foot a:hover { color: var(--ink); text-shadow: 0 0 18px rgba(161,139,255,.6); }

  @media (max-width: 820px) {
    body { font-size: 16px; }
    .wrap { padding: 0 20px; }
    .hero { padding: 4vh 0 72px; }
    .lede { font-size: 17px; }
    .mac { margin-top: 44px; }
    .deck { flex-direction: column; align-items: center; gap: 26px; margin-top: 34px; }
    .ctl { align-items: center; }
    .stack { align-items: center; gap: 26px; }
    .doc { padding-top: 4vh; }
    .doc h1 { margin-bottom: 38px; }
    .doc dt { font-size: 18px; }
    .doc dd { font-size: 16px; margin-bottom: 28px; padding-bottom: 28px; }
    .feats { padding-top: 112px; }
    .feats h2 { margin-bottom: 34px; }
    .fpills { flex-direction: row; flex-wrap: wrap; justify-content: center; gap: 11px; }
    .frow { display: contents; }
    .fdesc { margin-top: 24px; min-height: 76px; }
    .fdesc p { font-size: 16.5px; }
    .fp { height: 48px; padding: 0 19px; font-size: 15px; gap: 9px; border-radius: 24px; }
    .fp svg { width: 17px; height: 17px; }
    .cues { flex-wrap: wrap; gap: 20px 34px; }
    .menubar .l span, .menubar time { display: none; }
  }
  @media (max-width: 560px) {
    .top { padding: 16px 0; }
    .langs { gap: 12px; font-size: 12px; }
    .cmd { gap: 8px; margin: 26px auto 16px; padding: 11px 11px 11px 14px; border-radius: 12px; }
    .cmd code { font-size: 12px; }
    .cmd button { height: 30px; padding: 0 12px; font-size: 12px; }
    .links { gap: 20px; font-size: 14px; }
    .mac { margin-top: 34px; }
    .lid { border-radius: 12px 12px 7px 7px; }
    .screen { border-radius: 4px; }
    .feats { padding-top: 84px; }
    .feats h2 { margin-bottom: 28px; }
    .fpills { gap: 9px; }
    .fp { height: 44px; padding: 0 16px; font-size: 14px; }
    .fdesc { min-height: 84px; }
    .fdesc p { font-size: 15.5px; }
    .foot { padding: 56px 0 44px; }
  }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation: none !important; transition: none !important; }
  }"""

# 두 쪽(첫 화면·자주 묻는 질문)이 같이 쓰는 조각들
COPY = """(function () {
  document.documentElement.classList.add('js');
  // 설치 명령 복사
  Array.prototype.forEach.call(document.querySelectorAll('.cmd button'), function (b) {
    b.addEventListener('click', function () {
      var text = this.closest('.cmd').querySelector('code').textContent, button = this;
      function done() {
        button.textContent = T.copied; button.classList.add('done');
        setTimeout(function () { button.textContent = T.copy; button.classList.remove('done'); }, 1600);
      }
      function fallback() {
        var field = document.createElement('textarea');
        field.value = text; document.body.appendChild(field); field.select();
        try { document.execCommand('copy'); done(); } catch (e) {}
        document.body.removeChild(field);
      }
      if (navigator.clipboard) { navigator.clipboard.writeText(text).then(done, fallback); } else { fallback(); }
    });
  });
})();"""

SCRIPT = """(function () {
  var RM = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }

  // 메뉴 막대 시계와 캘린더 아이콘의 날짜는 지금 시각
  function clock() {
    var now = new Date();
    try {
      $('#clock').textContent = new Intl.DateTimeFormat(T.locale, { month: 'short', day: 'numeric', weekday: 'short', hour: 'numeric', minute: '2-digit' }).format(now);
    } catch (e) {}
    $$('.ic-cal .d').forEach(function (t) { t.textContent = now.getDate(); });
  }
  clock(); setInterval(clock, 20000);

  var stage = $('#stage'), slot = $('#slot'), card = $('#card'), sheen = $('.sheen', card), ico = $('.ico', card),
      dot = $('.dot', card), bod = $('.bod', card);
  var DURATION = 5, THRESHOLD = 34, GIVE = 48;
  var st = { i: 0, k: 1, shown: false, closing: false, hover: false, drag: false, expanded: false,
             remain: DURATION, sx: 0, py: 0, ps: 1, gen: 0, visible: false, started: false };

  function hsv(h, s, v) {
    h = ((h % 1) + 1) % 1;
    var i = Math.floor(h * 6), f = h * 6 - i, p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
    var c = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i % 6];
    return Math.round(c[0] * 255) + ',' + Math.round(c[1] * 255) + ',' + Math.round(c[2] * 255);
  }
  function hueOf(hex) {
    var r = parseInt(hex.substr(1, 2), 16) / 255, g = parseInt(hex.substr(3, 2), 16) / 255, b = parseInt(hex.substr(5, 2), 16) / 255;
    var mx = Math.max(r, g, b), d = mx - Math.min(r, g, b);
    if (!d) return 0;
    var h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return h / 6;
  }
  // 앱의 Palette(다크) 와 같은 공식. 모든 색이 강조색의 색상 하나에서 나온다.
  function paint(hex) {
    var h = hueOf(hex), s = card.style, ac = parseInt(hex.substr(1, 2), 16) + ',' + parseInt(hex.substr(3, 2), 16) + ',' + parseInt(hex.substr(5, 2), 16);
    s.setProperty('--ac', ac);
    s.setProperty('--warm', 'rgba(' + hsv(h + 0.09, 0.85, 0.95) + ',.5)');
    s.setProperty('--cool', 'rgba(' + hsv(h - 0.14, 0.90, 0.90) + ',.5)');
    s.setProperty('--wash', 'rgba(' + hsv(h, 0.50, 0.20) + ',.28)');
    s.setProperty('--solid', 'rgb(' + hsv(h, 0.35, 0.09) + ')');
    s.setProperty('--glow', 'rgba(' + ac + ',.9)');
  }
  // 화면은 1440pt 짜리 맥으로 본다. 카드는 읽을 수 있게 조금 크게, 좁은 화면에서는 폭에 맞춘다.
  function fit() {
    var w = stage.clientWidth, h = stage.clientHeight, s = w / 1440;
    // 펼친 카드가 가장 클 때(대략 360pt) 화면 안에 다 들어가는 배율까지만 키운다
    st.k = Math.min(1, w < 700 ? (w - 16) / 480 : w * 0.42 / 480, (h - 30) / 360);
    stage.style.setProperty('--s', s.toFixed(4));
    stage.style.setProperty('--k', st.k.toFixed(4));
  }
  function draw() { card.style.transform = 'translate(' + st.sx.toFixed(2) + 'px,' + st.py.toFixed(2) + 'px) scale(' + st.ps.toFixed(4) + ')'; }
  function fill() {
    var n = T.notes[st.i % T.notes.length];
    ico.innerHTML = T.icons[n.icon];
    $('.app span', card).textContent = n.app;
    $('.ttl', card).textContent = n.title;
    bod.textContent = n.body;
    bod.classList.remove('open');
    bod.getAnimations().forEach(function (a) { a.cancel(); });
    st.expanded = false;
    $('.pills', card).innerHTML = n.pill ? '<span class="pill"></span>' : '';
    if (n.pill) $('.pill', card).textContent = n.pill;
    clock();
  }
  // CASpringAnimation 과 같은 질량-스프링-감쇠. 0 에서 1 로 가며 값마다 fn 을 부른다.
  function spring(mass, k, c, v0, fn, gen) {
    var x = 0, v = v0, last = 0;
    requestAnimationFrame(function step(now) {
      if (gen !== st.gen) return;
      var dt = Math.min(0.034, last ? (now - last) / 1000 : 0.016); last = now;
      for (var n = 0; n < 8; n++) { var a = (k * (1 - x) - c * v) / mass; v += a * dt / 8; x += v * dt / 8; }
      var rest = Math.abs(1 - x) < 0.0008 && Math.abs(v) < 0.008;
      fn(rest ? 1 : x);
      if (!rest) requestAnimationFrame(step);
    });
  }
  function shine() { if (RM) return; sheen.classList.remove('go'); void sheen.offsetWidth; sheen.classList.add('go'); }
  function pop() {
    var gen = ++st.gen;
    fill(); st.sx = 0; st.shown = true; st.closing = false; st.remain = DURATION; dot.style.setProperty('--p', 1);
    card.getAnimations().forEach(function (a) { a.cancel(); });
    card.style.opacity = 1;
    if (RM) { st.py = 0; st.ps = 1; draw(); return; }
    card.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 140, easing: 'ease-out' });
    st.ps = 0.6; st.py = 20; draw();
    spring(1, 260, 16, 6, function (x) { st.ps = 0.6 + 0.4 * x; st.py = 20 * (1 - x); draw(); }, gen);
    ico.style.transform = 'scale(.3)';
    setTimeout(function () { spring(0.8, 300, 11, 8, function (x) { ico.style.transform = 'scale(' + (0.3 + 0.7 * x).toFixed(4) + ')'; }, gen); }, 80);
    shine();
  }
  function leave(then) {
    if (!st.shown || st.closing) { if (then) then(); return; }
    var gen = ++st.gen; st.closing = true;
    function gone() { if (gen !== st.gen) return; card.style.opacity = 0; st.shown = false; st.closing = false; if (then) then(); }
    if (RM) { gone(); return; }
    var from = card.style.transform, o = getComputedStyle(card).opacity;
    card.animate([{ transform: from, opacity: o }, { transform: 'translate(' + st.sx + 'px,-22px) scale(.8)', opacity: 0 }],
                 { duration: 240, easing: 'cubic-bezier(.4,0,1,1)', fill: 'forwards' }).onfinish = gone;
  }
  function again(wait) {
    var gen = st.gen;
    setTimeout(function () { if (gen === st.gen && !st.shown) { st.i++; pop(); } }, wait);
  }
  function bump() {
    if (RM || !st.shown || st.closing) return;
    card.animate([{ transform: 'scale(1)' }, { transform: 'scale(1.035)', offset: 0.4 }, { transform: 'scale(1)' }],
                 { duration: 320, easing: 'ease-in-out', composite: 'add' });
    shine();
  }

  // 접혀 있으면 한 번에 전부 펼친다. 앱처럼 본문 4줄에서 끝까지, 카드 높이가 0.3초 동안 따라 늘어난다.
  function expand() {
    if (st.expanded || !st.shown || st.closing) return false;
    // 줄 수 제한이 남은 줄을 어떻게 재는지는 브라우저마다 달라, 풀어 놓고 높이를 직접 잰다
    var h0 = bod.offsetHeight;
    bod.classList.add('open');
    var h1 = bod.offsetHeight;
    if (h1 <= h0 + 1) { bod.classList.remove('open'); return false; }
    st.expanded = true;
    st.remain = Math.max(st.remain, DURATION);
    if (!RM) bod.animate([{ height: h0 + 'px' }, { height: h1 + 'px' }], { duration: 300, easing: 'cubic-bezier(.2,.9,.2,1)' });
    return true;
  }

  // 시계. 올려 둔 동안은 멈추고, 떠나면 적어도 1.5초는 더 머문다.
  // 포인터가 움직이지 않은 채 카드가 새로 떠도 멈춰 있어야 하므로, 들고 난 것만 세지 않고
  // 지금 카드 위에 있는지를 프레임마다 직접 본다.
  function held() { try { return st.hover || card.matches(':hover'); } catch (e) { return st.hover; } }
  var prev = 0;
  requestAnimationFrame(function tick(now) {
    var dt = prev ? (now - prev) / 1000 : 0; prev = now;
    if (!RM && st.visible && st.shown && !st.closing && !held() && !st.drag) {
      st.remain -= dt; dot.style.setProperty('--p', Math.max(0, st.remain / DURATION).toFixed(3));
      if (st.remain <= 0) leave(function () { again(900); });
    }
    requestAnimationFrame(tick);
  });
  card.addEventListener('pointerenter', function (e) { if (e.pointerType === 'mouse') st.hover = true; });
  card.addEventListener('pointerleave', function () { st.hover = false; st.remain = Math.max(1.5, st.remain); });

  // 옆으로 밀기. 처음 민 쪽이 방향이고, 고무줄은 48pt 까지만 늘어나며, 34pt 넘겨 놓으면 닫힌다.
  var sw = { x0: 0, y0: 0, raw: 0, dir: 0, moved: false, idle: 0 };
  function follow() {
    if (!sw.dir || RM) return;
    var forward = Math.max(0, sw.raw * sw.dir);
    st.sx = sw.dir * (1 - 1 / (forward * 0.55 / GIVE + 1)) * GIVE;
    card.style.opacity = 1 - 0.45 * Math.min(1, forward / THRESHOLD);
    draw();
  }
  function release() {
    var travelled = sw.raw * sw.dir, was = sw.dir !== 0;
    sw.raw = 0; sw.dir = 0; st.drag = false;
    if (travelled > THRESHOLD) { leave(function () { again(900); }); return; }
    if (!was || st.closing || RM) return;
    var from = card.style.transform, o = card.style.opacity;
    st.sx = 0; draw(); card.style.opacity = 1;
    card.animate([{ transform: from, opacity: o }, { transform: card.style.transform, opacity: 1 }], { duration: 180, easing: 'ease-out' });
  }
  card.addEventListener('pointerdown', function (e) {
    if (!st.shown || st.closing || e.target.closest('.x')) return;
    sw.x0 = e.clientX; sw.y0 = e.clientY; sw.raw = 0; sw.dir = 0; sw.moved = false; st.drag = true;
    card.setPointerCapture(e.pointerId);
  });
  card.addEventListener('pointermove', function (e) {
    if (!st.drag) return;
    var dx = (e.clientX - sw.x0) / st.k, dy = (e.clientY - sw.y0) / st.k;
    if (!sw.dir) {
      // 손가락으로 위아래로 끌면 스크롤과 같다
      if (Math.abs(dy) > 8 && Math.abs(dy) > Math.abs(dx) * 1.6) {
        sw.moved = true; st.drag = false; expand(); return;
      }
      if (Math.abs(dx) > 4 && Math.abs(dx) > Math.abs(dy)) { sw.dir = dx < 0 ? -1 : 1; sw.moved = true; }
    }
    sw.raw = dx;
    follow();
  });
  function up() { if (st.drag) release(); }
  card.addEventListener('pointerup', up);
  card.addEventListener('pointercancel', up);
  // 카드 위에서 구른 것은 카드가 먹는다. 진짜 배너처럼 뒤 페이지는 따라 움직이지 않는다.
  card.addEventListener('wheel', function (e) {
    if (e.metaKey) return;   // ⌘ 를 누른 채 굴린 것은 지난 알림 넘기기(아래 stage 가 받는다)
    if (!st.shown || st.closing) return;
    e.preventDefault();
    // 가로가 세로보다 확실히 크면 민 것이다. 앱처럼 고무줄로 따라오고, 판정은 손을 뗀 뒤에 한다.
    if (Math.abs(e.deltaX) > Math.abs(e.deltaY) * 1.6) {
      sw.raw -= e.deltaX;
      if (!sw.dir && Math.abs(sw.raw) > 4) sw.dir = sw.raw < 0 ? -1 : 1;
      follow();
      // 휠은 손 뗀 때를 알려주지 않는다. 잠시 멈추면 끝난 것으로 본다.
      clearTimeout(sw.idle); sw.idle = setTimeout(release, 200);
      return;
    }
    sw.raw = 0;
    if (Math.abs(e.deltaY) > 0.5) expand();
  }, { passive: false });
  card.addEventListener('click', function (e) {
    if (sw.moved) { sw.moved = false; return; }
    if (e.target.closest('.x')) { leave(function () { again(900); }); return; }
    // 손가락으로는 굴리는 대신 눌러서 펼친다
    if (expand()) return;
    bump();
  });

  // 지난 알림 — ⌘ 를 누른 채 굴리면 앱처럼 카드가 롤에 감겨 넘어간다. 아래로 굴리면 더 오래된 쪽.
  // 카드를 가는 가로 띠로 복제해 롤에 닿은 띠부터 원을 따라 휘게 한다(src/Card.swift RollStage 와 같은 식).
  var roll = { busy: false, acc: 0, stepped: false, idle: 0 };
  var BANDS = 16, ROLL_MS = 300, HIDDEN = Math.PI * 0.6;
  function bands(src) {
    var wrap = document.createElement('div'), h = src.offsetHeight;
    wrap.className = 'rollfx';
    for (var i = 0; i < BANDS; i++) {
      var c = src.cloneNode(true);
      c.removeAttribute('id');
      c.setAttribute('aria-hidden', 'true');
      c.style.opacity = 1;
      c.style.clipPath = 'inset(' + (i * h / BANDS - 0.5) + 'px -4px ' + (h - (i + 1) * h / BANDS - 0.5) + 'px -4px)';
      wrap.appendChild(c);
    }
    wrap.h = h;
    slot.appendChild(wrap);
    return wrap;
  }
  // p 0 → 1. leaving 이면 0 이 제자리, 아니면 1 이 제자리. atTop: 롤이 카드 위에 있는지.
  function lay(wrap, p, leaving, atTop) {
    var H = wrap.h, r = Math.min(130, H * 0.65), full = H + r * HIDDEN, travel = (leaving ? p : 1 - p) * full;
    var fade = leaving ? 1 - p * p : 1 - (1 - p) * (1 - p), kids = wrap.children;
    for (var i = 0; i < kids.length; i++) {
      var c = (i + 0.5) * H / BANDS, edge = atTop ? c : H - c, along = travel - edge, y, z = 0, a = 0;
      if (along <= 0) y = atTop ? -travel : travel;
      else {
        var phi = along / r;
        y = (atTop ? -r * Math.sin(phi) - c : H + r * Math.sin(phi) - c);
        z = -r * (1 - Math.cos(phi)); a = (atTop ? 1 : -1) * phi;
      }
      var wrapFade = Math.max(0, 1 - Math.max(0, along / r) / HIDDEN);
      kids[i].style.transformOrigin = '50% ' + c + 'px';
      kids[i].style.transform = 'translate3d(0,' + y.toFixed(2) + 'px,' + z.toFixed(2) + 'px) rotateX(' + a.toFixed(4) + 'rad)';
      kids[i].style.opacity = (fade * wrapFade).toFixed(3);
    }
  }
  function flip(older) {
    if (roll.busy) return;
    if (!st.shown || st.closing) { st.i += older ? 1 : T.notes.length - 1; pop(); return; }
    ++st.gen;
    roll.busy = true;
    var out = bands(card);
    st.i += older ? 1 : T.notes.length - 1;
    fill(); st.sx = 0; draw(); st.remain = DURATION; dot.style.setProperty('--p', 1);
    var inn = bands(card);
    card.style.opacity = 0;
    var t0 = performance.now();
    requestAnimationFrame(function step(now) {
      var t = Math.min(1, (now - t0) / (RM ? 1 : ROLL_MS)), p = 0.5 - 0.5 * Math.cos(t * Math.PI);
      lay(out, p, true, older);
      lay(inn, p, false, !older);
      if (t < 1) { requestAnimationFrame(step); return; }
      card.style.opacity = 1;
      out.remove(); inn.remove();
      roll.busy = false;
    });
  }
  stage.addEventListener('wheel', function (e) {
    if (!e.metaKey) return;
    e.preventDefault();
    // 한 번 쓸면 한 장 — 잠시 멈출 때까지 나머지는 버린다
    clearTimeout(roll.idle);
    roll.idle = setTimeout(function () { roll.acc = 0; roll.stepped = false; }, 180);
    if (roll.stepped) return;
    roll.acc += e.deltaY;
    if (Math.abs(roll.acc) < 30) return;
    roll.stepped = true;
    flip(roll.acc > 0);
  }, { passive: false });

  // 조작
  function press(group, btn) { $$('button', group).forEach(function (b) { b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'); }); }
  $('#nine').addEventListener('click', function (e) {
    var b = e.target.closest('button'); if (!b) return;
    press(this, b);
    leave(function () { slot.setAttribute('data-x', b.getAttribute('data-x')); slot.setAttribute('data-y', b.getAttribute('data-y')); pop(); });
  });
  $('#theme').addEventListener('click', function (e) {
    var b = e.target.closest('button'); if (!b) return;
    press(this, b); card.setAttribute('data-theme', b.getAttribute('data-v')); bump();
  });
  $('#accent').addEventListener('click', function (e) {
    var b = e.target.closest('button'); if (!b) return;
    press(this, b); paint(b.getAttribute('data-v')); bump();
  });
  // 아래 단은 눈에 들어올 때 한 줄씩 떠오른다
  (function () {
    var rows = $$('.fp');
    if (RM || !('IntersectionObserver' in window)) {
      rows.forEach(function (r) { r.classList.add('in'); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.style.transitionDelay = (rows.indexOf(e.target) % 4) * 0.07 + 's';
        e.target.classList.add('in');
        io.unobserve(e.target);
      });
    }, { threshold: 0.2, rootMargin: '0px 0px -6% 0px' });
    rows.forEach(function (r) { io.observe(r); });
  })();

  // 알약을 누르면 그 설명만 보인다. 일곱 개 모두 글로 들어 있어 눌러 보지 않아도 읽힌다.
  (function () {
    var pills = $$('.fp'), descs = $$('.fdesc p');
    $('.fpills') && $('.fpills').addEventListener('click', function (e) {
      var b = e.target.closest('.fp');
      if (!b) return;
      var i = pills.indexOf(b);
      pills.forEach(function (x, n) { x.setAttribute('aria-expanded', n === i ? 'true' : 'false'); });
      descs.forEach(function (d, n) { d.classList.toggle('on', n === i); });
    });
  })();

  paint($('#accent [aria-pressed="true"]').getAttribute('data-v'));
  fit(); window.addEventListener('resize', fit);
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (entries) {
      st.visible = entries[0].isIntersecting;
      if (st.visible && !st.started) { st.started = true; setTimeout(pop, 450); }
    }, { threshold: 0.4 }).observe(stage);
  } else { st.visible = true; pop(); }
})();
"""

FLIES = """// 반딧불이. 빛망울 하나를 미리 그려 두고 크기와 진하기만 바꿔 찍는다.
(function () {
  var cv = document.getElementById('flies');
  if (!cv || !cv.getContext || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  var ctx = cv.getContext('2d'), dpr = Math.min(2, window.devicePixelRatio || 1), w = 0, h = 0, flies = [];

  // 따뜻한 것과 서늘한 것 두 가지. 섞여 있어야 한 색으로 물들지 않는다.
  var R = 32;
  function sprite(mid, out) {
    var c = document.createElement('canvas');
    c.width = c.height = R * 2;
    var g = c.getContext('2d'), rad = g.createRadialGradient(R, R, 0, R, R, R);
    rad.addColorStop(0, 'rgba(255,255,236,1)');
    rad.addColorStop(0.15, mid);
    rad.addColorStop(0.4, out);
    rad.addColorStop(1, 'rgba(255,220,120,0)');
    g.fillStyle = rad;
    g.fillRect(0, 0, R * 2, R * 2);
    return c;
  }
  var glows = [sprite('rgba(255,231,150,.85)', 'rgba(255,200,86,.2)'),
               sprite('rgba(214,255,206,.8)', 'rgba(150,235,170,.17)')];

  function born(anywhere) {
    return { x: Math.random() * w, y: anywhere ? Math.random() * h : h + 30,
             r: 5 + Math.random() * 8, sp: 3 + Math.random() * 9, rise: 4 + Math.random() * 10,
             ang: Math.random() * 6.283, wob: 0.3 + Math.random() * 0.7,
             ph: Math.random() * 6.283, rate: 0.5 + Math.random() * 0.8, max: 0.22 + Math.random() * 0.36,
             g: glows[Math.random() < 0.3 ? 1 : 0] };
  }
  function size() {
    w = window.innerWidth; h = window.innerHeight;
    cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    var want = Math.max(9, Math.min(28, Math.round(w * h / 52000)));
    while (flies.length < want) flies.push(born(true));
    flies.length = want;
  }
  var last = 0;
  function frame(now) {
    var dt = last ? Math.min(0.05, (now - last) / 1000) : 0.016, t = now / 1000;
    last = now;
    ctx.clearRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'lighter';
    for (var i = 0; i < flies.length; i++) {
      var f = flies[i];
      f.ang += Math.sin(t * f.wob + f.ph) * 0.9 * dt;
      f.x += Math.cos(f.ang) * f.sp * dt;
      f.y += (Math.sin(f.ang) * f.sp - f.rise) * dt;
      if (f.y < -40) { f.y = h + 30; f.x = Math.random() * w; }
      if (f.x < -40) f.x = w + 30; else if (f.x > w + 40) f.x = -30;
      // 숨 쉬듯: 밝을 때는 짧고 어두울 때는 길게
      var k = Math.max(0, Math.sin(t * f.rate + f.ph));
      ctx.globalAlpha = f.max * (0.08 + 0.92 * k * k * k);
      ctx.drawImage(f.g, f.x - f.r, f.y - f.r, f.r * 2, f.r * 2);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
    requestAnimationFrame(frame);
  }
  size();
  window.addEventListener('resize', size);
  requestAnimationFrame(frame);
})();"""

PAW = ('<path d="M32 30c-9 0-17 8-17 16 0 6 5 9 10 8 3-.6 5-1.5 7-1.5s4 .9 7 1.5c5 1 10-2 10-8 0-8-8-16-17-16z"/>'
       '<ellipse cx="13" cy="27" rx="5" ry="7" transform="rotate(-22 13 27)"/><ellipse cx="25" cy="15" rx="5.5" ry="7.5" transform="rotate(-6 25 15)"/>'
       '<ellipse cx="39" cy="15" rx="5.5" ry="7.5" transform="rotate(6 39 15)"/><ellipse cx="51" cy="27" rx="5" ry="7" transform="rotate(22 51 27)"/>')

# 바탕화면. macOS 27 의 기본 그림(골든게이트)을 512pixels.net 의 6K 판에서 받아
# 화면 비율(1.54)로 잘라 docs/wall.jpg 에 두었다.
WALL = '<img class="wall" src="{UP}wall.jpg" alt="" width="1800" height="1170">'

MSG = '<svg viewBox="0 0 56 56"><path fill="#fff" d="M28 13c-9.4 0-17 6.2-17 13.9 0 4.6 2.7 8.6 6.9 11.2-.4 2-1.4 3.9-2.9 5.3 3.1-.2 5.9-1.3 8.2-3.1 1.5.3 3.1.5 4.8.5 9.4 0 17-6.2 17-13.9S37.4 13 28 13z"/></svg>'
ICONS = {
  "finder": '<svg viewBox="0 0 56 56" fill="none" stroke="#0b3d7a" stroke-width="3" stroke-linecap="round"><path d="M20 20v6M36 20v6"/><path d="M15 36c7 6 19 6 26 0"/><path d="M30 7c-3 10-4 21-2 31" stroke-width="2.4"/></svg>',
  "safari": '<svg viewBox="0 0 56 56"><path d="M36 20 30 30 20 36 26 26z" fill="#fff"/><path d="M36 20 30 30 26 26z" fill="#ff3b30"/></svg>',
  "msg": MSG,
  "mail": '<svg viewBox="0 0 56 56"><rect x="12" y="17" width="32" height="22" rx="3" fill="#fff"/><path d="M12.5 18.5 28 30l15.5-11.5" stroke="#0a66e0" stroke-width="2.4" fill="none"/></svg>',
  "cal": '<svg viewBox="0 0 56 56"><rect width="56" height="16" fill="#ff453a"/><text class="d" x="28" y="46" text-anchor="middle" font-family="-apple-system,Helvetica,Arial,sans-serif" font-size="26" font-weight="300" fill="#1c1c1e">17</text></svg>',
  "notes": '<svg viewBox="0 0 56 56"><rect width="56" height="15" fill="#ffd33d"/><path d="M10 26h36M10 34h36M10 42h36" stroke="#d6d6dc" stroke-width="1.6"/></svg>',
  "music": '<svg viewBox="0 0 56 56"><path fill="#fff" d="M35 12v22.5a5.5 5.5 0 1 1-3-4.9V18.4l-11 2.6v16.5a5.5 5.5 0 1 1-3-4.9V16.2z"/></svg>',
  "set": '<svg viewBox="0 0 56 56"><circle cx="28" cy="28" r="15" fill="none" stroke="#3b3e46" stroke-width="7" stroke-dasharray="4.1 3.75"/><circle cx="28" cy="28" r="11" fill="#a3a7b0" stroke="#3b3e46" stroke-width="3"/><circle cx="28" cy="28" r="4" fill="#3b3e46"/></svg>',
}
DOCK = ["finder", "safari", "msg", "mail", "cal", "notes", "music", "set"]
RUNNING = {"finder", "msg", "notes"}

MENU_ICONS = (
  '<svg style="aspect-ratio:14/14" viewBox="0 0 14 14"><circle cx="5.8" cy="5.8" r="4.6" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="m9.2 9.2 3.8 3.8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>'
  '<svg style="aspect-ratio:18/13" viewBox="0 0 18 13"><path d="M9 12.6 6.5 10a3.5 3.5 0 0 1 5 0z"/><path d="M4.3 7.8a6.6 6.6 0 0 1 9.4 0l-1.5 1.5a4.5 4.5 0 0 0-6.4 0z"/><path d="M2 5.5a9.9 9.9 0 0 1 14 0l-1.5 1.5a7.8 7.8 0 0 0-11 0z"/></svg>'
  '<svg style="aspect-ratio:28/13" viewBox="0 0 28 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" stroke="currentColor" opacity=".5"/><rect x="2" y="2" width="16" height="9" rx="2"/><path d="M25 4.5v4a2 2 0 0 0 0-4z" opacity=".5"/></svg>'
  '<svg style="aspect-ratio:16/13" viewBox="0 0 16 13"><rect x=".7" y=".7" width="14.6" height="4.6" rx="2.3" fill="none" stroke="currentColor" stroke-width="1.3"/><circle cx="12.9" cy="3" r="1.6"/><rect x=".7" y="7.7" width="14.6" height="4.6" rx="2.3" fill="none" stroke="currentColor" stroke-width="1.3"/><circle cx="3.1" cy="10" r="1.6"/></svg>'
  '<svg style="aspect-ratio:1" viewBox="0 0 64 64"><use href="#paw"/></svg>'
)
APPLE = ('<svg class="apple" style="aspect-ratio:17/20" viewBox="0 0 17 20"><path d="M14.1 10.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9'
         '-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8s2 .8 3.4.8c1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9 0 0-2.7-1-2.7-4.1z'
         'M11.6 3c.7-.9 1.2-2 1.1-3.2-1 0-2.3.7-3 1.6-.7.8-1.2 2-1.1 3.1 1.1.1 2.3-.6 3-1.5z"/></svg>')

# 알약 앞의 작은 그림. 기능 순서와 같다.
FEAT_ICONS = [
  '<svg viewBox="0 0 20 20" aria-hidden="true"><g fill="currentColor"><circle cx="4.6" cy="4.6" r="1.25"/><circle cx="10" cy="4.6" r="1.25"/>'
  '<circle cx="15.4" cy="4.6" r="1.25"/><circle cx="4.6" cy="10" r="1.25"/><circle cx="10" cy="10" r="2.6"/><circle cx="15.4" cy="10" r="1.25"/>'
  '<circle cx="4.6" cy="15.4" r="1.25"/><circle cx="10" cy="15.4" r="1.25"/><circle cx="15.4" cy="15.4" r="1.25"/></g></svg>',
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
  '<path d="M4 4.6h12M4 8.6h12"/><path d="M6.3 12.6 10 16.3l3.7-3.7"/></svg>',
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
  '<rect x="3" y="7.4" width="14" height="9.2" rx="2.6"/><path d="M5.4 4.6h9.2"/></svg>',
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
  '<rect x="2.4" y="5.6" width="9" height="8.8" rx="2.6"/><path d="M13.4 10h4.2M15.4 7.9 17.6 10l-2.2 2.1"/></svg>',
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
  '<rect x="2.4" y="6.2" width="10.4" height="7.2" rx="3.6"/><path d="M11.8 11.4 17.6 14l-2.5.8-.8 2.5z" fill="currentColor" stroke="none"/></svg>',
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">'
  '<path d="M2.8 6.6h8.3M15.1 6.6h2.1M2.8 13.4h3.9M10.7 13.4h6.5"/><circle cx="13.2" cy="6.6" r="1.9"/><circle cx="8.7" cy="13.4" r="1.9"/></svg>',
  # 지난 알림 — 거꾸로 도는 시계
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
  '<path d="M3.6 10a6.4 6.4 0 1 0 1.9-4.5"/><path d="M3.2 3.4v2.8h2.8"/><path d="M10 6.6V10l2.4 1.6"/></svg>',
]

ACCENTS = ["#BF5AF2", "#0A84FF", "#FF375F", "#FF453A", "#FF9F0A", "#FFD60A", "#30D158", "#8E8E93"]
SPOTS = [("l", "t", "↖"), ("c", "t", "↑"), ("r", "t", "↗"), ("l", "m", "←"), ("c", "m", "●"), ("r", "m", "→"),
         ("l", "b", "↙"), ("c", "b", "↓"), ("r", "b", "↘")]


def icon(name, up=""):
    if name == "paw":
        return '<i class="ic ic-paw"><img alt="" src="%sicon.png"></i>' % up
    return '<i class="ic ic-%s">%s</i>' % (name, ICONS[name])


def page(code, L):
    up = "../" if L["dir"] else ""
    url = SITE + L["dir"]
    alternates = "\n".join(
        '<link rel="alternate" hreflang="%s" href="%s">' % (o["hreflang"], SITE + o["dir"])
        for o in LANGS.values())
    switcher = "\n    ".join(
        '<span class="here">%s</span>' % o["name"] if c == code
        else '<a href="%s" hreflang="%s">%s</a>' % ((up + o["dir"]) or "./", o["hreflang"], o["name"])
        for c, o in LANGS.items())
    first = L["notes"][0]
    menus = L["menus"]
    pills = "".join(
        '<button type="button" class="fp" aria-expanded="%s" aria-controls="fd%d">%s%s</button>\n      '
        % ("true" if i == 0 else "false", i, FEAT_ICONS[i], f[0]) for i, f in enumerate(L["feats"])).rstrip()
    descs = "".join('<p id="fd%d"%s>%s</p>\n      ' % (i, ' class="on"' if i == 0 else "", f[1])
                    for i, f in enumerate(L["feats"])).rstrip()
    # 네 개·세 개 두 줄로
    items = pills.split("\n      ")
    half = (len(items) + 1) // 2
    pills = '<div class="frow">%s</div>\n      <div class="frow">%s</div>' % ("".join(items[:half]), "".join(items[half:]))
    feats = '<div class="fpills">\n      %s\n    </div>\n    <div class="fdesc">\n      %s\n    </div>' % (pills, descs)
    dock = "".join('<span%s>%s</span>' % (' class="on"' if n in RUNNING else "", icon(n)) for n in DOCK)
    dock += '<hr><span class="on">%s</span>' % icon("paw", up)
    values = {k: v for k, v in L.items() if isinstance(v, str)}
    values.update({
        "og": L.get("og", "og.png"), "lang": L["hreflang"],
        "url": url, "site": SITE, "up": up, "alternates": alternates, "switcher": switcher,
        "brew": BREW, "latest": LATEST, "repo": REPO, "version": VERSION,
        "style": STYLE, "script": COPY + "\n" + SCRIPT + "\n" + FLIES, "paw": PAW,
        "wall": WALL.replace("{UP}", up), "dock": dock, "faqUrl": "faq/",
        "apple": APPLE, "menuIcons": MENU_ICONS, "feats": feats,
        "menus": "<b>%s</b>" % menus[0] + "".join("<span>%s</span>" % m for m in menus[1:]),
        "nApp": first["app"], "nTitle": first["title"], "nBody": first["body"], "icon0": icon(first["icon"], up),
        "spots": "".join(
            '<button type="button" data-x="%s" data-y="%s" aria-pressed="%s">%s</button>'
            % (x, y, "true" if (x, y) == ("c", "m") else "false", glyph) for x, y, glyph in SPOTS),
        "accents": "".join(
            '<button type="button" data-v="%s" style="--c:%s" aria-label="%s" aria-pressed="%s"></button>'
            % (c, c, c, "true" if i == 0 else "false") for i, c in enumerate(ACCENTS)),
        "data": json.dumps({"copy": L["copy"], "copied": L["copied"], "locale": L["locale"], "notes": L["notes"],
                            "icons": {n: icon(n, up) for n in ("msg", "cal", "paw")}},
                           ensure_ascii=False).replace("</", "<\\/"),
    })
    return TEMPLATE % values


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
<meta property="og:image" content="%(site)s%(og)s">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#07070b">
<link rel="icon" href="%(up)sfavicon.png">
<style>
%(style)s
</style>
</head>
<body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><symbol id="paw" viewBox="0 0 64 64" fill="currentColor">%(paw)s</symbol></svg>
<div class="sky" aria-hidden="true"><i></i><i></i></div>
<canvas class="flies" id="flies" aria-hidden="true"></canvas>
<div class="wrap">

<header class="top">
  <div class="mark"><img src="%(up)sicon.png" width="30" height="30" alt=""><span>Pounce</span></div>
  <nav class="langs">
    %(switcher)s
  </nav>
</header>

<main class="hero">
  <h1>%(h1)s</h1>
  <p class="display">%(d0)s</p>
  <p class="lede">%(lede)s</p>
  <div class="cmd">
    <code>%(brew)s</code>
    <button type="button" aria-label="%(copyAria)s">%(copy)s</button>
  </div>
  <p class="links"><a href="%(latest)s">%(download)s</a><a href="%(repo)s">GitHub</a></p>

  <div class="mac">
    <div class="lid">
      <div class="screen" id="stage">
        %(wall)s
        <div class="menubar" aria-hidden="true">
          <div class="l">%(apple)s%(menus)s</div>
          <div class="r">%(menuIcons)s<time id="clock"></time></div>
        </div>
        <div class="notch" aria-hidden="true"></div>
        <div class="win" aria-hidden="true">
          <div class="side"><div class="lights"><i></i><i></i><i></i></div><u></u><u></u><u></u><u></u><u></u></div>
          <div class="doc"><b></b><u></u><u></u><u></u><u></u><u></u><u></u><u></u><u></u><i></i></div>
        </div>
        <div class="dock" aria-hidden="true">%(dock)s</div>
        <div class="slot" id="slot" data-x="c" data-y="m">
          <div class="card" id="card" data-theme="aurora">
            <div class="clip"><i class="cl a"></i><i class="cl b"></i><i class="sheen"></i></div>
            <i class="rim"></i>
            <div class="in">
              <div class="ico">%(icon0)s</div>
              <div class="txt">
                <div class="app"><i class="dot"></i><span>%(nApp)s</span></div>
                <div class="ttl">%(nTitle)s</div>
                <div class="bod">%(nBody)s</div>
              </div>
            </div>
            <div class="pills"></div>
            <button type="button" class="x" aria-label="%(closeWord)s"><svg viewBox="0 0 10 10" aria-hidden="true"><path d="M1.2 1.2 8.8 8.8M8.8 1.2 1.2 8.8" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></button>
          </div>
        </div>
      </div>
    </div>
    <div class="base"></div>
  </div>

  <div class="deck">
    <div class="ctl"><span>%(cSpot)s</span><div class="nine" id="nine">%(spots)s</div></div>
    <div class="stack">
      <div class="ctl"><span>%(cTheme)s</span><div class="seg" id="theme">
        <button type="button" data-v="default" aria-pressed="false">%(th0)s</button>
        <button type="button" data-v="aurora" aria-pressed="true">%(th1)s</button>
        <button type="button" data-v="neon" aria-pressed="false">%(th2)s</button></div></div>
      <div class="ctl"><span>%(cAccent)s</span><div class="sw" id="accent">%(accents)s</div></div>
    </div>
  </div>
  <div class="cues">
    <span class="cue"><span class="rail s"><span class="mouse"><i></i></span></span>%(cueHold)s</span>
    <span class="cue"><span class="rail v"><span class="mouse"><i></i></span></span>%(cueOpen)s</span>
    <span class="cue"><span class="rail h"><span class="mouse"><i></i></span></span>%(cueClose)s</span>
    <span class="cue"><kbd class="key">⌘</kbd><span class="rail v"><span class="mouse"><i></i></span></span>%(cuePast)s</span>
  </div>

  <section class="feats">
    <h2>%(featTitle)s</h2>
    %(feats)s
  </section>
</main>

<footer class="foot">
  <img src="%(up)sicon.png" width="36" height="36" alt="">
  <p class="fname">Pounce</p>
  <p class="fmeta">%(version)s · %(req)s</p>
  <p class="flinks"><a href="%(faqUrl)s">%(faqTitle)s</a><a href="%(repo)s">GitHub</a><a href="%(latest)s">%(download)s</a></p>
</footer>

</div>

<script>
var T = %(data)s;
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

</body>
</html>
"""

def faq_page(code, L):
    """자주 묻는 질문. 첫 화면은 건드리지 않고 글로 읽히는 쪽을 따로 둔다."""
    up = "../../" if L["dir"] else "../"
    url = SITE + L["dir"] + "faq/"
    alternates = "\n".join(
        '<link rel="alternate" hreflang="%s" href="%sfaq/">' % (o["hreflang"], SITE + o["dir"])
        for o in LANGS.values())
    switcher = "\n    ".join(
        '<span class="here">%s</span>' % o["name"] if c == code
        else '<a href="%s" hreflang="%s">%s</a>' % (("../" * (2 if L["dir"] else 1)) + o["dir"] + "faq/", o["hreflang"], o["name"])
        for c, o in LANGS.items())
    items = "".join("<dt>%s</dt>\n    <dd>%s</dd>\n    " % (q, a) for q, a in L["faq"]).rstrip()
    ld = json.dumps({
        "@context": "https://schema.org", "@type": "FAQPage",
        "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}}
                       for q, a in L["faq"]],
    }, ensure_ascii=False, indent=2).replace("</", "<\\/")
    values = {k: v for k, v in L.items() if isinstance(v, str)}
    values.update({
        "lang": L["hreflang"], "og": L.get("og", "og.png"), "url": url, "site": SITE, "up": up,
        "alternates": alternates, "switcher": switcher, "items": items, "faqLd": ld,
        "brew": BREW, "latest": LATEST, "repo": REPO, "version": VERSION,
        "style": STYLE, "script": COPY + "\n" + FLIES, "paw": PAW,
        "home": "../" * (2 if L["dir"] else 1) + L["dir"] or "../",
        "data": json.dumps({"copy": L["copy"], "copied": L["copied"]}, ensure_ascii=False).replace("</", "<\\/"),
    })
    return FAQ_TEMPLATE % values


FAQ_TEMPLATE = """<!doctype html>
<html lang="%(lang)s">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(faqTitle)s — Pounce</title>
<meta name="description" content="%(faqDesc)s">
<link rel="canonical" href="%(url)s">
%(alternates)s
<link rel="alternate" hreflang="x-default" href="%(site)sfaq/">
<meta property="og:type" content="article">
<meta property="og:title" content="%(faqTitle)s — Pounce">
<meta property="og:description" content="%(faqDesc)s">
<meta property="og:url" content="%(url)s">
<meta property="og:image" content="%(site)s%(og)s">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#07070b">
<link rel="icon" href="%(up)sfavicon.png">
<style>
%(style)s
</style>
</head>
<body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><symbol id="paw" viewBox="0 0 64 64" fill="currentColor">%(paw)s</symbol></svg>
<div class="sky" aria-hidden="true"><i></i><i></i></div>
<canvas class="flies" id="flies" aria-hidden="true"></canvas>
<div class="wrap">

<header class="top">
  <a class="mark" href="%(home)s"><img src="%(up)sicon.png" width="30" height="30" alt=""><span>Pounce</span></a>
  <nav class="langs">
    %(switcher)s
  </nav>
</header>

<main class="doc">
  <h1>%(faqTitle)s</h1>
  <dl>
    %(items)s
  </dl>
  <div class="cta">
    <div class="cmd">
      <code>%(brew)s</code>
      <button type="button" aria-label="%(copyAria)s">%(copy)s</button>
    </div>
  </div>
</main>

<footer class="foot">
  <img src="%(up)sicon.png" width="36" height="36" alt="">
  <p class="fname">Pounce</p>
  <p class="fmeta">%(version)s · %(req)s</p>
  <p class="flinks"><a href="%(home)s">%(back)s</a><a href="%(repo)s">GitHub</a><a href="%(latest)s">%(download)s</a></p>
</footer>

</div>

<script>
var T = %(data)s;
%(script)s
</script>

<script type="application/ld+json">
%(faqLd)s
</script>
</body>
</html>
"""

SITEMAP = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
%s</urlset>
"""


def sitemap():
    """여덟 장(첫 화면 넷, 질문 넷)을 서로의 번역판으로 신고한다."""
    entries = ""
    for tail in ("", "faq/"):
        alts = "".join(
            '    <xhtml:link rel="alternate" hreflang="%s" href="%s"/>\n' % (o["hreflang"], SITE + o["dir"] + tail)
            for o in LANGS.values())
        alts += '    <xhtml:link rel="alternate" hreflang="x-default" href="%s"/>\n' % (SITE + tail)
        for L in LANGS.values():
            entries += "  <url>\n    <loc>%s</loc>\n%s  </url>\n" % (SITE + L["dir"] + tail, alts)
    return SITEMAP % entries


ROBOTS = """User-agent: *
Allow: /

Sitemap: %ssitemap.xml
""" % SITE

here = pathlib.Path(__file__).resolve().parent
(here / "sitemap.xml").write_text(sitemap(), encoding="utf-8")
(here / "robots.txt").write_text(ROBOTS, encoding="utf-8")
print("wrote sitemap.xml, robots.txt")
for code, L in LANGS.items():
    for path, html in ((L["dir"] + "index.html", page(code, L)),
                       (L["dir"] + "faq/index.html", faq_page(code, L))):
        target = here / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(html, encoding="utf-8")
        print("wrote", target.relative_to(here))
