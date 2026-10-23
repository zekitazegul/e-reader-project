# E-Reader Project

Android, iOS, web ve Windows için Flutter e-reader uygulaması.

## Özellikler

- Raf görünümünde kitaplık, Türkçe başlık araması ve cihazdan kitap ekleme.
- Mobil ve Windows uygulama belgelerinde e-books klasörünün oluşturulması ve taranması.
- Açılışta, uygulamaya dönüldüğünde ve elle yenilemede kitapları keşfetme.
- EPUB ve DOCX metin okuma; PDF özgün sayfa görünümü.
- Yazı tipi/boyutu, beş kâğıt teması ve metinlerde animasyonlu sayfa çevirme.
- Görünüm tercihlerinin saklanması ve EPUB, DOCX, PDF kitaplarda kaldığı yerden devam etme.

## Mevcut sınırlar

- EPUB/DOCX metin odaklıdır; görseller, tablolar ve özgün belge düzeni korunmaz.
- MOBI, PRC, AZW, AZW3, AZW4, KFX, KPF dosyaları kitaplığa eklenebilir; doğrudan okuma ve otomatik dönüşüm henüz yoktur. EPUB/PDF dönüşümü gerekir. DRM korumalı kitaplar açılamaz.
- Web kitaplığı bu oturumla sınırlıdır; kalıcı depolama ve cihaz klasörü tarama yoktur.
- Mobil/Windows e-books klasörü uygulamanın belgelerindedir; telefondaki herhangi bir genel klasörü otomatik taramaz. Tam yol uygulamada gösterilir. iOS Dosyalar paylaşımı açıktır.
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
