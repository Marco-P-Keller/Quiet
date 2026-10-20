"""What the screenshots say, in the languages `make-shots.py` cannot set itself.

`make-shots.py` draws the six languages the app speaks with Pillow, and Pillow
here has no text shaping: Arabic comes out as unjoined letters, Hebrew back to
front, Hindi and Thai with their marks in the wrong places. Everything below is
set by Chrome instead (`render-captions.mjs`), which shapes all of it, and laid
over the same phone on the same ground.

The app itself is in English in every one of these, so the phone shows English
and the words around it are the language of the listing — the same bargain the
store description strikes in one line above its disclaimer.

Eight entries per language, in the order the slides are swiped through:

    feed-open · curtain · settings · absent · feed · record · setup · opening

`*` marks the heavy run, `\\n` the line break of the headline. `struck` is the
slide with no phone on it: what Quiet takes out, in the words Instagram uses for
it in that language, and nothing else — suggested posts and autoplay are not on
the list because the app does not take them out.
"""

# language -> (writing direction, [(headline, subline) x 8], struck)
CAPTIONS = {
    "it": ("ltr", [
        ("Instagram,\nsenza *Reel*.", "Lo stesso feed, le stesse persone, gli stessi messaggi. La scheda infinita semplicemente non c’è più."),
        ("Non *cinque minuti*\nin più.", "Quando il tempo di oggi è finito, Quiet chiude la giornata — e sullo schermo non resta nulla con cui discutere."),
        ("Meno *adesso*.\nPiù *la prossima settimana*.", "Abbassare il limite giornaliero vale subito. Alzarlo aspetta una settimana e parte dal giorno dopo."),
        ("Cosa *non* c’è.", "Tolto per indirizzo, non nascosto dietro un’impostazione che potresti riattivare alle undici di sera."),
        ("Il tuo feed.\nLe tue *persone*.", "Storie, messaggi, commenti, profili — tutto, esattamente dov’era, sulla pagina di Instagram."),
        ("I giorni\n*alle tue spalle*.", "Una barra per ogni giorno, una linea tratteggiata sul tuo limite e il giorno di partenza."),
        ("L’intero patto,\n*subito*.", "Cosa toglie Quiet e cosa lascia stare, nella prima schermata, prima che tu scelga qualsiasi cosa."),
        ("Nessun account.\nNessun *tracciamento*.", "Nessun server nostro, nessuna analisi, nessuna pubblicità. Niente da controllare e niente da battere."),
    ], ["Reel", "Esplora", "Serie e report"]),

    "nl": ("ltr", [
        ("Instagram,\nzonder *Reels*.", "Dezelfde feed, dezelfde mensen, dezelfde berichten. Het tabblad dat nooit ophoudt is gewoon weg."),
        ("Geen *vijf minuten*\nmeer.", "Is de tijd van vandaag op, dan sluit Quiet de dag — en er staat niets op het scherm om mee te discussiëren."),
        ("Minder *nu*.\nMeer *volgende week*.", "Je daglimiet verlagen werkt direct. Verhogen wacht een week en gaat de volgende dag in."),
        ("Wat er *niet* is.", "Eruit gehaald op adres, niet verstopt achter een instelling die je om elf uur ’s avonds weer aan kunt zetten."),
        ("Je feed.\nJouw *mensen*.", "Verhalen, berichten, reacties, profielen — alles, precies waar het was, op de eigen pagina van Instagram."),
        ("De dagen\n*achter je*.", "Een balk voor elke dag, een stippellijn bij je limiet en de dag waarmee je begon."),
        ("De hele ruil,\n*vooraf*.", "Wat Quiet weghaalt en wat het met rust laat, op het eerste scherm, voordat je iets kiest."),
        ("Geen account.\nGeen *tracking*.", "Geen servers van ons, geen analyse, geen reclame. Niets om na te kijken en niets om te verslaan."),
    ], ["Reels", "Verkennen", "Reeksen en rapporten"]),

    "pl": ("ltr", [
        ("Instagram\nbez *Reels*.", "Ten sam feed, ci sami ludzie, te same wiadomości. Karty, która nigdy się nie kończy, po prostu nie ma."),
        ("Żadnych *pięciu minut*\nwięcej.", "Gdy dzisiejszy czas się skończy, Quiet zamyka dzień — a na ekranie nie ma nic, z czym można by się spierać."),
        ("Mniej *teraz*.\nWięcej *za tydzień*.", "Obniżenie dziennego limitu działa od razu. Podwyższenie czeka tydzień i zaczyna się następnego dnia."),
        ("Czego *tu nie ma*.", "Usunięte według adresu, a nie schowane za ustawieniem, które o jedenastej wieczorem można znów włączyć."),
        ("Twój feed.\nTwoi *ludzie*.", "Relacje, wiadomości, komentarze, profile — wszystko dokładnie tam, gdzie było, na własnej stronie Instagrama."),
        ("Dni\n*za tobą*.", "Słupek na każdy dzień, przerywana linia na twoim limicie i dzień startu."),
        ("Cała umowa,\n*na wstępie*.", "Co Quiet zabiera, a czego nie rusza — na pierwszym ekranie, zanim cokolwiek wybierzesz."),
        ("Bez konta.\nBez *śledzenia*.", "Żadnych naszych serwerów, żadnej analityki, żadnych reklam. Nic do sprawdzania i nic do pobicia."),
    ], ["Reels", "Eksploruj", "Serie i raporty"]),

    "tr": ("ltr", [
        ("Instagram,\n*Reels* olmadan.", "Aynı akış, aynı insanlar, aynı mesajlar. Hiç bitmeyen sekme artık yok."),
        ("*Beş dakika* daha\nyok.", "Bugünün süresi bitince Quiet günü kapatır — ekranda tartışılacak hiçbir şey kalmaz."),
        ("Şimdi *daha az*.\n*Gelecek hafta* daha çok.", "Günlük sınırı düşürmek hemen geçerli olur. Yükseltmek bir hafta bekler ve ertesi gün başlar."),
        ("Burada *olmayanlar*.", "Adresine göre çıkarıldı; gece on birde geri açabileceğin bir ayarın arkasına saklanmadı."),
        ("Akışın.\n*İnsanların*.", "Hikâyeler, mesajlar, yorumlar, profiller — hepsi tam olduğu yerde, Instagram’ın kendi sayfasında."),
        ("Geride kalan\n*günler*.", "Her gün için bir çubuk, sınırında kesik bir çizgi ve başladığın gün."),
        ("Bütün takas,\n*baştan*.", "Quiet’in neyi aldığı, neye dokunmadığı — ilk ekranda, bir şey seçmeden önce."),
        ("Hesap yok.\n*İzleme* yok.", "Bize ait sunucu yok, analiz yok, reklam yok. Kontrol edecek bir şey, aşılacak bir şey yok."),
    ], ["Reels", "Keşfet", "Seriler ve raporlar"]),

    "sv": ("ltr", [
        ("Instagram,\nutan *Reels*.", "Samma flöde, samma människor, samma meddelanden. Fliken som aldrig tar slut är helt enkelt borta."),
        ("Inte *fem minuter*\ntill.", "När dagens tid är slut stänger Quiet dagen — och det finns inget på skärmen att argumentera med."),
        ("Mindre *nu*.\nMer *nästa vecka*.", "Att sänka din dagsgräns gäller direkt. Att höja den väntar en vecka och börjar nästa dag."),
        ("Det som *inte* finns.", "Borttaget på adress, inte gömt bakom en inställning du kan slå på igen klockan elva på kvällen."),
        ("Ditt flöde.\nDina *människor*.", "Stories, meddelanden, kommentarer, profiler — allt, precis där det var, på Instagrams egen sida."),
        ("Dagarna\n*bakom dig*.", "En stapel för varje dag, en streckad linje vid din gräns och dagen du började."),
        ("Hela villkoret,\n*på förhand*.", "Vad Quiet tar bort och vad det låter vara, på första skärmen, innan du väljer något."),
        ("Inget konto.\nIngen *spårning*.", "Inga servrar från oss, ingen analys, ingen reklam. Inget att kontrollera och inget att slå."),
    ], ["Reels", "Utforska", "Streaks och rapporter"]),

    "da": ("ltr", [
        ("Instagram\nuden *Reels*.", "Det samme feed, de samme mennesker, de samme beskeder. Fanen, der aldrig slutter, er simpelthen væk."),
        ("Ikke *fem minutter*\nmere.", "Når dagens tid er brugt, lukker Quiet dagen — og der er intet på skærmen at diskutere med."),
        ("Mindre *nu*.\nMere *næste uge*.", "Sænker du din daglige grænse, gælder det med det samme. Hæver du den, venter det en uge og starter næste dag."),
        ("Hvad der *ikke* er her.", "Fjernet på adresse, ikke gemt bag en indstilling, du kan slå til igen klokken elleve om aftenen."),
        ("Dit feed.\nDine *mennesker*.", "Stories, beskeder, kommentarer, profiler — alt sammen præcis hvor det var, på Instagrams egen side."),
        ("Dagene\n*bag dig*.", "En søjle for hver dag, en stiplet linje ved din grænse og den dag, du startede fra."),
        ("Hele handlen,\n*på forhånd*.", "Hvad Quiet fjerner, og hvad det lader være, på den første skærm, før du vælger noget."),
        ("Ingen konto.\nIngen *sporing*.", "Ingen servere fra os, ingen analyse, ingen reklamer. Intet at tjekke og intet at slå."),
    ], ["Reels", "Udforsk", "Streaks og rapporter"]),

    "no": ("ltr", [
        ("Instagram\nuten *Reels*.", "Samme feed, samme folk, samme meldinger. Fanen som aldri tar slutt er rett og slett borte."),
        ("Ikke *fem minutter*\nmer.", "Når dagens tid er brukt opp, stenger Quiet dagen — og det er ingenting på skjermen å diskutere med."),
        ("Mindre *nå*.\nMer *neste uke*.", "Å senke den daglige grensen gjelder med en gang. Å heve den venter en uke og starter neste dag."),
        ("Det som *ikke* er her.", "Fjernet på adresse, ikke gjemt bak en innstilling du kan slå på igjen klokken elleve om kvelden."),
        ("Feeden din.\nDine *folk*.", "Stories, meldinger, kommentarer, profiler — alt akkurat der det var, på Instagrams egen side."),
        ("Dagene\n*bak deg*.", "En stolpe for hver dag, en stiplet linje ved grensen din og dagen du startet fra."),
        ("Hele avtalen,\n*på forhånd*.", "Hva Quiet tar bort og hva det lar være, på den første skjermen, før du velger noe."),
        ("Ingen konto.\nIngen *sporing*.", "Ingen servere fra oss, ingen analyse, ingen reklame. Ingenting å sjekke og ingenting å slå."),
    ], ["Reels", "Utforsk", "Streaks og rapporter"]),

    "fi": ("ltr", [
        ("Instagram\nilman *Reelsejä*.", "Sama syöte, samat ihmiset, samat viestit. Loputon välilehti on yksinkertaisesti poissa."),
        ("Ei *viittä minuuttia*\nlisää.", "Kun päivän aika on käytetty, Quiet sulkee päivän — eikä ruudulla ole mitään, mistä kiistellä."),
        ("Vähemmän *nyt*.\nEnemmän *ensi viikolla*.", "Päivärajan laskeminen tulee voimaan heti. Nostaminen odottaa viikon ja alkaa seuraavana päivänä."),
        ("Mitä täällä *ei* ole.", "Poistettu osoitteen perusteella, ei piilotettu asetuksen taakse, jonka voisi kytkeä takaisin päälle kello 23."),
        ("Sinun syötteesi.\nSinun *ihmisesi*.", "Tarinat, viestit, kommentit, profiilit — kaikki juuri siellä missä ennenkin, Instagramin omalla sivulla."),
        ("Päivät\n*takanasi*.", "Palkki jokaiselle päivälle, katkoviiva rajasi kohdalla ja päivä, josta aloitit."),
        ("Koko vaihtokauppa,\n*heti alussa*.", "Mitä Quiet ottaa pois ja mihin se ei koske, ensimmäisellä ruudulla, ennen kuin valitset mitään."),
        ("Ei tiliä.\nEi *seurantaa*.", "Ei meidän palvelimiamme, ei analytiikkaa, ei mainontaa. Ei mitään tarkistettavaa eikä voitettavaa."),
    ], ["Reels", "Tutki", "Putket ja raportit"]),

    "ca": ("ltr", [
        ("Instagram,\nsense *Reels*.", "El mateix feed, la mateixa gent, els mateixos missatges. La pestanya que no s’acaba mai simplement ja no hi és."),
        ("Ni *cinc minuts*\nmés.", "Quan s’acaba el temps d’avui, Quiet tanca el dia — i a la pantalla no hi ha res amb què discutir."),
        ("Menys *ara*.\nMés *la setmana vinent*.", "Baixar el límit diari s’aplica a l’instant. Pujar-lo espera una setmana i comença l’endemà."),
        ("El que *no* hi és.", "Tret per adreça, no amagat darrere d’un ajust que podries tornar a activar a les onze de la nit."),
        ("El teu feed.\nLa teva *gent*.", "Històries, missatges, comentaris, perfils — tot, exactament on era, a la pàgina pròpia d’Instagram."),
        ("Els dies\n*que deixes enrere*.", "Una barra per cada dia, una línia discontínua al teu límit i el dia del qual vas partir."),
        ("El tracte sencer,\n*d’entrada*.", "El que Quiet treu i el que deixa en pau, a la primera pantalla, abans que triïs res."),
        ("Cap compte.\nCap *rastreig*.", "Cap servidor nostre, cap anàlisi, cap publicitat. Res a comprovar i res a superar."),
    ], ["Reels", "Explora", "Ratxes i informes"]),

    "ro": ("ltr", [
        ("Instagram\nfără *Reels*.", "Același feed, aceiași oameni, aceleași mesaje. Fila care nu se termină niciodată pur și simplu a dispărut."),
        ("Fără *încă cinci*\nminute.", "Când timpul de azi s-a terminat, Quiet închide ziua — iar pe ecran nu rămâne nimic cu care să te târguiești."),
        ("Mai puțin *acum*.\nMai mult *peste o săptămână*.", "Scăderea limitei zilnice se aplică imediat. Mărirea așteaptă o săptămână și începe a doua zi."),
        ("Ce *nu* e aici.", "Scoase după adresă, nu ascunse în spatele unei setări pe care ai putea-o reactiva la unsprezece seara."),
        ("Feed-ul tău.\nOamenii *tăi*.", "Povești, mesaje, comentarii, profiluri — totul exact unde era, pe pagina proprie a Instagram."),
        ("Zilele\n*din urma ta*.", "O bară pentru fiecare zi, o linie întreruptă la limita ta și ziua de la care ai pornit."),
        ("Toată înțelegerea,\n*de la început*.", "Ce îți ia Quiet și ce lasă în pace, pe primul ecran, înainte să alegi ceva."),
        ("Fără cont.\nFără *urmărire*.", "Niciun server de-al nostru, nicio analiză, nicio publicitate. Nimic de verificat și nimic de învins."),
    ], ["Reels", "Explorare", "Serii și rapoarte"]),

    "hr": ("ltr", [
        ("Instagram\nbez *Reelsa*.", "Isti feed, isti ljudi, iste poruke. Kartice koja nikad ne prestaje jednostavno nema."),
        ("Nema više\n*pet minuta*.", "Kad dnevno vrijeme istekne, Quiet zatvara dan — a na zaslonu nema ničega s čime bi se moglo raspravljati."),
        ("Manje *odmah*.\nViše *sljedeći tjedan*.", "Snižavanje dnevnog ograničenja vrijedi odmah. Podizanje čeka tjedan dana i počinje idući dan."),
        ("Čega *nema*.", "Uklonjeno po adresi, a ne skriveno iza postavke koju je u jedanaest navečer moguće opet uključiti."),
        ("Tvoj feed.\nTvoji *ljudi*.", "Priče, poruke, komentari, profili — sve točno ondje gdje je bilo, na Instagramovoj vlastitoj stranici."),
        ("Dani\n*iza tebe*.", "Stupac za svaki dan, isprekidana crta na tvom ograničenju i dan od kojeg se krenulo."),
        ("Cijeli dogovor,\n*unaprijed*.", "Što Quiet oduzima, a što ostavlja na miru, na prvom zaslonu, prije nego išta odabereš."),
        ("Bez računa.\nBez *praćenja*.", "Nikakvih naših poslužitelja, nikakve analitike, nikakvog oglašavanja. Ništa za provjeriti i ništa za nadmašiti."),
    ], ["Reels", "Istraži", "Nizovi i izvještaji"]),

    "cs": ("ltr", [
        ("Instagram\nbez *Reels*.", "Stejný feed, stejní lidé, stejné zprávy. Záložka, která nikdy nekončí, prostě není."),
        ("Žádných *pět minut*\nnavíc.", "Když dnešní čas dojde, Quiet den zavře — a na obrazovce nezbude nic, o čem by se dalo handrkovat."),
        ("Méně *hned*.\nVíc *příští týden*.", "Snížení denního limitu platí okamžitě. Zvýšení počká týden a začne platit další den."),
        ("Co tu *není*.", "Odstraněno podle adresy, ne schováno za nastavením, které by šlo v jedenáct večer znovu zapnout."),
        ("Tvůj feed.\nTvoji *lidé*.", "Příběhy, zprávy, komentáře, profily — všechno přesně tam, kde to bylo, na vlastní stránce Instagramu."),
        ("Dny\n*za tebou*.", "Sloupec pro každý den, přerušovaná čára u tvého limitu a den, od kterého se začínalo."),
        ("Celý obchod,\n*předem*.", "Co Quiet bere a čeho se nedotýká, hned na první obrazovce, než cokoli zvolíš."),
        ("Žádný účet.\nŽádné *sledování*.", "Žádné naše servery, žádná analytika, žádná reklama. Nic ke kontrole a nic k překonání."),
    ], ["Reels", "Prozkoumat", "Série a reporty"]),

    "sk": ("ltr", [
        ("Instagram\nbez *Reels*.", "Rovnaký feed, rovnakí ľudia, rovnaké správy. Karta, ktorá sa nikdy nekončí, jednoducho nie je."),
        ("Žiadnych *päť minút*\nnavyše.", "Keď dnešný čas dôjde, Quiet deň zatvorí — a na obrazovke nezostane nič, o čom by sa dalo handrkovať."),
        ("Menej *hneď*.\nViac *budúci týždeň*.", "Zníženie denného limitu platí okamžite. Zvýšenie počká týždeň a začne platiť nasledujúci deň."),
        ("Čo tu *nie je*.", "Odstránené podľa adresy, nie skryté za nastavením, ktoré by sa dalo o jedenástej večer znova zapnúť."),
        ("Tvoj feed.\nTvoji *ľudia*.", "Príbehy, správy, komentáre, profily — všetko presne tam, kde to bolo, na vlastnej stránke Instagramu."),
        ("Dni\n*za tebou*.", "Stĺpec pre každý deň, prerušovaná čiara pri tvojom limite a deň, od ktorého sa začínalo."),
        ("Celý obchod,\n*vopred*.", "Čo Quiet berie a čoho sa nedotýka, hneď na prvej obrazovke, skôr než niečo zvolíš."),
        ("Žiadny účet.\nŽiadne *sledovanie*.", "Žiadne naše servery, žiadna analytika, žiadna reklama. Nič na kontrolu a nič na prekonanie."),
    ], ["Reels", "Preskúmať", "Série a reporty"]),

    "hu": ("ltr", [
        ("Instagram\n*Reels* nélkül.", "Ugyanaz a hírfolyam, ugyanazok az emberek, ugyanazok az üzenetek. A soha véget nem érő fül egyszerűen nincs ott."),
        ("Nincs még\n*öt perc*.", "Ha a mai idő elfogyott, a Quiet lezárja a napot — és a képernyőn nincs semmi, amivel vitatkozhatnál."),
        ("Kevesebb *most*.\nTöbb *jövő héten*.", "A napi korlát csökkentése azonnal érvénybe lép. Az emelése egy hetet vár, és másnap kezdődik."),
        ("Ami *nincs* itt.", "Cím szerint eltávolítva, nem egy olyan beállítás mögé rejtve, amelyet este tizenegykor visszakapcsolhatnál."),
        ("A te hírfolyamod.\nA te *embereid*.", "Történetek, üzenetek, hozzászólások, profilok — minden pontosan ott, ahol volt, az Instagram saját oldalán."),
        ("A mögötted\nhagyott *napok*.", "Egy oszlop minden napra, szaggatott vonal a korlátodnál, és a nap, ahonnan elindultál."),
        ("Az egész alku,\n*előre*.", "Mit vesz el a Quiet, és mihez nem nyúl — az első képernyőn, mielőtt bármit választanál."),
        ("Nincs fiók.\nNincs *követés*.", "Nincsenek saját szervereink, nincs elemzés, nincs reklám. Nincs mit ellenőrizni, és nincs mit felülmúlni."),
    ], ["Reels", "Felfedezés", "Sorozatok és jelentések"]),

    "id": ("ltr", [
        ("Instagram\ntanpa *Reels*.", "Feed yang sama, orang-orang yang sama, pesan yang sama. Tab yang tak ada habisnya itu sudah tidak ada."),
        ("Tak ada *lima menit*\nlagi.", "Saat waktu hari ini habis, Quiet menutup harinya — dan tidak ada apa pun di layar untuk ditawar."),
        ("Lebih sedikit *sekarang*.\nLebih banyak *minggu depan*.", "Menurunkan batas harian berlaku seketika. Menaikkannya menunggu seminggu dan mulai hari berikutnya."),
        ("Yang *tidak* ada di sini.", "Dihapus berdasarkan alamat, bukan disembunyikan di balik pengaturan yang bisa dinyalakan lagi pukul sebelas malam."),
        ("Feed-mu.\n*Orang-orangmu*.", "Cerita, pesan, komentar, profil — semuanya persis di tempatnya, di halaman Instagram sendiri."),
        ("Hari-hari\n*di belakangmu*.", "Satu batang untuk setiap hari, garis putus-putus di batasmu, dan hari kamu memulai."),
        ("Seluruh kesepakatan,\n*di muka*.", "Apa yang diambil Quiet dan apa yang dibiarkan, di layar pertama, sebelum kamu memilih apa pun."),
        ("Tanpa akun.\nTanpa *pelacakan*.", "Tanpa server kami, tanpa analitik, tanpa iklan. Tidak ada yang perlu diperiksa dan tidak ada yang perlu dikalahkan."),
    ], ["Reels", "Jelajahi", "Streak dan laporan"]),

    "ms": ("ltr", [
        ("Instagram\ntanpa *Reels*.", "Suapan yang sama, orang yang sama, mesej yang sama. Tab yang tidak berkesudahan itu sudah tiada."),
        ("Tiada lagi\n*lima minit*.", "Apabila masa hari ini habis, Quiet menutup hari itu — dan tiada apa-apa di skrin untuk dirundingkan."),
        ("Kurang *sekarang*.\nLebih *minggu depan*.", "Menurunkan had harian berkuat kuasa serta-merta. Menaikkannya menunggu seminggu dan bermula hari berikutnya."),
        ("Apa yang *tiada* di sini.", "Dibuang mengikut alamat, bukan disembunyikan di sebalik tetapan yang boleh dihidupkan semula pada pukul sebelas malam."),
        ("Suapan anda.\n*Orang* anda.", "Cerita, mesej, komen, profil — semuanya tepat di tempatnya, di halaman Instagram sendiri."),
        ("Hari-hari\n*di belakang anda*.", "Satu bar untuk setiap hari, garisan putus-putus pada had anda, dan hari anda bermula."),
        ("Seluruh pertukaran,\n*di awal*.", "Apa yang Quiet ambil dan apa yang dibiarkan, pada skrin pertama, sebelum anda memilih apa-apa."),
        ("Tiada akaun.\nTiada *penjejakan*.", "Tiada pelayan kami, tiada analitik, tiada pengiklanan. Tiada apa untuk disemak dan tiada apa untuk dikalahkan."),
    ], ["Reels", "Terokai", "Streak dan laporan"]),

    "vi": ("ltr", [
        ("Instagram,\nkhông có *Reels*.", "Cùng một bảng tin, cùng những người ấy, cùng những tin nhắn. Tab không bao giờ kết thúc đã biến mất."),
        ("Không thêm\n*năm phút* nữa.", "Khi hết thời gian hôm nay, Quiet đóng ngày lại — và trên màn hình không còn gì để mặc cả."),
        ("Bớt *ngay bây giờ*.\nThêm *tuần sau*.", "Hạ giới hạn hằng ngày có hiệu lực ngay. Tăng giới hạn phải chờ một tuần và bắt đầu từ ngày hôm sau."),
        ("Những gì *không* có ở đây.", "Được gỡ theo địa chỉ, không phải giấu sau một cài đặt mà bạn có thể bật lại lúc mười một giờ đêm."),
        ("Bảng tin của bạn.\n*Người* của bạn.", "Tin, tin nhắn, bình luận, trang cá nhân — tất cả đúng chỗ cũ, trên trang riêng của Instagram."),
        ("Những ngày\n*đã qua*.", "Một cột cho mỗi ngày, một đường nét đứt ở giới hạn của bạn, và ngày bạn bắt đầu."),
        ("Toàn bộ thỏa thuận,\n*nói trước*.", "Quiet lấy đi gì và để yên gì, ngay trên màn hình đầu tiên, trước khi bạn chọn bất cứ điều gì."),
        ("Không tài khoản.\nKhông *theo dõi*.", "Không có máy chủ của chúng tôi, không phân tích, không quảng cáo. Không có gì để kiểm tra và không có gì để vượt qua."),
    ], ["Reels", "Khám phá", "Chuỗi và báo cáo"]),

    "ru": ("ltr", [
        ("Instagram\nбез *Reels*.", "Та же лента, те же люди, те же сообщения. Бесконечной вкладки просто нет."),
        ("Никаких *ещё пяти*\nминут.", "Когда время на сегодня вышло, Quiet закрывает день — и на экране не остаётся ничего, с чем можно торговаться."),
        ("Меньше — *сразу*.\nБольше — *через неделю*.", "Снижение дневного лимита действует сразу. Повышение ждёт неделю и начинается на следующий день."),
        ("Чего *здесь нет*.", "Убрано по адресу, а не спрятано за настройкой, которую можно снова включить в одиннадцать вечера."),
        ("Твоя лента.\nТвои *люди*.", "Истории, сообщения, комментарии, профили — всё на своих местах, на собственной странице Instagram."),
        ("Дни\n*позади*.", "Столбик на каждый день, пунктирная линия на уровне лимита и день, с которого всё началось."),
        ("Вся сделка\n*сразу*.", "Что Quiet убирает и чего не трогает — на первом экране, до того как ты что-либо выберешь."),
        ("Без аккаунта.\nБез *слежки*.", "Никаких наших серверов, никакой аналитики, никакой рекламы. Нечего проверять и нечего побеждать."),
    ], ["Reels", "Интересное", "Серии и отчёты"]),

    "uk": ("ltr", [
        ("Instagram\nбез *Reels*.", "Та сама стрічка, ті самі люди, ті самі повідомлення. Вкладки, що не закінчується, просто немає."),
        ("Жодних *ще п’яти*\nхвилин.", "Коли час на сьогодні вичерпано, Quiet закриває день — і на екрані не лишається нічого, з чим можна торгуватися."),
        ("Менше — *одразу*.\nБільше — *за тиждень*.", "Зниження денного ліміту діє одразу. Підвищення чекає тиждень і починається наступного дня."),
        ("Чого *тут немає*.", "Прибрано за адресою, а не сховано за налаштуванням, яке можна знову ввімкнути об одинадцятій вечора."),
        ("Твоя стрічка.\nТвої *люди*.", "Історії, повідомлення, коментарі, профілі — все на своїх місцях, на власній сторінці Instagram."),
        ("Дні\n*позаду*.", "Стовпчик на кожен день, пунктирна лінія на рівні ліміту і день, з якого все почалося."),
        ("Вся угода\n*одразу*.", "Що Quiet забирає і чого не чіпає — на першому екрані, до того як ти щось обереш."),
        ("Без акаунта.\nБез *стеження*.", "Жодних наших серверів, жодної аналітики, жодної реклами. Нічого перевіряти і нічого перемагати."),
    ], ["Reels", "Цікаве", "Серії та звіти"]),

    "el": ("ltr", [
        ("Instagram\nχωρίς *Reels*.", "Η ίδια ροή, οι ίδιοι άνθρωποι, τα ίδια μηνύματα. Η καρτέλα που δεν τελειώνει ποτέ απλώς λείπει."),
        ("Ούτε *πέντε λεπτά*\nακόμη.", "Όταν τελειώσει ο χρόνος της ημέρας, το Quiet κλείνει τη μέρα — και στην οθόνη δεν μένει τίποτα να διαπραγματευτείς."),
        ("Λιγότερο *τώρα*.\nΠερισσότερο *σε μία εβδομάδα*.", "Η μείωση του ημερήσιου ορίου ισχύει αμέσως. Η αύξηση περιμένει μία εβδομάδα και ξεκινά την επόμενη μέρα."),
        ("Τι *δεν* υπάρχει εδώ.", "Αφαιρέθηκαν με βάση τη διεύθυνση, δεν κρύφτηκαν πίσω από μια ρύθμιση που θα μπορούσες να ενεργοποιήσεις ξανά στις έντεκα το βράδυ."),
        ("Η ροή σου.\nΟι *άνθρωποί* σου.", "Ιστορίες, μηνύματα, σχόλια, προφίλ — όλα ακριβώς εκεί που ήταν, στη δική της σελίδα του Instagram."),
        ("Οι μέρες\n*πίσω σου*.", "Μία μπάρα για κάθε μέρα, μια διακεκομμένη γραμμή στο όριό σου και η μέρα που ξεκίνησες."),
        ("Ολόκληρη η συμφωνία,\n*από την αρχή*.", "Τι αφαιρεί το Quiet και τι αφήνει ήσυχο, στην πρώτη οθόνη, πριν επιλέξεις οτιδήποτε."),
        ("Χωρίς λογαριασμό.\nΧωρίς *παρακολούθηση*.", "Κανένας δικός μας διακομιστής, καμία ανάλυση, καμία διαφήμιση. Τίποτα να ελέγξεις και τίποτα να νικήσεις."),
    ], ["Reels", "Εξερεύνηση", "Σερί και αναφορές"]),

    "ar": ("rtl", [
        ("إنستغرام،\nبدون *Reels*.", "الخلاصة نفسها، والأشخاص أنفسهم، والرسائل نفسها. علامة التبويب التي لا تنتهي ببساطة اختفت."),
        ("لا *خمس دقائق*\nأخرى.", "عندما ينتهي وقت اليوم، يُغلق Quiet اليوم — ولا يبقى على الشاشة شيء يمكن المساومة معه."),
        ("أقل *الآن*.\nوأكثر *الأسبوع القادم*.", "خفض الحد اليومي يسري فورًا. أما رفعه فينتظر أسبوعًا ويبدأ في اليوم التالي."),
        ("ما *ليس* هنا.", "أُزيل حسب العنوان، لا مخفيًا خلف إعداد يمكنك إعادة تشغيله في الحادية عشرة ليلًا."),
        ("خلاصتك.\n*أشخاصك*.", "القصص والرسائل والتعليقات والملفات الشخصية — كل شيء في مكانه تمامًا، على صفحة إنستغرام نفسها."),
        ("الأيام\n*خلفك*.", "عمود لكل يوم، وخط متقطع عند حدّك، واليوم الذي بدأت منه."),
        ("الصفقة كاملة،\n*منذ البداية*.", "ما يزيله Quiet وما يتركه، على الشاشة الأولى، قبل أن تختار أي شيء."),
        ("بلا حساب.\nبلا *تتبّع*.", "لا خوادم خاصة بنا، ولا تحليلات، ولا إعلانات. لا شيء للتحقق منه ولا شيء لتتفوق عليه."),
    ], ["Reels", "استكشاف", "السلاسل والتقارير"]),

    "he": ("rtl", [
        ("אינסטגרם,\nבלי *Reels*.", "אותו פיד, אותם אנשים, אותן הודעות. הלשונית שלא נגמרת פשוט איננה."),
        ("אין עוד\n*חמש דקות*.", "כשהזמן להיום נגמר, Quiet סוגר את היום — ואין על המסך שום דבר להתמקח איתו."),
        ("פחות *עכשיו*.\nיותר *בשבוע הבא*.", "הורדת המגבלה היומית נכנסת לתוקף מיד. העלאתה מחכה שבוע ומתחילה למחרת."),
        ("מה *אין* כאן.", "הוסר לפי כתובת, לא מוסתר מאחורי הגדרה שאפשר להפעיל מחדש באחת עשרה בלילה."),
        ("הפיד שלך.\n*האנשים* שלך.", "סטוריז, הודעות, תגובות, פרופילים — הכול בדיוק איפה שהיה, בדף של אינסטגרם עצמה."),
        ("הימים\n*שמאחוריך*.", "עמודה לכל יום, קו מקווקו במגבלה שלך, והיום שממנו התחלת."),
        ("העסקה כולה,\n*מראש*.", "מה Quiet לוקח ומה הוא משאיר בשקט, במסך הראשון, לפני שבחרת משהו."),
        ("בלי חשבון.\nבלי *מעקב*.", "אין שרתים שלנו, אין ניתוח נתונים, אין פרסומות. אין מה לבדוק ואין מה לנצח."),
    ], ["Reels", "חקר", "רצפים ודוחות"]),

    "hi": ("ltr", [
        ("इंस्टाग्राम,\n*Reels* के बिना।", "वही फ़ीड, वही लोग, वही संदेश। कभी ख़त्म न होने वाला टैब बस ग़ायब है।"),
        ("अब *पाँच मिनट*\nऔर नहीं।", "जब आज का समय ख़त्म हो जाता है, Quiet दिन बंद कर देता है — और स्क्रीन पर बहस करने के लिए कुछ नहीं बचता।"),
        ("अभी *कम*।\n*अगले हफ़्ते* ज़्यादा।", "रोज़ाना की सीमा घटाना तुरंत लागू होता है। बढ़ाना एक हफ़्ता रुकता है और अगले दिन से शुरू होता है।"),
        ("यहाँ जो *नहीं* है।", "पते के आधार पर हटाया गया, किसी ऐसी सेटिंग के पीछे छिपाया नहीं गया जिसे आप रात ग्यारह बजे फिर चालू कर सकें।"),
        ("आपकी फ़ीड।\nआपके *अपने लोग*।", "स्टोरी, संदेश, टिप्पणियाँ, प्रोफ़ाइल — सब कुछ ठीक वहीं, इंस्टाग्राम के अपने पेज पर।"),
        ("आपके\n*पीछे के दिन*।", "हर दिन के लिए एक पट्टी, आपकी सीमा पर एक बिंदीदार रेखा, और वह दिन जहाँ से आपने शुरुआत की।"),
        ("पूरा सौदा,\n*पहले ही*।", "Quiet क्या हटाता है और किसे छोड़ देता है, पहली ही स्क्रीन पर, कुछ भी चुनने से पहले।"),
        ("कोई खाता नहीं।\nकोई *ट्रैकिंग* नहीं।", "हमारा कोई सर्वर नहीं, कोई एनालिटिक्स नहीं, कोई विज्ञापन नहीं। जाँचने को कुछ नहीं, हराने को कुछ नहीं।"),
    ], ["Reels", "एक्सप्लोर", "स्ट्रीक और रिपोर्ट"]),

    "th": ("ltr", [
        ("Instagram\nที่ไม่มี *Reels*", "ฟีดเดิม คนเดิม ข้อความเดิม แท็บที่ไม่มีวันจบหายไปแล้ว"),
        ("ไม่มี\n*อีกห้านาที*", "เมื่อเวลาของวันนี้หมด Quiet จะปิดวัน และไม่มีอะไรบนหน้าจอให้ต่อรอง"),
        ("ลด *ทันที*\nเพิ่ม *สัปดาห์หน้า*", "การลดขีดจำกัดรายวันมีผลทันที ส่วนการเพิ่มต้องรอหนึ่งสัปดาห์และเริ่มวันถัดไป"),
        ("สิ่งที่ *ไม่มี* ที่นี่", "ถูกนำออกตามที่อยู่ ไม่ได้ซ่อนไว้หลังการตั้งค่าที่เปิดกลับได้ตอนห้าทุ่ม"),
        ("ฟีดของคุณ\n*คนของคุณ*", "สตอรี่ ข้อความ ความคิดเห็น โปรไฟล์ ทุกอย่างอยู่ที่เดิม บนหน้าเว็บของ Instagram เอง"),
        ("วันต่าง ๆ\n*ที่ผ่านมา*", "แท่งหนึ่งแท่งต่อวัน เส้นประที่ขีดจำกัดของคุณ และวันที่คุณเริ่มต้น"),
        ("ข้อแลกเปลี่ยนทั้งหมด\n*บอกก่อน*", "Quiet เอาอะไรออกและไม่แตะอะไร บอกไว้ที่หน้าจอแรก ก่อนที่คุณจะเลือกอะไร"),
        ("ไม่มีบัญชี\nไม่มี *การติดตาม*", "ไม่มีเซิร์ฟเวอร์ของเรา ไม่มีการวิเคราะห์ ไม่มีโฆษณา ไม่มีอะไรให้ตรวจ และไม่มีอะไรให้ชนะ"),
    ], ["Reels", "สำรวจ", "สตรีคและรายงาน"]),

    "ja": ("ltr", [
        ("Instagram、\n*Reels* なし。", "同じフィード、同じ人たち、同じメッセージ。終わらないタブは、ただなくなっています。"),
        ("あと*5分*は\nありません。", "今日の時間を使い切ると、Quiet はその日を閉じます。画面には、言い返せるものが何も残りません。"),
        ("下げるのは*今すぐ*。\n上げるのは*来週*。", "1日の上限を下げるとすぐに反映されます。上げる場合は1週間待ち、翌日から有効になります。"),
        ("ここに*ない*もの。", "アドレスで取り除いてあり、夜11時に元へ戻せる設定の裏に隠してあるわけではありません。"),
        ("あなたのフィード。\nあなたの*人たち*。", "ストーリーズ、メッセージ、コメント、プロフィール。すべてそのまま、Instagram 自身のページで。"),
        ("過ぎた\n*日々*。", "1日ごとに1本のバー、上限に引いた破線、そして始めた日。"),
        ("取引の全体を、\n*最初に*。", "Quiet が何を取り除き、何に手を触れないか。何かを選ぶ前の最初の画面で。"),
        ("アカウント不要。\n*追跡*なし。", "当社のサーバーも、分析も、広告もありません。確かめるものも、超えるものもありません。"),
    ], ["Reels", "発見", "ストリークとレポート"]),

    "ko": ("ltr", [
        ("Instagram,\n*Reels* 없이.", "같은 피드, 같은 사람들, 같은 메시지. 끝없이 이어지던 탭만 사라졌습니다."),
        ("*5분*만 더는\n없습니다.", "오늘의 시간을 다 쓰면 Quiet가 하루를 닫습니다. 화면에는 따질 것이 아무것도 남지 않습니다."),
        ("줄이는 건 *지금*.\n늘리는 건 *다음 주*.", "하루 한도를 낮추면 바로 적용됩니다. 높이면 일주일을 기다렸다가 다음 날부터 적용됩니다."),
        ("여기에 *없는* 것.", "주소 기준으로 제거했으며, 밤 11시에 다시 켤 수 있는 설정 뒤에 숨겨 두지 않았습니다."),
        ("당신의 피드.\n당신의 *사람들*.", "스토리, 메시지, 댓글, 프로필까지 모두 그대로, Instagram 자체 페이지에서."),
        ("지나간\n*날들*.", "하루마다 막대 하나, 한도에 점선 하나, 그리고 시작한 날."),
        ("거래 조건 전체를\n*처음부터*.", "Quiet가 무엇을 없애고 무엇을 그대로 두는지, 무엇을 고르기 전 첫 화면에서."),
        ("계정 없음.\n*추적* 없음.", "자체 서버도, 분석도, 광고도 없습니다. 확인할 것도, 이길 것도 없습니다."),
    ], ["Reels", "탐색", "스트릭과 리포트"]),

    "zh-Hans": ("ltr", [
        ("Instagram，\n没有 *Reels*。", "同样的信息流，同样的人，同样的消息。那个永无止境的标签页，已经不在了。"),
        ("不再有\n*“再五分钟”*。", "今天的时间用完，Quiet 就会关闭这一天，屏幕上没有任何可以讨价还价的东西。"),
        ("调低，*立即*生效。\n调高，*下周*生效。", "调低每日上限会立刻生效；调高则要等一周，并从次日开始。"),
        ("这里*没有*的东西。", "按地址移除，而不是藏在一个晚上十一点还能重新打开的设置后面。"),
        ("你的信息流。\n你的*人*。", "快拍、消息、评论、主页，一切原样，就在 Instagram 自己的页面上。"),
        ("身后的\n*日子*。", "每天一根柱子，在你的上限处画一条虚线，还有你开始的那一天。"),
        ("全部取舍，\n*开门见山*。", "Quiet 拿走什么、不碰什么，就在第一个屏幕上，在你做任何选择之前。"),
        ("无需账号。\n*不追踪*。", "没有我们的服务器，没有分析，没有广告。没什么要检查，也没什么要打败。"),
    ], ["Reels", "探索", "连续记录和报告"]),

    "zh-Hant": ("ltr", [
        ("Instagram，\n沒有 *Reels*。", "一樣的動態消息，一樣的人，一樣的訊息。那個永無止境的分頁，已經不在了。"),
        ("不再有\n*「再五分鐘」*。", "今天的時間用完，Quiet 就會關閉這一天，螢幕上沒有任何可以討價還價的東西。"),
        ("調低，*立即*生效。\n調高，*下週*生效。", "調低每日上限會立刻生效；調高則要等一週，並從隔天開始。"),
        ("這裡*沒有*的東西。", "依網址移除，而不是藏在一個晚上十一點還能重新開啟的設定後面。"),
        ("你的動態消息。\n你的*人*。", "限時動態、訊息、留言、個人檔案，一切照舊，就在 Instagram 自己的頁面上。"),
        ("身後的\n*日子*。", "每天一根長條，在你的上限處畫一條虛線，還有你開始的那一天。"),
        ("全部取捨，\n*開門見山*。", "Quiet 拿走什麼、不碰什麼，就在第一個畫面上，在你做任何選擇之前。"),
        ("不需帳號。\n*不追蹤*。", "沒有我們的伺服器，沒有分析，沒有廣告。沒什麼要檢查，也沒什麼要打敗。"),
    ], ["Reels", "探索", "連續紀錄與報告"]),

    "sl": ("ltr", [
        ("Instagram\nbrez *Reelsov*.", "Isti feed, isti ljudje, ista sporočila. Zavihka, ki se nikoli ne konča, preprosto ni več."),
        ("Nobenih *petih minut*\nveč.", "Ko je današnji čas porabljen, Quiet zapre dan — na zaslonu pa ne ostane nič, s čimer bi se lahko pogajal."),
        ("Manj *zdaj*.\nVeč *čez teden*.", "Znižanje dnevne omejitve velja takoj. Zvišanje počaka teden dni in začne veljati naslednji dan."),
        ("Česar *tu ni*.", "Odstranjeno po naslovu, ne skrito za nastavitvijo, ki jo je ob enajstih zvečer mogoče spet vklopiti."),
        ("Tvoj feed.\nTvoji *ljudje*.", "Zgodbe, sporočila, komentarji, profili — vse natanko tam, kjer je bilo, na Instagramovi lastni strani."),
        ("Dnevi\n*za teboj*.", "Stolpec za vsak dan, črtkana črta pri tvoji omejitvi in dan, od katerega se je začelo."),
        ("Cel dogovor,\n*vnaprej*.", "Kaj Quiet vzame in česa se ne dotakne — na prvem zaslonu, preden karkoli izbereš."),
        ("Brez računa.\nBrez *sledenja*.", "Brez naših strežnikov, brez analitike, brez oglaševanja. Nič za preverjati in nič za premagati."),
    ], ["Reels", "Razišči", "Nizi in poročila"]),

    "mr": ("ltr", [
        ("इंस्टाग्राम,\n*Reels* शिवाय.", "तोच फीड, तीच माणसं, तेच मेसेज. कधीही न संपणारा टॅब आता नाहीच."),
        ("आणखी *पाच मिनिटे*\nनाहीत.", "आजचा वेळ संपला की Quiet दिवस बंद करते — आणि स्क्रीनवर वाद घालण्यासारखे काहीच उरत नाही."),
        ("आत्ता *कमी*.\n*पुढच्या आठवड्यात* जास्त.", "रोजची मर्यादा कमी केली तर ती लगेच लागू होते. वाढवली तर आठवडाभर थांबते आणि पुढच्या दिवसापासून सुरू होते."),
        ("इथे *नसलेले*.", "पत्त्यानुसार काढले आहे, रात्री अकराला परत चालू करता येईल अशा सेटिंगमागे लपवलेले नाही."),
        ("तुमचा फीड.\nतुमची *माणसं*.", "स्टोरीज, मेसेज, कमेंट, प्रोफाइल — सगळे अगदी जिथे होते तिथेच, इंस्टाग्रामच्या स्वतःच्या पेजवर."),
        ("तुमच्या\n*मागचे दिवस*.", "प्रत्येक दिवसासाठी एक पट्टी, तुमच्या मर्यादेवर एक तुटक रेघ, आणि तुम्ही जिथून सुरू केले तो दिवस."),
        ("संपूर्ण व्यवहार,\n*आधीच*.", "Quiet काय काढते आणि कशाला हात लावत नाही — पहिल्याच स्क्रीनवर, काहीही निवडण्यापूर्वी."),
        ("खाते नाही.\n*ट्रॅकिंग* नाही.", "आमचे सर्व्हर नाहीत, अ‍ॅनालिटिक्स नाही, जाहिराती नाहीत. तपासायला काही नाही, हरवायला काही नाही."),
    ], ["Reels", "एक्सप्लोर", "स्ट्रीक आणि अहवाल"]),

    "bn": ("ltr", [
        ("Instagram,\n*Reels* ছাড়া।", "একই ফিড, একই মানুষ, একই মেসেজ। যে ট্যাব কখনও শেষ হয় না, সেটাই শুধু নেই।"),
        ("আর *পাঁচ মিনিট*\nনয়।", "আজকের সময় ফুরোলে Quiet দিনটি বন্ধ করে দেয় — আর স্ক্রিনে দরকষাকষি করার মতো কিছুই থাকে না।"),
        ("এখন *কম*।\n*আগামী সপ্তাহে* বেশি।", "দৈনিক সীমা কমালে তা সঙ্গে সঙ্গে কার্যকর হয়। বাড়ালে এক সপ্তাহ অপেক্ষা করে পরের দিন থেকে শুরু হয়।"),
        ("এখানে যা *নেই*।", "ঠিকানা ধরে সরানো হয়েছে, রাত এগারোটায় আবার চালু করা যায় এমন সেটিংয়ের আড়ালে লুকানো নয়।"),
        ("আপনার ফিড।\nআপনার *মানুষ*।", "স্টোরি, মেসেজ, মন্তব্য, প্রোফাইল — সবই ঠিক যেখানে ছিল সেখানেই, Instagram-এর নিজের পেজে।"),
        ("পেছনের\n*দিনগুলো*।", "প্রতিটি দিনের জন্য একটি দণ্ড, আপনার সীমায় একটি ডটেড রেখা, আর যে দিন থেকে শুরু করেছিলেন সেই দিন।"),
        ("পুরো লেনদেন,\n*শুরুতেই*।", "Quiet কী সরায় আর কী ছোঁয় না — প্রথম স্ক্রিনেই, কিছু বেছে নেওয়ার আগে।"),
        ("অ্যাকাউন্ট নেই।\n*ট্র্যাকিং* নেই।", "আমাদের সার্ভার নেই, অ্যানালিটিক্স নেই, বিজ্ঞাপন নেই। যাচাই করার কিছু নেই, হারানোর কিছু নেই।"),
    ], ["Reels", "এক্সপ্লোর", "স্ট্রিক ও রিপোর্ট"]),

    "gu": ("ltr", [
        ("Instagram,\n*Reels* વગર.", "એ જ ફીડ, એ જ લોકો, એ જ મેસેજ. ક્યારેય ન પૂરો થતો ટેબ બસ નથી."),
        ("હવે *પાંચ મિનિટ*\nવધુ નહીં.", "આજનો સમય પૂરો થાય એટલે Quiet દિવસ બંધ કરે છે — અને સ્ક્રીન પર દલીલ કરવા જેવું કંઈ બચતું નથી."),
        ("હમણાં *ઓછું*.\n*આવતા અઠવાડિયે* વધુ.", "રોજની મર્યાદા ઘટાડવી તરત લાગુ પડે છે. વધારવી અઠવાડિયું રાહ જુએ છે અને બીજા દિવસથી શરૂ થાય છે."),
        ("અહીં જે *નથી*.", "સરનામા પ્રમાણે કાઢી નાખ્યું છે, રાત્રે અગિયાર વાગ્યે ફરી ચાલુ કરી શકાય એવી સેટિંગ પાછળ છુપાવ્યું નથી."),
        ("તમારી ફીડ.\nતમારા *લોકો*.", "સ્ટોરીઝ, મેસેજ, કમેન્ટ, પ્રોફાઇલ — બધું બરાબર જ્યાં હતું ત્યાં જ, Instagram ના પોતાના પેજ પર."),
        ("પાછળના\n*દિવસો*.", "દરેક દિવસ માટે એક પટ્ટી, તમારી મર્યાદા પર એક તૂટક રેખા, અને જે દિવસથી તમે શરૂ કર્યું તે દિવસ."),
        ("આખો સોદો,\n*પહેલેથી*.", "Quiet શું કાઢે છે અને શું છોડી દે છે — પહેલી જ સ્ક્રીન પર, કંઈ પસંદ કરતા પહેલાં."),
        ("ખાતું નહીં.\n*ટ્રેકિંગ* નહીં.", "અમારું કોઈ સર્વર નહીં, એનાલિટિક્સ નહીં, જાહેરાત નહીં. તપાસવા જેવું કંઈ નહીં, હરાવવા જેવું કંઈ નહીં."),
    ], ["Reels", "એક્સપ્લોર", "સ્ટ્રીક અને રિપોર્ટ"]),

    "pa": ("ltr", [
        ("Instagram,\n*Reels* ਤੋਂ ਬਿਨਾਂ।", "ਉਹੀ ਫੀਡ, ਉਹੀ ਲੋਕ, ਉਹੀ ਸੁਨੇਹੇ। ਕਦੇ ਨਾ ਮੁੱਕਣ ਵਾਲਾ ਟੈਬ ਬਸ ਹੈ ਹੀ ਨਹੀਂ।"),
        ("ਹੁਣ *ਪੰਜ ਮਿੰਟ*\nਹੋਰ ਨਹੀਂ।", "ਜਦੋਂ ਅੱਜ ਦਾ ਸਮਾਂ ਮੁੱਕ ਜਾਂਦਾ ਹੈ, Quiet ਦਿਨ ਬੰਦ ਕਰ ਦਿੰਦਾ ਹੈ — ਅਤੇ ਸਕ੍ਰੀਨ ਉੱਤੇ ਬਹਿਸ ਕਰਨ ਲਈ ਕੁਝ ਨਹੀਂ ਬਚਦਾ।"),
        ("ਹੁਣ *ਘੱਟ*।\n*ਅਗਲੇ ਹਫ਼ਤੇ* ਵੱਧ।", "ਰੋਜ਼ ਦੀ ਹੱਦ ਘਟਾਉਣਾ ਤੁਰੰਤ ਲਾਗੂ ਹੁੰਦਾ ਹੈ। ਵਧਾਉਣਾ ਇੱਕ ਹਫ਼ਤਾ ਉਡੀਕਦਾ ਹੈ ਅਤੇ ਅਗਲੇ ਦਿਨ ਤੋਂ ਸ਼ੁਰੂ ਹੁੰਦਾ ਹੈ।"),
        ("ਇੱਥੇ ਜੋ *ਨਹੀਂ* ਹੈ।", "ਪਤੇ ਦੇ ਆਧਾਰ ਉੱਤੇ ਹਟਾਇਆ ਗਿਆ, ਰਾਤ ਗਿਆਰਾਂ ਵਜੇ ਮੁੜ ਚਾਲੂ ਕੀਤੀ ਜਾ ਸਕਣ ਵਾਲੀ ਸੈਟਿੰਗ ਪਿੱਛੇ ਲੁਕਾਇਆ ਨਹੀਂ ਗਿਆ।"),
        ("ਤੁਹਾਡੀ ਫੀਡ।\nਤੁਹਾਡੇ *ਲੋਕ*।", "ਸਟੋਰੀਆਂ, ਸੁਨੇਹੇ, ਟਿੱਪਣੀਆਂ, ਪ੍ਰੋਫ਼ਾਈਲਾਂ — ਸਭ ਕੁਝ ਬਿਲਕੁਲ ਉੱਥੇ ਹੀ ਜਿੱਥੇ ਸੀ, Instagram ਦੇ ਆਪਣੇ ਪੰਨੇ ਉੱਤੇ।"),
        ("ਪਿੱਛੇ ਰਹਿ ਗਏ\n*ਦਿਨ*।", "ਹਰ ਦਿਨ ਲਈ ਇੱਕ ਪੱਟੀ, ਤੁਹਾਡੀ ਹੱਦ ਉੱਤੇ ਇੱਕ ਬਿੰਦੀਦਾਰ ਲਕੀਰ, ਅਤੇ ਉਹ ਦਿਨ ਜਿੱਥੋਂ ਤੁਸੀਂ ਸ਼ੁਰੂ ਕੀਤਾ।"),
        ("ਪੂਰਾ ਸੌਦਾ,\n*ਪਹਿਲਾਂ ਹੀ*।", "Quiet ਕੀ ਹਟਾਉਂਦਾ ਹੈ ਅਤੇ ਕਿਸ ਨੂੰ ਛੱਡ ਦਿੰਦਾ ਹੈ — ਪਹਿਲੀ ਹੀ ਸਕ੍ਰੀਨ ਉੱਤੇ, ਕੁਝ ਵੀ ਚੁਣਨ ਤੋਂ ਪਹਿਲਾਂ।"),
        ("ਕੋਈ ਖਾਤਾ ਨਹੀਂ।\nਕੋਈ *ਟਰੈਕਿੰਗ* ਨਹੀਂ।", "ਸਾਡਾ ਕੋਈ ਸਰਵਰ ਨਹੀਂ, ਕੋਈ ਐਨਾਲਿਟਿਕਸ ਨਹੀਂ, ਕੋਈ ਇਸ਼ਤਿਹਾਰ ਨਹੀਂ। ਜਾਂਚਣ ਨੂੰ ਕੁਝ ਨਹੀਂ, ਹਰਾਉਣ ਨੂੰ ਕੁਝ ਨਹੀਂ।"),
    ], ["Reels", "ਐਕਸਪਲੋਰ", "ਸਟ੍ਰੀਕ ਅਤੇ ਰਿਪੋਰਟਾਂ"]),

    "ur": ("rtl", [
        ("Instagram،\n*Reels* کے بغیر۔", "وہی فیڈ، وہی لوگ، وہی پیغامات۔ کبھی ختم نہ ہونے والا ٹیب بس ہے ہی نہیں۔"),
        ("اب *پانچ منٹ*\nاور نہیں۔", "جب آج کا وقت ختم ہو جاتا ہے، Quiet دن بند کر دیتا ہے — اور اسکرین پر بحث کرنے کو کچھ نہیں بچتا۔"),
        ("ابھی *کم*۔\n*اگلے ہفتے* زیادہ۔", "روزانہ کی حد گھٹانا فوراً نافذ ہوتا ہے۔ بڑھانا ایک ہفتہ انتظار کرتا ہے اور اگلے دن سے شروع ہوتا ہے۔"),
        ("یہاں جو *نہیں* ہے۔", "پتے کی بنیاد پر ہٹایا گیا، کسی ایسی سیٹنگ کے پیچھے چھپایا نہیں گیا جسے رات گیارہ بجے دوبارہ آن کیا جا سکے۔"),
        ("آپ کی فیڈ۔\nآپ کے *لوگ*۔", "اسٹوریز، پیغامات، تبصرے، پروفائل — سب کچھ ٹھیک وہیں جہاں تھا، Instagram کے اپنے صفحے پر۔"),
        ("پیچھے رہ جانے والے\n*دن*۔", "ہر دن کے لیے ایک پٹی، آپ کی حد پر ایک ڈاٹڈ لکیر، اور وہ دن جہاں سے آپ نے آغاز کیا۔"),
        ("پورا سودا،\n*پہلے ہی*۔", "Quiet کیا ہٹاتا ہے اور کس کو چھوڑ دیتا ہے — پہلی ہی اسکرین پر، کچھ بھی چننے سے پہلے۔"),
        ("کوئی اکاؤنٹ نہیں۔\nکوئی *ٹریکنگ* نہیں۔", "ہمارا کوئی سرور نہیں، کوئی اینالیٹکس نہیں، کوئی اشتہار نہیں۔ جانچنے کو کچھ نہیں، ہرانے کو کچھ نہیں۔"),
    ], ["Reels", "ایکسپلور", "اسٹریک اور رپورٹیں"]),

    "ta": ("ltr", [
        ("Instagram,\n*Reels* இல்லாமல்.", "அதே ஃபீட், அதே மனிதர்கள், அதே செய்திகள். முடிவே இல்லாத டேப் மட்டும் இல்லை."),
        ("இன்னும் *ஐந்து நிமிடம்*\nஇல்லை.", "இன்றைய நேரம் முடிந்ததும் Quiet அந்த நாளை மூடிவிடுகிறது — திரையில் பேரம் பேச எதுவும் மிஞ்சுவதில்லை."),
        ("இப்போது *குறைவு*.\n*அடுத்த வாரம்* அதிகம்.", "தினசரி வரம்பைக் குறைத்தால் உடனே அமலாகும். உயர்த்தினால் ஒரு வாரம் காத்திருந்து அடுத்த நாள் தொடங்கும்."),
        ("இங்கே *இல்லாதவை*.", "முகவரி அடிப்படையில் நீக்கப்பட்டது, இரவு பதினொரு மணிக்கு மீண்டும் இயக்கக்கூடிய அமைப்பின் பின்னால் மறைக்கப்படவில்லை."),
        ("உங்கள் ஃபீட்.\nஉங்கள் *மனிதர்கள்*.", "ஸ்டோரிகள், செய்திகள், கருத்துகள், சுயவிவரங்கள் — எல்லாம் இருந்த இடத்திலேயே, Instagram-இன் சொந்தப் பக்கத்தில்."),
        ("பின்னால் விட்ட\n*நாட்கள்*.", "ஒவ்வொரு நாளுக்கும் ஒரு பட்டை, உங்கள் வரம்பில் ஒரு புள்ளிக்கோடு, நீங்கள் தொடங்கிய நாள்."),
        ("முழு ஒப்பந்தமும்,\n*முன்கூட்டியே*.", "Quiet எதை எடுத்துவிடுகிறது, எதைத் தொடுவதில்லை — முதல் திரையிலேயே, எதையும் தேர்ந்தெடுக்கும் முன்."),
        ("கணக்கு இல்லை.\n*கண்காணிப்பு* இல்லை.", "எங்கள் சர்வர் இல்லை, பகுப்பாய்வு இல்லை, விளம்பரம் இல்லை. சரிபார்க்க எதுவும் இல்லை, வெல்ல எதுவும் இல்லை."),
    ], ["Reels", "எக்ஸ்ப்ளோர்", "ஸ்ட்ரீக்குகள் & அறிக்கைகள்"]),

    "te": ("ltr", [
        ("Instagram,\n*Reels* లేకుండా.", "అదే ఫీడ్, అదే మనుషులు, అదే సందేశాలు. అంతులేని ట్యాబ్ మాత్రమే లేదు."),
        ("ఇక *ఐదు నిమిషాలు*\nఅదనంగా లేవు.", "ఈ రోజు సమయం అయిపోగానే Quiet ఆ రోజును మూసేస్తుంది — తెరపై వాదించడానికి ఏమీ మిగలదు."),
        ("ఇప్పుడు *తక్కువ*.\n*వచ్చే వారం* ఎక్కువ.", "రోజువారీ పరిమితిని తగ్గిస్తే వెంటనే అమలవుతుంది. పెంచితే ఒక వారం ఆగి, మరుసటి రోజు నుంచి మొదలవుతుంది."),
        ("ఇక్కడ *లేనివి*.", "చిరునామా ఆధారంగా తొలగించాం, రాత్రి పదకొండుకు తిరిగి ఆన్ చేయగల సెట్టింగ్ వెనుక దాచలేదు."),
        ("మీ ఫీడ్.\nమీ *మనుషులు*.", "స్టోరీలు, సందేశాలు, కామెంట్లు, ప్రొఫైళ్లు — అన్నీ ఉన్నచోటే, Instagram సొంత పేజీలో."),
        ("వెనుక ఉన్న\n*రోజులు*.", "ప్రతి రోజుకు ఒక బార్, మీ పరిమితి వద్ద ఒక చుక్కల గీత, మీరు ప్రారంభించిన రోజు."),
        ("మొత్తం ఒప్పందం,\n*ముందుగానే*.", "Quiet ఏం తీసేస్తుంది, ఏం ముట్టదు — మొదటి తెరపైనే, ఏదైనా ఎంచుకునే ముందు."),
        ("ఖాతా లేదు.\n*ట్రాకింగ్* లేదు.", "మా సర్వర్లు లేవు, అనలిటిక్స్ లేదు, ప్రకటనలు లేవు. తనిఖీ చేయడానికి ఏమీ లేదు, గెలవడానికి ఏమీ లేదు."),
    ], ["Reels", "ఎక్స్‌ప్లోర్", "స్ట్రీక్‌లు, నివేదికలు"]),

    "kn": ("ltr", [
        ("Instagram,\n*Reels* ಇಲ್ಲದೆ.", "ಅದೇ ಫೀಡ್, ಅದೇ ಜನರು, ಅದೇ ಸಂದೇಶಗಳು. ಎಂದೂ ಮುಗಿಯದ ಟ್ಯಾಬ್ ಮಾತ್ರ ಇಲ್ಲ."),
        ("ಇನ್ನು *ಐದು ನಿಮಿಷ*\nಇಲ್ಲ.", "ಇಂದಿನ ಸಮಯ ಮುಗಿದಾಗ Quiet ಆ ದಿನವನ್ನು ಮುಚ್ಚುತ್ತದೆ — ಪರದೆಯ ಮೇಲೆ ವಾದಿಸಲು ಏನೂ ಉಳಿಯುವುದಿಲ್ಲ."),
        ("ಈಗ *ಕಡಿಮೆ*.\n*ಮುಂದಿನ ವಾರ* ಹೆಚ್ಚು.", "ದಿನದ ಮಿತಿ ಕಡಿಮೆ ಮಾಡಿದರೆ ತಕ್ಷಣ ಜಾರಿಗೆ ಬರುತ್ತದೆ. ಹೆಚ್ಚಿಸಿದರೆ ಒಂದು ವಾರ ಕಾದು, ಮರುದಿನದಿಂದ ಶುರುವಾಗುತ್ತದೆ."),
        ("ಇಲ್ಲಿ *ಇಲ್ಲದ್ದು*.", "ವಿಳಾಸದ ಆಧಾರದ ಮೇಲೆ ತೆಗೆದುಹಾಕಲಾಗಿದೆ, ರಾತ್ರಿ ಹನ್ನೊಂದಕ್ಕೆ ಮತ್ತೆ ಆನ್ ಮಾಡಬಹುದಾದ ಸೆಟ್ಟಿಂಗ್ ಹಿಂದೆ ಅಡಗಿಸಿಲ್ಲ."),
        ("ನಿಮ್ಮ ಫೀಡ್.\nನಿಮ್ಮ *ಜನರು*.", "ಸ್ಟೋರಿಗಳು, ಸಂದೇಶಗಳು, ಕಾಮೆಂಟ್‌ಗಳು, ಪ್ರೊಫೈಲ್‌ಗಳು — ಎಲ್ಲವೂ ಇದ್ದ ಜಾಗದಲ್ಲೇ, Instagram ನ ಸ್ವಂತ ಪುಟದಲ್ಲಿ."),
        ("ಹಿಂದಿನ\n*ದಿನಗಳು*.", "ಪ್ರತಿ ದಿನಕ್ಕೆ ಒಂದು ಪಟ್ಟಿ, ನಿಮ್ಮ ಮಿತಿಯ ಬಳಿ ಒಂದು ಚುಕ್ಕೆ ರೇಖೆ, ಮತ್ತು ನೀವು ಶುರು ಮಾಡಿದ ದಿನ."),
        ("ಇಡೀ ವ್ಯವಹಾರ,\n*ಮೊದಲೇ*.", "Quiet ಏನನ್ನು ತೆಗೆದುಹಾಕುತ್ತದೆ, ಏನನ್ನು ಮುಟ್ಟುವುದಿಲ್ಲ — ಮೊದಲ ಪರದೆಯಲ್ಲೇ, ಏನನ್ನಾದರೂ ಆರಿಸುವ ಮೊದಲು."),
        ("ಖಾತೆ ಇಲ್ಲ.\n*ಟ್ರ್ಯಾಕಿಂಗ್* ಇಲ್ಲ.", "ನಮ್ಮ ಸರ್ವರ್ ಇಲ್ಲ, ಅನಾಲಿಟಿಕ್ಸ್ ಇಲ್ಲ, ಜಾಹೀರಾತು ಇಲ್ಲ. ಪರಿಶೀಲಿಸಲು ಏನೂ ಇಲ್ಲ, ಸೋಲಿಸಲು ಏನೂ ಇಲ್ಲ."),
    ], ["Reels", "ಎಕ್ಸ್‌ಪ್ಲೋರ್", "ಸ್ಟ್ರೀಕ್ ಮತ್ತು ವರದಿಗಳು"]),

    "ml": ("ltr", [
        ("Instagram,\n*Reels* ഇല്ലാതെ.", "അതേ ഫീഡ്, അതേ ആളുകൾ, അതേ സന്ദേശങ്ങൾ. ഒരിക്കലും തീരാത്ത ടാബ് മാത്രം ഇല്ല."),
        ("ഇനി *അഞ്ച് മിനിറ്റ്*\nഇല്ല.", "ഇന്നത്തെ സമയം തീരുമ്പോൾ Quiet ആ ദിവസം അടയ്ക്കുന്നു — സ്ക്രീനിൽ തർക്കിക്കാൻ ഒന്നും ബാക്കിയില്ല."),
        ("ഇപ്പോൾ *കുറവ്*.\n*അടുത്ത ആഴ്ച* കൂടുതൽ.", "ദിവസ പരിധി കുറച്ചാൽ ഉടൻ പ്രാബല്യത്തിൽ വരും. കൂട്ടിയാൽ ഒരാഴ്ച കാത്തിരുന്ന് അടുത്ത ദിവസം തുടങ്ങും."),
        ("ഇവിടെ *ഇല്ലാത്തത്*.", "വിലാസം നോക്കി നീക്കം ചെയ്തു, രാത്രി പതിനൊന്നിന് വീണ്ടും ഓണാക്കാവുന്ന ക്രമീകരണത്തിന് പിന്നിൽ ഒളിപ്പിച്ചിട്ടില്ല."),
        ("നിങ്ങളുടെ ഫീഡ്.\nനിങ്ങളുടെ *ആളുകൾ*.", "സ്റ്റോറികൾ, സന്ദേശങ്ങൾ, കമന്റുകൾ, പ്രൊഫൈലുകൾ — എല്ലാം ഉണ്ടായിരുന്നിടത്തു തന്നെ, Instagram-ന്റെ സ്വന്തം പേജിൽ."),
        ("പിന്നിലെ\n*ദിവസങ്ങൾ*.", "ഓരോ ദിവസത്തിനും ഒരു ബാർ, നിങ്ങളുടെ പരിധിയിൽ ഒരു ഡോട്ടഡ് വര, നിങ്ങൾ തുടങ്ങിയ ദിവസം."),
        ("മുഴുവൻ ഇടപാടും,\n*മുൻകൂട്ടി*.", "Quiet എന്ത് നീക്കുന്നു, എന്തിനെ തൊടുന്നില്ല — ആദ്യ സ്ക്രീനിൽ തന്നെ, എന്തെങ്കിലും തിരഞ്ഞെടുക്കുന്നതിന് മുമ്പ്."),
        ("അക്കൗണ്ട് ഇല്ല.\n*ട്രാക്കിംഗ്* ഇല്ല.", "ഞങ്ങളുടെ സെർവർ ഇല്ല, അനലിറ്റിക്സ് ഇല്ല, പരസ്യങ്ങളില്ല. പരിശോധിക്കാൻ ഒന്നുമില്ല, തോൽപ്പിക്കാൻ ഒന്നുമില്ല."),
    ], ["Reels", "എക്സ്പ്ലോർ", "സ്ട്രീക്കുകളും റിപ്പോർട്ടുകളും"]),

    "or": ("ltr", [
        ("Instagram,\n*Reels* ବିନା।", "ସେହି ଫିଡ୍, ସେହି ଲୋକ, ସେହି ମେସେଜ୍। କେବେ ଶେଷ ନ ହେଉଥିବା ଟ୍ୟାବ୍ କେବଳ ନାହିଁ।"),
        ("ଆଉ *ପାଞ୍ଚ ମିନିଟ୍*\nନାହିଁ।", "ଆଜିର ସମୟ ସରିଗଲେ Quiet ସେହି ଦିନକୁ ବନ୍ଦ କରିଦିଏ — ସ୍କ୍ରିନ୍‌ରେ ତର୍କ କରିବାକୁ କିଛି ରହେ ନାହିଁ।"),
        ("ଏବେ *କମ୍*।\n*ଆସନ୍ତା ସପ୍ତାହରେ* ଅଧିକ।", "ଦୈନିକ ସୀମା କମାଇଲେ ତୁରନ୍ତ ଲାଗୁ ହୁଏ। ବଢ଼ାଇଲେ ଏକ ସପ୍ତାହ ଅପେକ୍ଷା କରି ପରଦିନ ଆରମ୍ଭ ହୁଏ।"),
        ("ଏଠାରେ ଯାହା *ନାହିଁ*।", "ଠିକଣା ଅନୁସାରେ ହଟାଯାଇଛି, ରାତି ଏଗାରଟାରେ ପୁଣି ଚାଲୁ କରିହେବ ଏପରି ସେଟିଂ ପଛରେ ଲୁଚାଯାଇ ନାହିଁ।"),
        ("ଆପଣଙ୍କ ଫିଡ୍।\nଆପଣଙ୍କ *ଲୋକ*।", "ଷ୍ଟୋରି, ମେସେଜ୍, ମନ୍ତବ୍ୟ, ପ୍ରୋଫାଇଲ୍ — ସବୁ ଠିକ୍ ଯେଉଁଠି ଥିଲା ସେଠାରେ ହିଁ, Instagram ର ନିଜ ପୃଷ୍ଠାରେ।"),
        ("ପଛରେ ଥିବା\n*ଦିନଗୁଡ଼ିକ*।", "ପ୍ରତ୍ୟେକ ଦିନ ପାଇଁ ଗୋଟିଏ ବାର୍, ଆପଣଙ୍କ ସୀମାରେ ଗୋଟିଏ ବିନ୍ଦୁଯୁକ୍ତ ରେଖା, ଏବଂ ଆପଣ ଆରମ୍ଭ କରିଥିବା ଦିନ।"),
        ("ପୂରା ସଉଦା,\n*ଆଗରୁ ହିଁ*।", "Quiet କ’ଣ ହଟାଏ ଏବଂ କାହାକୁ ଛାଡ଼ିଦିଏ — ପ୍ରଥମ ସ୍କ୍ରିନ୍‌ରେ ହିଁ, କିଛି ବାଛିବା ପୂର୍ବରୁ।"),
        ("ଖାତା ନାହିଁ।\n*ଟ୍ରାକିଂ* ନାହିଁ।", "ଆମର ସର୍ଭର୍ ନାହିଁ, ଆନାଲିଟିକ୍ସ ନାହିଁ, ବିଜ୍ଞାପନ ନାହିଁ। ଯାଞ୍ଚ କରିବାକୁ କିଛି ନାହିଁ, ହରାଇବାକୁ କିଛି ନାହିଁ।"),
    ], ["Reels", "ଏକ୍ସପ୍ଲୋର୍", "ଷ୍ଟ୍ରିକ୍ ଓ ରିପୋର୍ଟ"]),
}

