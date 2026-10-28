# Ticari sürüm hazırlığı

Kararlar: ücretsiz temel sürüm ve aylık/yıllık Pro abonelik. Hedefler: Android, iPhone/iPad, Windows ve macOS. Bu belge uygulanacak ürün ve yayın planıdır; ödeme, bulut eşitleme ve Pro satışı henüz etkin değildir.

## Ürün sınırı

Ücretsiz sürüm: yerel kitaplık, desteklenen kitapları okuma, erişilebilir yazı ayarları, 1–4 sayfa, iki yönlü kaydırma, ayraçlar, kitap içi arama ve ücretsiz kamu malı EPUB araması. Kullanıcının mevcut kitapları ve ayraçları abonelik bitince de erişilebilir kalır.

Pro için önerilen sürekli değer: cihazlar arasında konum/ayraç eşitleme, isteğe bağlı şifreli bulut yedekleme, gelişmiş notlar ve dışa aktarma. Bunlar mevcut uygulamada sunulmuş özellikler değildir; satın alma ekranı ancak uygulanıp doğrulandıktan sonra gösterilecek.

Aylık ve yıllık teklifler aynı Pro haklarını verir. Fiyat metni mağazadan ve kullanıcının para biriminden alınır; sabit fiyat veya gelir garantisi kodlanmaz. Deneme süresi ve indirimler ayrıca kararlaştırılır.

## Satın alma ve hesap akışı

1. Temel okuma hesap gerektirmez. Cihazlar arasında Pro için kullanıcının isteğiyle ortak hesap açılır.
2. Google Play ve Apple StoreKit ürünleri mağazada tanımlanır. Web/Windows ödeme yolu dağıtım kanalına göre ayrıca seçilir.
3. Satın alma kanıtı sunucuda mağazayla doğrulanır. Bekleyen ödeme Pro açmaz. Aynı işlem tekrar geldiğinde ikinci hak üretilmez.
4. Sunucu; etkin, ödeme bekliyor, ödemesiz ek süre, süresi dolmuş ve iade/iptal edilmiş durumlarını yönetir. Yenileme ve iadeler mağaza bildirimleriyle güncellenir.
5. Satın alımları geri yükleme ve aboneliği yönetme yolları görünür olur. Otomatik yenilemenin kapatılması, ödenmiş dönemin sonuna kadar erişimi korur.
6. Yerel tercihlerdeki bir `pro=true` değeri ödeme kanıtı olarak kabul edilmez. Kitap dosyaları kullanıcı açıkça eşitlemeyi açmadan yüklenmez.

Google, satın alımların erişim verilmeden önce doğrulanmasını ve hassas mantığın sunucuda tutulmasını önerir: https://developer.android.com/google/play/billing/security
Apple, aboneliklerin sürekli değer sunmasını ve abonelik durumlarının yönetilmesini açıklar: https://developer.apple.com/app-store/subscriptions/
Platformlar arası erişim için kullanıcı ve hak eşleştirmesi uygulamanın sorumluluğundadır: https://developer.apple.com/documentation/StoreKit/handling-subscriptions-billing

## Yayından önce tamamlanacak somut işler

- Marka adı, üretim paket kimlikleri, destek e-postası ve alan adı seçimi. Şimdiki `com.example.e_reader` deneme kimliğidir.
- Mağaza hesapları, imzalama anahtarları ve aylık/yıllık ürün kimlikleri. Gizli bilgiler kaynak koduna konmaz.
- Ödeme doğrulama sunucusu, hesap sistemi ve Pro hizmetlerinin uygulanması.
- Gizlilik ve kullanım metinleri; veri silme, satın alma geri yükleme, iptal ve destek akışları. İşletme/ülke bilgileri olmadan nihai hukuki metin hazırlanmaz.
- Dillerin anadil incelemesi, büyük yazı ve ekran okuyucu kontrolleri; yavaş internet ve çevrimdışı okuma testleri.
- Gerçek mağaza test ortamında satın alma, yenileme, iptal, iade, süre bitimi, cihaz değişimi ve hesap değiştirme senaryoları.
- Kitap arama/indirme kataloğunun telif sınırlarının hedef ülkelerde incelenmesi. Kamu malı katalog erişimi ticari dağıtım hakkı garantisi değildir.

## Platform doğrulaması

Android APK ve Windows uygulaması bu Windows bilgisayarda derlenebilir. iOS ve macOS hedefleri kaynak olarak hazırlanır; imzalama ve cihaz doğrulaması Mac/Xcode ortamında yapılmalıdır. macOS hedefi bu oturumda Mac üzerinde derlenmiş sayılmaz.

Flutter platform araç gereksinimleri: https://docs.flutter.dev/platform-integration

Depodaki CI akışı test ve imzasız derleme kontrolü içindir. Mağazaya otomatik yayınlama ve ödeme hesabı bağlantısı içermez.
