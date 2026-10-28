# E-Reader Project

Android, iOS, web ve Windows için Flutter e-reader uygulaması.

## Özellikler

- Doğrudan açılan kitaplıkta büyük kare kapak veya liste görünümü; görünüm seçimi hatırlanır.
- Kitaba uzun basınca yazar, tür, boyut ve son hesaplanan sayfa sayısını gör. Kitap adları kesilmeden alt satıra geçer.
- Yeni eklenen metin kitaplarında gereksiz boşluklar ve sekmeler temizlenir, paragraf ayrımları korunur. Önceden kayıtlı kitapların metin konumları korunur.
- EPUB bölüm ayıklama hızlandırıldı; son üç çözümlenmiş kitap, toplam dört milyon karakter sınırıyla oturum içinde yeniden kullanılır. İlk görünür sayfa hazırlanır, toplam sayfa sayısı arka planda hesaplanır.
- Okuyucuda tek sayfa sayacı; normal yazı ölçeğinde telefon araçları tek satırda, daha geniş metin alanı.
- Ekran sayfaları ile EPUB'un sabit kitap sayfa işaretleri ayrılır. Sayaca dokunarak ilerlemeyi gör; dosyada kitap sayfa bilgisi yoksa kendi basılı baskının toplamını girerek açıkça tahmini olarak etiketlenen kitap konumunu kullan.
- Araştırılmış basılı baskı toplamları otomatik kullanılır. Kitap bilgilerinde referans baskı, kaynak ve son okuma düzeninde bir basılı sayfaya düşen ekran sayfası gösterilir. [Araştırma ve doğrulanamayan eserler](docs/PRINT_PAGE_RESEARCH_2026-10-26.md).
- Android gezinme çubuğu gizlidir; alt kenardan kaydırınca geçici açılır. Uygulamanın menü/ana sayfa/geri çubuğu görünür kalır.
- Sıkı listede yalnızca kitap adı görünür. İlk dokunuş sağda dosya bilgilerini açar; ikinci dokunuş kitabı açar.
- Android sistem klasör seçicisiyle bir cihaz klasörüne kalıcı okuma erişimi; EPUB, DOCX ve PDF dosyalarını kitaplıktan açma. Masaüstünde seçilen klasör yolu saklanır.
- Dosya ekledikten sonra, uygulamaya dönüldüğünde ve izlenen klasörde değişiklik olduğunda kitaplık otomatik yenilenir.
- EPUB ve DOCX metin okuma; PDF özgün sayfa görünümü.
- Şifresiz MOBI6/PalmDOC kitaplarını cihazda EPUB'a dönüştürüp kitaplığa ekleme; aynı içerik tekrar dönüştürülürse ikinci bir kopya eklenmez.
- Kitaplıkta dil seçicinin solunda okuma ayarları; kitap ekranında üstte arama ve çift dokunmayla tam ekran.
- Metin kitaplarında pinch hareketiyle yazı boyutu; yeniden sayfalama metnin sayfa içinde kalmasını sağlar.
- EPUB/DOCX ve dönüştürülmüş MOBI metninde uzun basarak tutamaçlı seçim, kalıcı alt çizgi ve seçilen metne bağlı düzenlenebilir not balonları.
- Türkçe, İngilizce ve Hollandaca arasında altı gömülü çevrimdışı sözlük. Diğer desteklenen diller için sözlük indirilmeden önce onay alınır. Sözlük penceresi kelime ve kalıp karşılıklarını gösterir; uzun seçimlerde kelimeler listelenir. Seçili metin ağa gönderilmez.
- Büyük metinlerde satır ölçümlerine dayalı, arayüze düzenli olarak zaman bırakan sayfalama; hazırlık ilerlemesi, boyut değişiminde eski hesabın iptali ve arka arkaya açma isteklerine karşı koruma.
- Önce kayıtlı konumun sayfaları açılır; toplam sayfa sayısı okumayı engellemeden hesaplanır. Hazırlık sırasında ileri/geri gezinme, arama ve ayraçla konuma gitme çalışır. Son üç sayfa düzeni bellekte tutulur.
- Sayfalar ekran genişliğini kullanır; dar kenar boşlukları, masaüstünde tek satır araç çubuğu ve araçlar gizlendiğinde genişleyen okuma alanı.
- Yazı tipi/boyutu, beş kâğıt teması ve metinlerde animasyonlu sayfa çevirme.
- EPUB/DOCX için 1, 2, 3 veya 4 sayfayı yan yana gösteren simgeli düğmeler; ekran daraldığında okunabilir sayfa sayısına uyum. Sayfa tercihi, dikey kaydırma ve satır aralığı kaydedilir. Ayarlar kitaplıktan açılır; sayfaya dokunarak araçları gizleyebilirsin.
- Bilgisayarda üst çubuktan geniş tek sayfa görünümüne geç; yazıyı büyüt/küçült düğmeleriyle ayarla. Tek sayfa seçimi yazı küçükse 24 puntoya yükseltir; sonraki tercihler kaydedilir.
- Dikey modda sayfa yapışması olmadan akıcı yukarı/aşağı kaydırma; dokunma, fare tekerleği ve trackpad desteği. Yukarı/aşağı oklar kaydırır, sağ/sol oklar sayfa çevirir. Page Up/Down ve boşlukla sayfa çevirme; azaltılmış hareket ayarına uyum.
- Sayfaya çift tıklayarak/dokunarak veya F11 ile tam ekrana gir/çık; Esc tam ekrandan çıkar. Windows'ta pencere çerçevesi kaldırılır, mobilde sistem çubukları gizlenir; web'de tarayıcının tam ekran API'si kullanılır. Kitap kapatılınca önceki pencere görünümü geri gelir.
- Görünüm tercihlerinin saklanması ve EPUB, DOCX, PDF kitaplarda kaldığı yerden devam etme.
- EPUB, DOCX ve PDF için tek dokunuşla kitap adı ve sayfa numarasıyla otomatik ayraç kaydı; eklenme tarihi ve saatiyle listeleme ve sayfaya dönme. Eski konum kayıtları korunur; geçmiş tarih bilinmiyorsa açıkça belirtilir.
- EPUB/DOCX metninde Türkçe büyük/küçük harf duyarsız arama, sonuç sayfasına gitme ve eşleşmeleri vurgulama. Arama ilk 200 eşleşmeyi gösterir.
- EPUB, DOCX ve PDF okuyucularında sayfa sayısına dokunarak sayfa numarasına gitme.

