/// The 6-theme classification taxonomy from the CSC575 Business Case (section 3.1, "Smart Post
/// Creator") and the "Klasifikasi Pantun 6 Tema Baharu" research dataset (5,644 hand-classified
/// pantun). Mirrors domain/model/PantunTheme.kt exactly so both apps classify posts the same way.
class PantunTheme {
  static const nasihatMoral = 'Nasihat & Moral';
  static const cintaKasihSayang = 'Cinta & Kasih Sayang';
  static const budiAdab = 'Budi & Adab';
  static const agamaSpiritual = 'Agama & Spiritual';
  static const peribahasaKiasan = 'Peribahasa & Kiasan';
  static const jenaka = 'Jenaka';

  static const List<String> all = [
    nasihatMoral,
    cintaKasihSayang,
    budiAdab,
    agamaSpiritual,
    peribahasaKiasan,
    jenaka,
  ];
}