# Where a localisation has no captions of its own: the language it borrows, for
# the words and for the app's own screens. English in Australia and Canada is
# the English of `en`; Mexican Spanish, Canadian French and European Portuguese
# are what the app speaks as `es`, `fr` and `pt-BR`.
BORROWS = {
    "en-AU": "en", "en-CA": "en", "es-MX": "es", "fr-CA": "fr", "pt-PT": "pt-BR",
}

# App Store Connect localisation -> the key above (or in `make-shots.py`).
LOCALES = {
    "ar-SA": "ar", "ca": "ca", "cs": "cs", "da": "da", "el": "el", "fi": "fi",
    "he": "he", "hi": "hi", "hr": "hr", "hu": "hu", "id": "id", "it": "it",
    "ja": "ja", "ko": "ko", "ms": "ms", "nl-NL": "nl", "no": "no", "pl": "pl",
    "ro": "ro", "ru": "ru", "sk": "sk", "sv": "sv", "th": "th", "tr": "tr",
    "uk": "uk", "vi": "vi", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant",
    # The eleven App Store Connect added after the first thirty-nine.
    "sl-SI": "sl", "mr-IN": "mr", "bn-BD": "bn", "gu-IN": "gu", "pa-IN": "pa",
    "ur-PK": "ur", "ta-IN": "ta", "te-IN": "te", "kn-IN": "kn", "ml-IN": "ml",
    "or-IN": "or",
}
