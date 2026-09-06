import Foundation

/// The languages Pounce speaks. The value is the code stored in settings; `system` follows the Mac.
enum Language: String, CaseIterable {
  case system, ko, en, ja, zhHans = "zh-Hans", zhHant = "zh-Hant", es, fr, de, it, pt, ru, nl, pl, tr, vi, id

  /// Shown in its own language, the way every language picker does it, so it is readable to whoever needs it.
  var label: String {
    switch self {
    case .system: return T("시스템")
    case .ko: return "한국어"
    case .en: return "English"
    case .ja: return "日本語"
    case .zhHans: return "简体中文"
    case .zhHant: return "繁體中文"
    case .es: return "Español"
    case .fr: return "Français"
    case .de: return "Deutsch"
    case .it: return "Italiano"
    case .pt: return "Português"
    case .ru: return "Русский"
    case .nl: return "Nederlands"
    case .pl: return "Polski"
    case .tr: return "Türkçe"
    case .vi: return "Tiếng Việt"
    case .id: return "Bahasa Indonesia"
    }
  }
}

/// The one place every visible string lives. Korean is the source text and doubles as the key, so a
/// missing translation falls back to it rather than to a bare identifier.
enum Localization {
  /// The order the columns appear in each row of `table`, after the Korean key.
  static let columns = ["en", "ja", "zh-Hans", "zh-Hant", "es", "fr", "de", "it",
                        "pt", "ru", "nl", "pl", "tr", "vi", "id"]

  private static var cached: String?

  /// The language actually in force: the chosen one, or the closest the Mac asks for.
  static var active: String {
    if let cached { return cached }
    let choice = Settings.shared.language
    let resolved = choice == Language.system.rawValue ? systemLanguage() : choice
    cached = resolved
    return resolved
  }

  static func forget() { cached = nil }

  private static func systemLanguage() -> String {
    for preferred in Locale.preferredLanguages {
      if preferred.hasPrefix("zh") { return preferred.contains("Hant") ? "zh-Hant" : "zh-Hans" }
      let base = String(preferred.prefix(2))
      if base == "ko" { return "ko" }
      if columns.contains(base) { return base }
    }
    // Nothing matched: English travels furthest.
    return "en"
  }

  static func text(_ korean: String) -> String {
    let language = active
    guard language != "ko", let column = columns.firstIndex(of: language) else { return korean }
    guard let row = rows[korean], column < row.count, !row[column].isEmpty else { return korean }
    return row[column]
  }

  private static let rows: [String: [String]] = {
    var out = [String: [String]]()
    for line in table.split(separator: "\n") {
      let parts = line.components(separatedBy: "|")
      guard parts.count > 1 else { continue }
      out[parts[0]] = Array(parts.dropFirst())
    }
    return out
  }()
}

/// The visible text, in the language in force. Korean strings are the keys.
func T(_ korean: String, _ arguments: CVarArg...) -> String {
  let format = Localization.text(korean)
  return arguments.isEmpty ? format : String(format: format, arguments: arguments)
}

