/// Trabzon Büyükşehir Belediyesi'ne bağlı 18 ilçe ve mahalleleri.
/// Kayıt ekranındaki İlçe -> Mahalle seçim menüsü bu veriden beslenir.
/// Kaynak: TÜİK 2023 nüfus verileri, Wikipedia (gerçek, resmi mahalle isimleri).
///
/// Not: Bu veri neredeyse hiç değişmeyeceği için Firestore yerine doğrudan
/// kod içinde (sabit olarak) tutuluyor - hem daha hızlı hem internetsiz çalışırü
class NeighborhoodsData {
  static const Map<String, List<String>> districtsAndNeighborhoods = {
    'Ortahisar': [
      '1 Nolu Beşirli', '1 Nolu Bostancı', '1 Nolu Erdoğdu', '2 Nolu Beşirli',
      '2 Nolu Bostancı', '2 Nolu Erdoğdu', '3 Nolu Erdoğdu', 'Ağıllı',
      'Akkaya', 'Akoluk', 'Aktoprak', 'Akyazı', 'Ayvalı', 'Aydınlıkevler',
      'Bahçecik', 'Bengisu', 'Beştaş', 'Boztepe', 'Bulak', 'Çağlayan',
      'Çamoba', 'Çarşı', 'Çilekli', 'Çimenli', 'Çukurçayır', 'Cumhuriyet',
      'Değirmendere', 'Doğançay', 'Dolaylı', 'Düzyurt', 'Esentepe',
      'Esenyurt', 'Fatih', 'Fatih Sultan', 'Gazipaşa', 'Geçit', 'Gölçayır',
      'Gözalan', 'Gülbaharhatun', 'Gündoğdu', 'Gürbulak', 'Hızırbey',
      'İnönü', 'İncesu', 'İskenderpaşa', 'Kalkınma', 'Kamışlı', 'Kanuni',
      'Karakaya', 'Karlık', 'Karşıyaka', 'Kavala', 'Kaymaklı', 'Kemerkaya',
      'Kireçhane', 'Konaklar', 'Kozluca', 'Kurtuluş', 'Kutlugün', 'Okçular',
      'Ortahisar', 'Özbirlik', 'Pazarkapı', 'Pelitli', 'Pınaraltı', 'Sanayi',
      'Sayvan', 'Sevimli', 'Soğuksu', 'Subaşı', 'Toklu', 'Tosköy', 'Uğurlu',
      'Üniversite', 'Yalı', 'Yalıncak', 'Yenicuma', 'Yenimahalle', 'Yeniköy',
      'Yeşilbük', 'Yeşilhisar', 'Yeşilova', 'Yeşiltepe', 'Yeşilvadi',
      'Yeşilyurt', 'Yeşilköy',
    ],
    'Akçaabat': [
      'Acısu', 'Adacık', 'Ağaçlı', 'Akçakale', 'Akçaköy', 'Akdamar',
      'Akören', 'Akpınar', 'Alsancak', 'Ambarcık', 'Arpacılı', 'Aydınköy',
      'Benlitaş Baltacı', 'Bozdoğan', 'Cevizli', 'Cevizlik', 'Çamlıca',
      'Çamlıdere', 'Çınarlık', 'Çiçeklidüz', 'Çilekli', 'Çolaklı', 'Çukurca',
      'Darıca', 'Demirci', 'Demirkapı', 'Demirtaş', 'Derecik', 'Doğanköy',
      'Dörtyol', 'Dürbinar', 'Erikli', 'Esentepe', 'Eskiköy', 'Fındıklı',
      'Fıstıklı', 'Gümüşlü', 'Helvacı', 'Işıklar', 'Kaleönü', 'Karaçayır',
      'Karaman', 'Karpınar', 'Kavaklı', 'Kayalar', 'Kemaliye', 'Kirazlık',
      'Koçlu', 'Kuruçam', 'Maden', 'Mersin', 'Meşeli', 'Meydankaya',
      'Nefsipulathane', 'Oğulkaya Yolbaşı', 'Orta', 'Ortaalan', 'Ortaköy',
      'Osmanbaba', 'Özakdamar', 'Özdemirci', 'Salacık', 'Sarıca', 'Sarıtaş',
      'Sertkaya', 'Söğütlü', 'Şinik', 'Tatlısu', 'Tütüncüler', 'Uçarsu',
      'Uğurlu', 'Yaylacık', 'Yeni', 'Yenimahalle', 'Yeniköy', 'Yeşiltepe',
      'Yeşilyurt', 'Yıldızlı', 'Zaferli',
    ],
    'Araklı': [
      'Aytaş', 'Ayvadere', 'Bahçecik', 'Bereketli', 'Birlik', 'Buzluca',
      'Çamlıca', 'Çamlıktepe', 'Çankaya', 'Çiftepınar', 'Çukurçayır',
      'Değirmencik', 'Dulköy', 'Erenler', 'Erikli', 'Halilli', 'Hasköy',
      'Hürriyet', 'İyisu', 'Kalecik', 'Karatepe', 'Karşıyaka', 'Kayacık',
      'Kayaiçi', 'Kaymaklı', 'Kestanelik', 'Köprüüstü', 'Kükürtlü', 'Merkez',
      'Merkezköy', 'Ortaköy', 'Özgen', 'Pervane', 'Sulakyurt', 'Sularbaşı',
      'Taşgeçit', 'Taşönü', 'Taştepe', 'Türkeli', 'Turnalı', 'Yalıboyu',
      'Yassıkaya', 'Yeniköy', 'Yeşilce', 'Yeşilköy', 'Yeşilyurt', 'Yiğitözü',
      'Yıldızlı', 'Yolgören', 'Yoncalı', 'Yüceyurt',
    ],
    'Arsin': [
      'Atayurt', 'Başdurak', 'Çardaklı', 'Çiçekli', 'Çubuklu', 'Cudibey',
      'Cumhuriyet', 'Dilek', 'Elmaalan', 'Fatih', 'Fındıklı', 'Gölcük',
      'Gölgelik', 'Güneyce', 'Güzelyalı', 'Harmanlı', 'İşhan', 'Işıklı',
      'Karaca', 'Konak', 'Kuzguncuk', 'Nuroğlu', 'Oğuz', 'Örnek', 'Özlü',
      'Şankaya', 'Üçpınar', 'Yalı', 'Yeniköy', 'Yenimahalle', 'Yeşilce',
      'Yeşilköy', 'Yeşiltepe', 'Yeşilyalı', 'Yolaç', 'Yolüstü',
    ],
    'Beşikdüzü': [
      'Beşikdüzü (Merkez)', 'Ağaçlı', 'Akkese', 'Aksaklı', 'Anbarlı',
      'Ardıçatak', 'Bayırköy', 'Bozlu', 'Çakırlı', 'Çıtlaklı', 'Dağlıca',
      'Denizli', 'Dolanlı', 'Duygulu', 'Gürgenli', 'Hünerli', 'Kalegüney',
      'Korkuthan', 'Kutluca', 'Oğuz', 'Resullü', 'Sayvancık', 'Seyitahmet',
      'Şahmelik', 'Takazlı', 'Türkelli', 'Yenicami', 'Yeşilköy', 'Zemberek',
    ],
    'Çarşıbaşı': [
      'Çarşıbaşı (Merkez)', 'Çallı', 'Erenköy', 'Fenerköy', 'Gülbahçe',
      'Kadıköy', 'Kaleköy', 'Kavaklı', 'Kovanlı', 'Küçükköy', 'Pınarlı',
      'Samsun', 'Serpilköy', 'Şahinli', 'Taşlıtepe', 'Veliköy', 'Yavuz',
      'Yeniköy',
    ],
    'Çaykara': [
      'Çaykara (Merkez)', 'Ataköy', 'Akdoğan', 'Arpaözü', 'Aşağıkumlu',
      'Baltacılı', 'Çambaşı', 'Çamlıbel', 'Çayıroba', 'Demirkapı', 'Demirli',
      'Derindere', 'Eğridere', 'Kabataş', 'Karaçam', 'Kayran', 'Koldere',
      'Köknar', 'Köseli', 'Maraşlı', 'Soğanlı', 'Şahinkaya', 'Şekersu',
      'Taşkıran', 'Taşlıgedik', 'Taşören', 'Ulucami', 'Uzungöl', 'Uzuntarla',
      'Yeşilalan', 'Yukarıkumlu', 'Yaylaönü',
    ],
    'Dernekpazarı': [
      'Dernekpazarı (Merkez)', 'Akköse', 'Çalışanlar', 'Çayırbaşı', 'Gülen',
      'Günebakan', 'Ormancık', 'Taşçılar', 'Tüfekçi', 'Yenice', 'Zincirlitaş',
    ],
    'Düzköy': [
      'Düzköy (Merkez)', 'Aykut', 'Çalköy', 'Çayırbağı', 'Alazlı', 'Çiğdemli',
      'Gökçeler', 'Gürgendağ', 'Küçüktepeköy', 'Taşocağı', 'Yerlice',
    ],
    'Hayrat': [
      'Hayrat (Merkez)', 'Balaban', 'Dağönü', 'Dereyurt', 'Fatih', 'Geçitli',
      'Göksel', 'Kılavuz', 'Köyceğiz', 'Onur', 'Pazarönü', 'Pınarca',
      'Sarmaşık', 'Şehitli', 'Şişli', 'Taflancık', 'Yarlı', 'Yeniköy',
      'Yıldırımlar', 'Yırca',
    ],
    'Köprübaşı': [
      'Köprübaşı (Merkez)', 'Beşköy', 'Arpalı', 'Çifteköprü', 'Güneşli',
      'Yağmurlu',
    ],
    'Maçka': [
      'Maçka (Merkez)', 'Akarsu', 'Akmescit', 'Alaçam', 'Alataş', 'Altındere',
      'Anayurt', 'Ardıçlıyayla', 'Armağan', 'Atasu', 'Bağışlı', 'Bakımlı',
      'Bakırcılar', 'Barışlı', 'Başar', 'Coşandere', 'Çamlıdüz', 'Çatak',
      'Çayırlar', 'Çeşmeler', 'Çıralı', 'Dikkaya', 'Erginköy', 'Esiroğlu',
      'Gayretli', 'Günay', 'Gürgenağaç', 'Güzelce', 'Güzelyayla', 'Hamsiköy',
      'Hızarlı', 'Kapuköy', 'Kaynarca', 'Kırantaş', 'Kiremitli', 'Kozağaç',
      'Köprüyanı', 'Kuşçu', 'Mataracı', 'Ocaklı', 'Oğulağaç', 'Ormaniçi',
      'Ormanüstü', 'Ortaköy', 'Örnekalan', 'Sevinç', 'Sındıran', 'Sukenarı',
      'Şimşirli', 'Temelli', 'Üçgedik', 'Yaylabaşı', 'Yazılıtaş', 'Yazlık',
      'Yeniköy', 'Yerlice', 'Yeşilyurt', 'Yukarıköy', 'Yüzüncüyıl', 'Zaferli',
    ],
    'Of': [
      'Of (Merkez)', 'Ağaçbaşı', 'Ağaçseven', 'Aşağıkışlacık', 'Ballıca',
      'Barış', 'Başköy', 'Bayırca', 'Birlik', 'Bölümlü', 'Cumapazarı',
      'Çaltılı', 'Çataldere', 'Çatalsöğüt', 'Çukurova', 'Dağalan', 'Darılı',
      'Dereköy', 'Doğançay', 'Dumlusu', 'Erenköy', 'Esenköy', 'Eskipazar',
      'Fındıkoba', 'Gökçeoba', 'Gümüşören', 'Güresen', 'Gürpınar', 'İkidere',
      'Karabudak', 'Kavakpınar', 'Kazançlı', 'Keler', 'Kıyıboyu', 'Kıyıcık',
      'Kiraz', 'Kireçli', 'Korkut', 'Korucuk', 'Kumludere', 'Ovacık',
      'Örtülü', 'Pınaraltı', 'Saraçlı', 'Sarayköy', 'Sarıbey', 'Sarıkaya',
      'Sefaköy', 'Serince', 'Sıraağaç', 'Sivrice', 'Söğütlü', 'Sugeldi',
      'Tavşanlı', 'Tekoba', 'Uğurlu', 'Uluağaç', 'Yanıktaş', 'Yazlık',
      'Yemişalan',
    ],
    'Sürmene': [
      'Sürmene (Merkez)', 'Çamburnu', 'Ormanseven', 'Oylum', 'Yeniay',
      'Aksu', 'Armutlu', 'Aşağıovalı', 'Birlik', 'Çiftesu', 'Çimenli',
      'Dirlik', 'Fındıcak', 'Gültepe', 'Güneyköy', 'Kahraman', 'Karacakaya',
      'Konak', 'Koyuncular', 'Küçükdere', 'Muratlı', 'Ortaköy', 'Petekli',
      'Üzümlü', 'Yazıoba', 'Yeşilköy', 'Yokuşbaşı', 'Yukarıçavuşlu',
      'Yukarıovalı',
    ],
    'Şalpazarı': [
      'Şalpazarı (Merkez)', 'Ağırtaş', 'Akçiriş', 'Çamlıca', 'Çarlaklı',
      'Çetrik', 'Doğancı', 'Dorukkiriş', 'Düzköy', 'Fidanbaşı', 'Geyikli',
      'Gökçeköy', 'Gölkiriş', 'Güdün', 'Kabasakal', 'Karakaya', 'Kasımağzı',
      'Kuzuluk', 'Pelitçik', 'Sayvançatak', 'Simenli', 'Sinlice', 'Sütpınar',
      'Tepeağzı', 'Üzümözü',
    ],
    'Tonya': [
      'Tonya (Merkez)', 'Biçinlik', 'Büyükmahalle', 'Çamlı', 'Çayıriçi',
      'Hoşarlı', 'İskenderli', 'Kalemli', 'Kaleönü', 'Kalınçam', 'Karaağaçlı',
      'Karasu', 'Karşular', 'Kayacan', 'Kösecik', 'Kozluca', 'Melikşah',
      'Ortamahalle', 'Sağrı', 'Sayraç', 'Turalı', 'Yakçukur', 'Yenimahalle',
    ],
    'Vakfıkebir': [
      'Vakfıkebir (Merkez)', 'Açıkalan', 'Akköy', 'Aydoğdu', 'Bahadırlı',
      'Ballı', 'Bozalan', 'Caferli', 'Çamlık', 'Çavuşlu', 'Deregözü',
      'Düzlük', 'Esentepe', 'Fethiye', 'Fevziye', 'Güneyköy', 'Güneysu',
      'Hamzalı', 'İlyaslı', 'İshaklı', 'Karatepe', 'Kıranköy', 'Kirazlık',
      'Köprücek', 'Mahmutlu', 'Mısırlı', 'Ortaköy', 'Rıdvanlı', 'Sekmenli',
      'Sinanlı', 'Soğuksu', 'Şenocak', 'Tarlacık', 'Yalıköy', 'Yaylacık',
      'Yıldız',
    ],
    'Yomra': [
      'Yomra (Merkez)', 'Çamlıyurt', 'Çınarlı', 'Demirciler', 'Gülyurdu',
      'İkisu', 'Kaşüstü', 'Kayabaşı', 'Kılıçlı', 'Kıratlı', 'Kömürcü',
      'Maden', 'Ocak', 'Oymalıtepe', 'Özdil', 'Pınarlı', 'Şanlı', 'Tandırlı',
      'Taşdelen', 'Yenice', 'Yokuşlu',
    ],
  };

  /// İlçe isimlerini alfabetik sırayla döndürür (dropdown'ın ilk seçim listesi için).
  static List<String> get districtNames =>
      districtsAndNeighborhoods.keys.toList()..sort();

  /// Verilen ilçeye ait mahalle listesini alfabetik sırayla döndürür.
  static List<String> neighborhoodsOf(String district) {
    final list = districtsAndNeighborhoods[district] ?? [];
    final sorted = List<String>.from(list)..sort();
    return sorted;
  }
}