## Mevcut sınırlar

- EPUB/DOCX metin odaklıdır; görseller, tablolar ve özgün belge düzeni korunmaz.
- Yazım önerileri mevcut kitap adları ve sekiz klasik eserlik başlangıç sözlüğüne dayanır; tüm kitapları tanıyan bir servis değildir. Çapraz dil ad eşleştirmesi bu sözlükle sınırlıdır. Belirli bir dilde ücretsiz sürüm bulunacağı garanti edilmez.
- İnternet araması ilk 32 ücretsiz EPUB sonucunu gösterir; tüm interneti veya ücretli mağazaları taramaz. Katalog ağırlıklı olarak yabancı dildedir. Gutenberg kamu malı durumu ABD’ye göredir; yerel telif koşulları farklı olabilir. Web’de indirme kaynağın CORS izinlerine bağlıdır. Uzun süreli kullanım için Gutendex kendi sunucunu kurmanı önerir: https://gutendex.com/.
- MOBI/PRC dönüşümü şifresiz MOBI6 ve PalmDOC sıkıştırmasını destekler. HUFF/CDIC, KF8/AZW3 ve diğer Kindle biçimleri dönüştürülmez. DRM korumalı kitaplar açılamaz. Metin dönüşümünde görseller ve özgün sayfa düzeni korunmaz.
- Web kitaplığı bu oturumla sınırlıdır; kalıcı depolama ve cihaz klasörü tarama yoktur.
- Varsayılan e-books klasöründeki kitaplar korunur. Android’de seçilen klasöre yalnızca kullanıcının verdiği kalıcı okuma izniyle erişilir; kaynak dosyalar değiştirilmez.
- Tarama alt klasörlere inmez. Dosya başına 100 MB sınırı vardır.
- PDF'de yazı tipi değişimi ve metin okuyucusunun sayfa efekti uygulanmaz. Okuma konumu ve tercihler cihazda saklanır; cihazlar arası eşitleme yoktur.

## Geliştirme

```sh
flutter pub get
flutter run -d chrome
flutter run -d windows
```

Android için bağlı cihaz veya emülatör kullanılabilir. iOS derlemesi için macOS, Xcode ve iOS 15+ gerekir.

```sh
flutter analyze
flutter test
flutter build web
```

Uygulama simgelerini yeniden üretmek için:

```sh
dart run flutter_launcher_icons
```

Lora ve Literata fontlarının açık lisansları assets/fonts klasöründedir.