/// Korean|en|ja|zh-Hans|zh-Hant|es|fr|de|it|pt|ru|nl|pl|tr|vi|id
private let table = """
위치|Position|位置|位置|位置|Posición|Position|Position|Posizione|Posição|Положение|Positie|Pozycja|Konum|Vị trí|Posisi
테마|Theme|テーマ|主题|主題|Tema|Thème|Design|Tema|Tema|Тема|Thema|Motyw|Tema|Giao diện|Tema
설정|Settings|設定|设置|設定|Ajustes|Réglages|Einstellungen|Impostazioni|Ajustes|Настройки|Instellingen|Ustawienia|Ayarlar|Cài đặt|Pengaturan
정보|About|情報|关于|關於|Información|À propos|Über|Info|Sobre|О программе|Info|Informacje|Hakkında|Giới thiệu|Tentang
모니터|Display|ディスプレイ|显示器|顯示器|Pantalla|Écran|Bildschirm|Schermo|Tela|Монитор|Beeldscherm|Ekran|Ekran|Màn hình|Layar
크기|Size|サイズ|大小|大小|Tamaño|Taille|Größe|Dimensione|Tamanho|Размер|Grootte|Rozmiar|Boyut|Kích thước|Ukuran
지속 시간|Duration|表示時間|显示时长|顯示時間|Duración|Durée|Dauer|Durata|Duração|Длительность|Duur|Czas|Süre|Thời lượng|Durasi
강조색|Accent|アクセントカラー|强调色|強調色|Color de acento|Couleur d'accentuation|Akzentfarbe|Colore accento|Cor de destaque|Акцентный цвет|Accentkleur|Kolor akcentu|Vurgu rengi|Màu nhấn|Warna aksen
소리|Sound|サウンド|声音|音效|Sonido|Son|Ton|Suono|Som|Звук|Geluid|Dźwięk|Ses|Âm thanh|Suara
없음|None|なし|无|無|Ninguno|Aucun|Ohne|Nessuno|Nenhum|Нет|Geen|Brak|Yok|Không|Tidak ada
언어|Language|言語|语言|語言|Idioma|Langue|Sprache|Lingua|Idioma|Язык|Taal|Język|Dil|Ngôn ngữ|Bahasa
알람 테스트|Test notification|通知テスト|通知测试|通知測試|Notificación de prueba|Notification de test|Testmitteilung|Notifica di prova|Notificação de teste|Тестовое уведомление|Testmelding|Powiadomienie testowe|Test bildirimi|Thông báo thử|Notifikasi uji
5회|×5|×5|×5|×5|×5|×5|×5|×5|×5|×5|×5|×5|×5|×5|×5
액션|Actions|アクション|操作|操作|Acciones|Actions|Aktionen|Azioni|Ações|Действия|Acties|Akcje|Eylemler|Tác vụ|Tindakan
액션 테스트|Action test|アクションのテスト|操作测试|操作測試|Prueba de acciones|Test des actions|Aktionstest|Test azioni|Teste de ações|Проверка действий|Actietest|Test akcji|Eylem testi|Thử tác vụ|Uji tindakan
답장 버튼을 눌러 보세요.|Try the reply button.|返信ボタンを押してみてください。|试试回复按钮。|試試回覆按鈕。|Prueba el botón de responder.|Essayez le bouton de réponse.|Probier die Antwort-Taste.|Prova il pulsante di risposta.|Experimente o botão de responder.|Нажмите кнопку ответа.|Probeer de antwoordknop.|Wypróbuj przycisk odpowiedzi.|Yanıt düğmesini deneyin.|Thử nút trả lời.|Coba tombol balas.
답장|Reply|返信|回复|回覆|Responder|Répondre|Antworten|Rispondi|Responder|Ответить|Antwoorden|Odpowiedz|Yanıtla|Trả lời|Balas
메시지|Message|メッセージ|消息|訊息|Mensaje|Message|Nachricht|Messaggio|Mensagem|Сообщение|Bericht|Wiadomość|Mesaj|Tin nhắn|Pesan
자동 업데이트|Update automatically|自動アップデート|自动更新|自動更新|Actualizar automáticamente|Mise à jour automatique|Automatisch aktualisieren|Aggiorna automaticamente|Atualizar automaticamente|Обновлять автоматически|Automatisch bijwerken|Aktualizuj automatycznie|Otomatik güncelle|Tự động cập nhật|Perbarui otomatis
Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@|Pounce %@
자동으로 업데이트되었습니다.|Updated automatically.|自動でアップデートしました。|已自动更新。|已自動更新。|Se actualizó automáticamente.|Mise à jour effectuée automatiquement.|Automatisch aktualisiert.|Aggiornato automaticamente.|Atualizado automaticamente.|Обновлено автоматически.|Automatisch bijgewerkt.|Zaktualizowano automatycznie.|Otomatik olarak güncellendi.|Đã tự động cập nhật.|Diperbarui otomatis.
유리|Glass|ガラス|玻璃|玻璃|Cristal|Verre|Glas|Vetro|Vidro|Стекло|Glas|Szkło|Cam|Kính|Kaca
밝기|Appearance|明るさ|明暗|明暗|Apariencia|Apparence|Erscheinung|Aspetto|Aparência|Оформление|Weergave|Wygląd|Görünüm|Chế độ|Tampilan
오로라|Aurora|オーロラ|极光|極光|Aurora|Aurore|Aurora|Aurora|Aurora|Сияние|Aurora|Zorza|Aurora|Cực quang|Aurora
네온|Neon|ネオン|霓虹|霓虹|Neón|Néon|Neon|Neon|Néon|Неон|Neon|Neon|Neon|Neon|Neon
모노|Mono|モノクロ|单色|單色|Mono|Mono|Mono|Mono|Mono|Моно|Mono|Mono|Mono|Đơn sắc|Mono
카드 위에서 스크롤하면 그 자리에서 전문이 펼쳐집니다. 본문이 길면 네 줄까지만 보여주고 나머지는 줄임표로 접습니다. 이 문장은 그 동작을 눈으로 확인하려고 일부러 길게 쓴 것이고, 카드 폭에 맞춰 줄이 나뉘는 모습도 함께 볼 수 있습니다. 잘리는 지점은 카드 폭과 글자 크기에 따라 달라지고, 크기를 크게로 바꾸면 같은 문장이라도 더 일찍 잘립니다. 원문 전체는 알림 센터에 그대로 남아 있습니다.|Scroll on the card and the whole thing opens where it stands. A long body is shown four lines deep and the rest is folded away behind an ellipsis. This sentence is deliberately long so you can watch that happen, and see how the lines break to the width of the card. Where the cut lands depends on the card's width and text size, so the same sentence folds earlier at a larger size. The whole text stays in Notification Center.|カードの上でスクロールすると、その場で全文が開きます。 本文が長い場合は4行まで表示し、残りは省略記号でたたみます。この文はその動作を目で確かめるためにわざと長く書いてあり、カード幅に合わせて行が折り返される様子も一緒に確認できます。 どこで切れるかはカード幅と文字サイズによって変わり、サイズを大きくすると同じ文でも早く切れます。全文は通知センターにそのまま残ります。|在卡片上滚动，全文就会当场展开。 正文过长时只显示四行，其余内容用省略号折叠。这段文字是特意写长的，方便你亲眼确认这一行为，同时看到文本如何按卡片宽度换行。 截断的位置取决于卡片宽度和文字大小，字号调大时同一段话会更早被折叠。完整内容仍保留在通知中心。|在卡片上捲動，全文就會當場展開。 內文過長時只顯示四行，其餘以刪節號摺疊。這段文字是刻意寫長的，方便你親眼確認這個行為，同時看到文字如何依卡片寬度換行。 截斷的位置取決於卡片寬度與文字大小，字級調大時同一段話會更早被摺疊。完整內容仍保留在通知中心。|Desplázate sobre la tarjeta y el texto se abre entero ahí mismo. Un cuerpo largo se muestra hasta cuatro líneas y el resto se pliega tras unos puntos suspensivos. Esta frase es larga a propósito para que puedas verlo y observar cómo se ajustan las líneas al ancho de la tarjeta. Dónde se corta depende del ancho de la tarjeta y del tamaño del texto, así que la misma frase se pliega antes en un tamaño mayor. El texto completo sigue en el Centro de notificaciones.|Faites défiler sur la carte et le texte s'ouvre entièrement sur place. Un texte long s'affiche sur quatre lignes au plus, le reste se replie derrière des points de suspension. Cette phrase est longue à dessein pour que vous puissiez l'observer et voir comment les lignes s'ajustent à la largeur de la carte. L'endroit de la coupe dépend de la largeur de la carte et de la taille du texte : la même phrase se replie plus tôt en grande taille. Le texte entier reste dans le centre de notifications.|Scroll auf der Karte, und der ganze Text klappt an Ort und Stelle auf. Ein langer Text wird bis zu vier Zeilen gezeigt, der Rest verschwindet hinter Auslassungspunkten. Dieser Satz ist absichtlich lang, damit du das sehen kannst und wie die Zeilen auf die Kartenbreite umbrechen. Wo geschnitten wird, hängt von Kartenbreite und Textgröße ab; derselbe Satz bricht bei größerer Schrift früher ab. Der ganze Text bleibt in der Mitteilungszentrale.|Scorri sulla scheda e il testo si apre per intero lì dov'è. Un testo lungo viene mostrato fino a quattro righe e il resto si ripiega dietro i puntini di sospensione. Questa frase è lunga apposta per farti vedere il comportamento e come le righe si adattano alla larghezza della scheda. Dove avviene il taglio dipende dalla larghezza della scheda e dalla dimensione del testo, quindi la stessa frase si ripiega prima a dimensioni maggiori. Il testo intero resta nel Centro Notifiche.|Role sobre o cartão e o texto inteiro se abre ali mesmo. Um texto longo aparece em até quatro linhas e o resto fica dobrado atrás de reticências. Esta frase é longa de propósito para você ver isso acontecer e como as linhas quebram na largura do cartão. Onde o corte acontece depende da largura do cartão e do tamanho do texto, então a mesma frase se dobra antes num tamanho maior. O texto inteiro continua na Central de Notificações.|Прокрутите на карточке — и текст раскроется целиком прямо там. Длинный текст показывается до четырёх строк, остальное сворачивается за многоточием. Это предложение намеренно длинное, чтобы вы увидели это своими глазами и заметили, как строки переносятся по ширине карточки. Место обрезки зависит от ширины карточки и размера текста, поэтому при крупном размере та же фраза сворачивается раньше. Полный текст остаётся в Центре уведомлений.|Scroll op de kaart en de hele tekst klapt ter plekke open. Een lange tekst wordt tot vier regels getoond, de rest vouwt weg achter een beletselteken. Deze zin is met opzet lang zodat je het kunt zien en ziet hoe de regels afbreken op de breedte van de kaart. Waar het afkapt hangt af van de breedte van de kaart en de tekstgrootte, dus bij een groter formaat vouwt dezelfde zin eerder weg. De hele tekst blijft in het Berichtencentrum staan.|Przewiń na karcie, a cały tekst rozwinie się na miejscu. Długa treść pokazuje się do czterech wierszy, reszta chowa się za wielokropkiem. To zdanie jest celowo długie, żebyś mógł to zobaczyć i sprawdzić, jak wiersze łamią się do szerokości karty. Miejsce przycięcia zależy od szerokości karty i wielkości tekstu, więc przy większym rozmiarze to samo zdanie zwija się wcześniej. Cała treść zostaje w Centrum powiadomień.|Kartın üzerinde kaydırın, metnin tamamı olduğu yerde açılır. Uzun bir metin en fazla dört satır gösterilir, gerisi üç noktanın arkasına katlanır. Bu cümle bunu gözünüzle görebilmeniz ve satırların kart genişliğine göre nasıl bölündüğünü izleyebilmeniz için bilerek uzun yazıldı. Kesme noktası kart genişliğine ve yazı boyutuna göre değişir; büyük boyutta aynı cümle daha erken katlanır. Metnin tamamı Bildirim Merkezi'nde kalır.|Cuộn trên thẻ là toàn bộ nội dung mở ra ngay tại chỗ. Nội dung dài chỉ hiện bốn dòng, phần còn lại được gấp lại sau dấu ba chấm. Câu này cố tình viết dài để bạn thấy điều đó, và xem các dòng ngắt theo chiều rộng của thẻ. Vị trí cắt phụ thuộc vào chiều rộng thẻ và cỡ chữ, nên cùng một câu sẽ gấp sớm hơn ở cỡ lớn. Toàn bộ nội dung vẫn nằm trong Trung tâm thông báo.|Gulir di atas kartu dan seluruh teksnya terbuka di tempat. Isi yang panjang ditampilkan sampai empat baris dan sisanya dilipat di balik elipsis. Kalimat ini sengaja dibuat panjang agar Anda bisa melihatnya, sekaligus melihat cara baris dipenggal mengikuti lebar kartu. Titik potongnya bergantung pada lebar kartu dan ukuran teks, jadi kalimat yang sama terlipat lebih awal pada ukuran besar. Teks utuhnya tetap ada di Pusat Notifikasi.
모양|Look|見た目|外观|外觀|Aspecto|Aspect|Aussehen|Look|Visual|Вид|Uiterlijk|Wygląd karty|Görünüş|Hình thức|Tampilan kartu
사진|Photo|写真|图片|圖片|Foto|Photo|Foto|Foto|Foto|Фото|Foto|Zdjęcie|Fotoğraf|Ảnh|Foto
사진 테스트|Photo test|写真のテスト|图片测试|圖片測試|Prueba de foto|Test photo|Fototest|Test foto|Teste de foto|Проверка фото|Fototest|Test zdjęcia|Fotoğraf testi|Thử ảnh|Uji foto
첨부된 사진이 있는 알림입니다.|A notification with a picture attached.|写真が添付された通知です。|这是一条附带图片的通知。|這是一則附帶圖片的通知。|Una notificación con una foto adjunta.|Une notification avec une photo jointe.|Eine Mitteilung mit angehängtem Bild.|Una notifica con una foto allegata.|Uma notificação com uma foto anexada.|Уведомление с прикреплённым фото.|Een melding met een foto erbij.|Powiadomienie ze zdjęciem w załączniku.|Fotoğraf ekli bir bildirim.|Thông báo có đính kèm ảnh.|Notifikasi dengan foto terlampir.
전화|Call|通話|来电|來電|Llamada|Appel|Anruf|Chiamata|Chamada|Звонок|Oproep|Połączenie|Arama|Cuộc gọi|Panggilan
전화 테스트|Call test|通話のテスト|来电测试|來電測試|Prueba de llamada|Test d'appel|Anruftest|Test chiamata|Teste de chamada|Проверка звонка|Oproeptest|Test połączenia|Arama testi|Thử cuộc gọi|Uji panggilan
수락|Accept|応答|接听|接聽|Aceptar|Accepter|Annehmen|Accetta|Aceitar|Принять|Opnemen|Odbierz|Kabul et|Nhận|Terima
거절|Decline|拒否|拒绝|拒絕|Rechazar|Refuser|Ablehnen|Rifiuta|Recusar|Отклонить|Weigeren|Odrzuć|Reddet|Từ chối|Tolak
수락과 거절 버튼이 달린 지속형 알림입니다.|A persistent notification with accept and decline.|応答と拒否のボタンが付いた持続型の通知です。|这是一条带接听和拒绝按钮的持续通知。|這是一則帶接聽和拒絕按鈕的持續通知。|Una notificación persistente con aceptar y rechazar.|Une notification persistante avec accepter et refuser.|Eine bleibende Mitteilung mit Annehmen und Ablehnen.|Una notifica persistente con accetta e rifiuta.|Uma notificação persistente com aceitar e recusar.|Постоянное уведомление с кнопками «Принять» и «Отклонить».|Een blijvende melding met opnemen en weigeren.|Trwałe powiadomienie z odbierz i odrzuć.|Kabul et ve reddet düğmeli kalıcı bildirim.|Thông báo giữ lại với nút nhận và từ chối.|Notifikasi menetap dengan terima dan tolak.
보내기|Send|送信|发送|發送|Enviar|Envoyer|Senden|Invia|Enviar|Отправить|Stuur|Wyślij|Gönder|Gửi|Kirim
고정|Pinned|固定|固定|固定|Fijada|Épinglée|Fixiert|Fissata|Fixada|Закреплённое|Vastgezet|Przypięte|Sabit|Ghim|Disematkan
모든 알람 닫기|Close all|すべて閉じる|全部关闭|全部關閉|Cerrar todo|Tout fermer|Alle schließen|Chiudi tutto|Fechar tudo|Закрыть все|Alles sluiten|Zamknij wszystkie|Tümünü kapat|Đóng tất cả|Tutup semua
로그인 시 실행|Open at login|ログイン時に起動|登录时启动|登入時啟動|Abrir al iniciar sesión|Ouvrir à la connexion|Beim Anmelden öffnen|Apri all'accesso|Abrir ao iniciar sessão|Запускать при входе|Openen bij inloggen|Uruchamiaj po zalogowaniu|Girişte aç|Mở khi đăng nhập|Buka saat login
디버그 로그|Debug log|デバッグログ|调试日志|除錯記錄|Registro de depuración|Journal de débogage|Debug-Protokoll|Log di debug|Log de depuração|Журнал отладки|Debuglog|Dziennik debugowania|Hata ayıklama günlüğü|Nhật ký gỡ lỗi|Log debug
메뉴 막대에서 숨기기|Hide from menu bar|メニューバーから隠す|从菜单栏隐藏|從選單列隱藏|Ocultar de la barra de menús|Masquer de la barre des menus|Aus der Menüleiste ausblenden|Nascondi dalla barra dei menu|Ocultar da barra de menus|Скрыть из строки меню|Verbergen uit menubalk|Ukryj z paska menu|Menü çubuğundan gizle|Ẩn khỏi thanh menu|Sembunyikan dari bilah menu
숨긴 뒤에는 Pounce 를 다시 실행하면 이 창이 열립니다.|Once hidden, launching Pounce again opens this window.|非表示にしたあとは、Pounce をもう一度起動するとこのウインドウが開きます。|隐藏后，再次启动 Pounce 会打开此窗口。|隱藏後，再次啟動 Pounce 會開啟此視窗。|Una vez oculto, al abrir Pounce de nuevo se muestra esta ventana.|Une fois masqué, relancer Pounce ouvre cette fenêtre.|Nach dem Ausblenden öffnet ein erneuter Start von Pounce dieses Fenster.|Una volta nascosto, riaprendo Pounce si apre questa finestra.|Depois de oculto, abrir o Pounce de novo mostra esta janela.|После скрытия повторный запуск Pounce открывает это окно.|Eenmaal verborgen opent Pounce opnieuw starten dit venster.|Po ukryciu ponowne uruchomienie Pounce otwiera to okno.|Gizlendikten sonra Pounce'u yeniden açmak bu pencereyi açar.|Sau khi ẩn, mở lại Pounce sẽ hiện cửa sổ này.|Setelah disembunyikan, membuka Pounce lagi akan menampilkan jendela ini.
접근성 권한|Accessibility|アクセシビリティ|辅助功能|輔助使用|Accesibilidad|Accessibilité|Bedienungshilfen|Accessibilità|Acessibilidade|Универсальный доступ|Toegankelijkheid|Dostępność|Erişilebilirlik|Trợ năng|Aksesibilitas
접근성 열기|Open Accessibility|アクセシビリティを開く|打开辅助功能|開啟輔助使用|Abrir Accesibilidad|Ouvrir Accessibilité|Bedienungshilfen öffnen|Apri Accessibilità|Abrir Acessibilidade|Открыть настройки|Toegankelijkheid openen|Otwórz Dostępność|Erişilebilirliği aç|Mở Trợ năng|Buka Aksesibilitas
허용됨|Granted|許可済み|已允许|已允許|Concedido|Autorisé|Erteilt|Concesso|Concedido|Разрешено|Toegestaan|Przyznano|İzin verildi|Đã cấp|Diizinkan
허용 안 됨 · 켜면 바로 붙습니다|Not granted · takes effect as soon as you turn it on|未許可 · オンにするとすぐ有効になります|未允许 · 打开后立即生效|未允許 · 開啟後立即生效|No concedido · se aplica al activarlo|Non autorisé · s'applique dès l'activation|Nicht erteilt · wirkt sofort nach dem Aktivieren|Non concesso · attivandolo ha effetto subito|Não concedido · aplica-se assim que ativar|Не разрешено · включите, и всё заработает|Niet toegestaan · direct actief na inschakelen|Brak zgody · działa od razu po włączeniu|İzin yok · açtığınızda hemen etkin olur|Chưa cấp · bật là dùng được ngay|Belum diizinkan · aktif begitu dinyalakan
로그 열기|Open log|ログを開く|打开日志|開啟記錄|Abrir registro|Ouvrir le journal|Protokoll öffnen|Apri log|Abrir log|Открыть журнал|Log openen|Otwórz dziennik|Günlüğü aç|Mở nhật ký|Buka log
Pounce 종료|Quit Pounce|Pounce を終了|退出 Pounce|結束 Pounce|Salir de Pounce|Quitter Pounce|Pounce beenden|Esci da Pounce|Sair do Pounce|Завершить Pounce|Pounce stoppen|Zakończ Pounce|Pounce'tan çık|Thoát Pounce|Keluar dari Pounce
버전 %@|Version %@|バージョン %@|版本 %@|版本 %@|Versión %@|Version %@|Version %@|Versione %@|Versão %@|Версия %@|Versie %@|Wersja %@|Sürüm %@|Phiên bản %@|Versi %@
업데이트 확인|Check for updates|アップデートを確認|检查更新|檢查更新|Buscar actualizaciones|Rechercher les mises à jour|Nach Updates suchen|Cerca aggiornamenti|Procurar atualizações|Проверить обновления|Op updates controleren|Sprawdź aktualizacje|Güncellemeleri denetle|Kiểm tra bản mới|Periksa pembaruan
확인 중…|Checking…|確認中…|检查中…|檢查中…|Comprobando…|Vérification…|Suche läuft…|Controllo…|Verificando…|Проверка…|Controleren…|Sprawdzanie…|Denetleniyor…|Đang kiểm tra…|Memeriksa…
최신 버전입니다|Up to date|最新です|已是最新版本|已是最新版本|Está actualizado|À jour|Auf dem neuesten Stand|È aggiornato|Está atualizado|Установлена последняя версия|Up-to-date|Masz najnowszą wersję|Güncel|Đã là bản mới nhất|Sudah versi terbaru
새 버전 %@|New version %@|新しいバージョン %@|新版本 %@|新版本 %@|Nueva versión %@|Nouvelle version %@|Neue Version %@|Nuova versione %@|Nova versão %@|Новая версия %@|Nieuwe versie %@|Nowa wersja %@|Yeni sürüm %@|Phiên bản mới %@|Versi baru %@
업데이트 설치|Install update|アップデートをインストール|安装更新|安裝更新|Instalar actualización|Installer la mise à jour|Update installieren|Installa aggiornamento|Instalar atualização|Установить обновление|Update installeren|Zainstaluj aktualizację|Güncellemeyi yükle|Cài bản mới|Pasang pembaruan
릴리스 열기|Open release page|リリースページを開く|打开发布页面|開啟發佈頁面|Abrir página de la versión|Ouvrir la page de version|Release-Seite öffnen|Apri pagina release|Abrir página da versão|Открыть страницу релиза|Releasepagina openen|Otwórz stronę wydania|Sürüm sayfasını aç|Mở trang phát hành|Buka halaman rilis
내려받는 중…|Downloading…|ダウンロード中…|下载中…|下載中…|Descargando…|Téléchargement…|Wird geladen…|Download in corso…|Baixando…|Загрузка…|Downloaden…|Pobieranie…|İndiriliyor…|Đang tải…|Mengunduh…
설치 중…|Installing…|インストール中…|安装中…|安裝中…|Instalando…|Installation…|Wird installiert…|Installazione…|Instalando…|Установка…|Installeren…|Instalowanie…|Yükleniyor…|Đang cài…|Memasang…
설치 완료 · 다시 시작합니다|Installed · restarting|インストール完了 · 再起動します|安装完成 · 正在重新启动|安裝完成 · 即將重新啟動|Instalado · reiniciando|Installé · redémarrage|Installiert · Neustart|Installato · riavvio|Instalado · reiniciando|Установлено · перезапуск|Geïnstalleerd · opnieuw starten|Zainstalowano · ponowne uruchamianie|Yüklendi · yeniden başlatılıyor|Đã cài · đang khởi động lại|Terpasang · memulai ulang
왼쪽 위|Top left|左上|左上|左上|Arriba izquierda|En haut à gauche|Oben links|In alto a sinistra|Superior esquerdo|Слева вверху|Linksboven|Lewy górny|Sol üst|Trên trái|Kiri atas
위 가운데|Top center|上中央|顶部居中|上方置中|Arriba centro|En haut au centre|Oben mittig|In alto al centro|Superior centro|Сверху по центру|Bovenaan midden|Górny środek|Üst orta|Trên giữa|Tengah atas
오른쪽 위|Top right|右上|右上|右上|Arriba derecha|En haut à droite|Oben rechts|In alto a destra|Superior direito|Справа вверху|Rechtsboven|Prawy górny|Sağ üst|Trên phải|Kanan atas
왼쪽 가운데|Left|左中央|左侧居中|左側置中|Izquierda centro|À gauche au centre|Links mittig|A sinistra al centro|Esquerda centro|Слева по центру|Links midden|Lewy środek|Sol orta|Giữa trái|Kiri tengah
가운데|Center|中央|居中|置中|Centro|Au centre|Mitte|Centro|Centro|По центру|Midden|Środek|Orta|Chính giữa|Tengah
오른쪽 가운데|Right|右中央|右侧居中|右側置中|Derecha centro|À droite au centre|Rechts mittig|A destra al centro|Direita centro|Справа по центру|Rechts midden|Prawy środek|Sağ orta|Giữa phải|Kanan tengah
왼쪽 아래|Bottom left|左下|左下|左下|Abajo izquierda|En bas à gauche|Unten links|In basso a sinistra|Inferior esquerdo|Слева внизу|Linksonder|Lewy dolny|Sol alt|Dưới trái|Kiri bawah
아래 가운데|Bottom center|下中央|底部居中|下方置中|Abajo centro|En bas au centre|Unten mittig|In basso al centro|Inferior centro|Снизу по центру|Onderaan midden|Dolny środek|Alt orta|Dưới giữa|Tengah bawah
오른쪽 아래|Bottom right|右下|右下|右下|Abajo derecha|En bas à droite|Unten rechts|In basso a destra|Inferior direito|Справа внизу|Rechtsonder|Prawy dolny|Sağ alt|Dưới phải|Kanan bawah
시스템|System|システム|系统|系統|Sistema|Système|System|Sistema|Sistema|Системный|Systeem|System|Sistem|Hệ thống|Sistem
라이트|Light|ライト|浅色|淺色|Claro|Clair|Hell|Chiaro|Claro|Светлая|Licht|Jasny|Açık|Sáng|Terang
다크|Dark|ダーク|深色|深色|Oscuro|Sombre|Dunkel|Scuro|Escuro|Тёмная|Donker|Ciemny|Koyu|Tối|Gelap
블루|Blue|ブルー|蓝色|藍色|Azul|Bleu|Blau|Blu|Azul|Синий|Blauw|Niebieski|Mavi|Xanh dương|Biru
퍼플|Purple|パープル|紫色|紫色|Morado|Violet|Violett|Viola|Roxo|Фиолетовый|Paars|Fioletowy|Mor|Tím|Ungu
핑크|Pink|ピンク|粉色|粉紅|Rosa|Rose|Pink|Rosa|Rosa|Розовый|Roze|Różowy|Pembe|Hồng|Merah muda
레드|Red|レッド|红色|紅色|Rojo|Rouge|Rot|Rosso|Vermelho|Красный|Rood|Czerwony|Kırmızı|Đỏ|Merah
오렌지|Orange|オレンジ|橙色|橘色|Naranja|Orange|Orange|Arancione|Laranja|Оранжевый|Oranje|Pomarańczowy|Turuncu|Cam|Oranye
옐로|Yellow|イエロー|黄色|黃色|Amarillo|Jaune|Gelb|Giallo|Amarelo|Жёлтый|Geel|Żółty|Sarı|Vàng|Kuning
그린|Green|グリーン|绿色|綠色|Verde|Vert|Grün|Verde|Verde|Зелёный|Groen|Zielony|Yeşil|Xanh lá|Hijau
그래파이트|Graphite|グラファイト|石墨色|石墨色|Grafito|Graphite|Graphit|Grafite|Grafite|Графитовый|Grafiet|Grafitowy|Grafit|Than chì|Grafit
작게|Small|小|小|小|Pequeño|Petit|Klein|Piccolo|Pequeno|Мелкий|Klein|Mały|Küçük|Nhỏ|Kecil
보통|Medium|標準|中|中|Mediano|Moyen|Mittel|Medio|Médio|Средний|Normaal|Średni|Orta|Vừa|Sedang
크게|Large|大|大|大|Grande|Grand|Groß|Grande|Grande|Крупный|Groot|Duży|Büyük|Lớn|Besar
샘플 알림|Sample notification|サンプル通知|示例通知|範例通知|Notificación de ejemplo|Notification d'exemple|Beispielmitteilung|Notifica di esempio|Notificação de exemplo|Пример уведомления|Voorbeeldmelding|Przykładowe powiadomienie|Örnek bildirim|Thông báo mẫu|Contoh notifikasi
이렇게 보입니다|This is how it looks|このように表示されます|显示效果如下|顯示效果如下|Así se ve|Voici le rendu|So sieht es aus|Ecco come appare|É assim que aparece|Вот как это выглядит|Zo ziet het eruit|Tak to wygląda|Böyle görünür|Trông sẽ như thế này|Tampilannya seperti ini
%d초|%ds|%d秒|%d秒|%d秒|%d s|%d s|%d s|%d s|%d s|%d с|%d s|%d s|%d sn|%d giây|%d dtk
설정…|Settings…|設定…|设置…|設定…|Ajustes…|Réglages…|Einstellungen…|Impostazioni…|Ajustes…|Настройки…|Instellingen…|Ustawienia…|Ayarlar…|Cài đặt…|Pengaturan…
닫기|Close|閉じる|关闭|關閉|Cerrar|Fermer|Schließen|Chiudi|Fechar|Закрыть|Sluiten|Zamknij|Kapat|Đóng|Tutup
테스트 알림|Test notification|テスト通知|测试通知|測試通知|Notificación de prueba|Notification de test|Testmitteilung|Notifica di prova|Notificação de teste|Тестовое уведомление|Testmelding|Powiadomienie testowe|Test bildirimi|Thông báo thử|Notifikasi uji
테스트 알림 %d/5|Test notification %d/5|テスト通知 %d/5|测试通知 %d/5|測試通知 %d/5|Notificación de prueba %d/5|Notification de test %d/5|Testmitteilung %d/5|Notifica di prova %d/5|Notificação de teste %d/5|Тестовое уведомление %d/5|Testmelding %d/5|Powiadomienie testowe %d/5|Test bildirimi %d/5|Thông báo thử %d/5|Notifikasi uji %d/5
연속으로 온 알림은 카드 하나에 묶입니다.|Notifications that arrive together share one card.|続けて届いた通知は 1 枚のカードにまとまります。|连续到达的通知会合并到一张卡片。|連續送達的通知會合併成一張卡片。|Las notificaciones seguidas se agrupan en una tarjeta.|Les notifications successives sont regroupées sur une carte.|Aufeinanderfolgende Mitteilungen teilen sich eine Karte.|Le notifiche consecutive si uniscono in un'unica scheda.|Notificações seguidas se juntam num só cartão.|Уведомления подряд объединяются в одну карточку.|Opeenvolgende meldingen delen één kaart.|Kolejne powiadomienia łączą się w jedną kartę.|Peş peşe gelen bildirimler tek kartta toplanır.|Các thông báo đến liên tiếp gộp vào một thẻ.|Notifikasi beruntun digabung dalam satu kartu.
고정 알림|Pinned notification|固定通知|固定通知|固定通知|Notificación fijada|Notification épinglée|Fixierte Mitteilung|Notifica fissata|Notificação fixada|Закреплённое уведомление|Vastgezette melding|Przypięte powiadomienie|Sabit bildirim|Thông báo ghim|Notifikasi tersemat
닫을 때까지 남습니다.|It stays until you close it.|閉じるまで残ります。|关闭前会一直显示。|關閉前會一直顯示。|Permanece hasta que la cierres.|Elle reste jusqu'à ce que vous la fermiez.|Sie bleibt, bis du sie schließt.|Resta finché non la chiudi.|Fica até você fechar.|Останется, пока не закроете.|Blijft staan tot je hem sluit.|Zostaje, dopóki go nie zamkniesz.|Kapatana kadar durur.|Sẽ ở lại cho đến khi bạn đóng.|Tetap ada sampai Anda menutupnya.
설정 > 정보에서 업데이트할 수 있습니다.|You can update it in Settings > About.|設定 > 情報からアップデートできます。|可在“设置 > 关于”中更新。|可在「設定 > 關於」中更新。|Puedes actualizar en Ajustes > Información.|Vous pouvez mettre à jour dans Réglages > À propos.|Du kannst in Einstellungen > Über aktualisieren.|Puoi aggiornare in Impostazioni > Info.|Você pode atualizar em Ajustes > Sobre.|Обновить можно в «Настройки > О программе».|Je kunt bijwerken via Instellingen > Info.|Możesz zaktualizować w Ustawienia > Informacje.|Ayarlar > Hakkında bölümünden güncelleyebilirsiniz.|Bạn có thể cập nhật trong Cài đặt > Giới thiệu.|Anda bisa memperbarui di Pengaturan > Tentang.
그리고 %d개 더|%d more|ほか %d 件|另外 %d 条|另外 %d 則|%d más|%d de plus|%d weitere|Altre %d|Mais %d|Ещё %d|Nog %d|Jeszcze %d|%d tane daha|%d nữa|%d lagi
릴리스 정보를 읽을 수 없습니다|Could not read the release feed|リリース情報を読み取れません|无法读取发布信息|無法讀取發佈資訊|No se pudo leer la información de la versión|Impossible de lire les informations de version|Release-Infos nicht lesbar|Impossibile leggere le informazioni di rilascio|Não foi possível ler as informações da versão|Не удалось прочитать сведения о релизе|Kan releasegegevens niet lezen|Nie można odczytać informacji o wydaniu|Sürüm bilgisi okunamadı|Không đọc được thông tin phát hành|Tidak dapat membaca info rilis
릴리스에 내려받을 파일이 없습니다|The release has no file to download|リリースにダウンロードできるファイルがありません|该版本没有可下载的文件|該版本沒有可下載的檔案|La versión no tiene archivo para descargar|Aucun fichier à télécharger dans cette version|Die Version enthält keine Datei zum Laden|La release non ha file da scaricare|A versão não tem arquivo para baixar|В релизе нет файла для загрузки|De release bevat geen bestand|Wydanie nie zawiera pliku do pobrania|Sürümde indirilecek dosya yok|Bản phát hành không có tệp để tải|Rilis tidak punya berkas untuk diunduh
내려받기 실패|Download failed|ダウンロードに失敗しました|下载失败|下載失敗|Error al descargar|Échec du téléchargement|Download fehlgeschlagen|Download non riuscito|Falha no download|Не удалось загрузить|Download mislukt|Pobieranie nie powiodło się|İndirme başarısız|Tải xuống thất bại|Unduhan gagal
압축을 풀지 못했습니다|Could not unpack the download|展開できませんでした|无法解压下载的文件|無法解壓縮下載的檔案|No se pudo descomprimir|Impossible de décompresser|Entpacken fehlgeschlagen|Impossibile estrarre|Não foi possível descompactar|Не удалось распаковать|Uitpakken mislukt|Nie udało się rozpakować|Arşiv açılamadı|Không giải nén được|Gagal mengekstrak
내려받은 파일에 앱이 없습니다|The download contains no app|ダウンロードにアプリが含まれていません|下载内容中没有应用|下載內容中沒有應用程式|La descarga no contiene la app|Le téléchargement ne contient pas l'app|Der Download enthält keine App|Il download non contiene l'app|O download não contém o app|В загрузке нет приложения|De download bevat geen app|Pobrany plik nie zawiera aplikacji|İndirilen dosyada uygulama yok|Tệp tải về không có ứng dụng|Unduhan tidak berisi aplikasi
서명을 확인하지 못했습니다|Could not verify the signature|署名を確認できませんでした|无法验证签名|無法驗證簽名|No se pudo verificar la firma|Impossible de vérifier la signature|Signatur nicht überprüfbar|Impossibile verificare la firma|Não foi possível verificar a assinatura|Не удалось проверить подпись|Kan handtekening niet verifiëren|Nie można zweryfikować podpisu|İmza doğrulanamadı|Không xác minh được chữ ký|Tanda tangan tidak dapat diverifikasi
다른 개발자가 서명한 빌드입니다|Signed by a different developer|別の開発者が署名したビルドです|该版本由其他开发者签名|該版本由其他開發者簽署|Firmado por otro desarrollador|Signé par un autre développeur|Von einem anderen Entwickler signiert|Firmato da un altro sviluppatore|Assinado por outro desenvolvedor|Подписано другим разработчиком|Ondertekend door een andere ontwikkelaar|Podpisane przez innego dewelopera|Farklı bir geliştirici imzalamış|Do nhà phát triển khác ký|Ditandatangani pengembang lain
%@ 폴더에 쓸 수 없습니다|Cannot write to the %@ folder|%@ フォルダに書き込めません|无法写入 %@ 文件夹|無法寫入 %@ 檔案夾|No se puede escribir en la carpeta %@|Écriture impossible dans le dossier %@|Kein Schreibzugriff auf den Ordner %@|Impossibile scrivere nella cartella %@|Não é possível gravar na pasta %@|Нет доступа на запись в папку %@|Kan niet schrijven naar map %@|Nie można zapisać w folderze %@|%@ klasörüne yazılamıyor|Không ghi được vào thư mục %@|Tidak bisa menulis ke folder %@
앱을 바꾸지 못했습니다|Could not replace the app|アプリを置き換えられませんでした|无法替换应用|無法取代應用程式|No se pudo reemplazar la app|Impossible de remplacer l'app|App konnte nicht ersetzt werden|Impossibile sostituire l'app|Não foi possível substituir o app|Не удалось заменить приложение|Kan de app niet vervangen|Nie udało się zastąpić aplikacji|Uygulama değiştirilemedi|Không thay được ứng dụng|Gagal mengganti aplikasi
"""
