/// Philippine banks and e-wallets that get their own icon and color.
///
/// When an account's name matches one (e.g. "GoTyme", "gotyme savings"),
/// the app shows that bank's icon (`assets/banks/<id>.png`) and color.
class PhBank {
  const PhBank({
    required this.id,
    required this.name,
    required this.aliases,
    required this.color,
    this.isWallet = false,
  });

  /// Also the icon's file name: `assets/banks/<id>.png`
  final String id;

  /// How the bank writes its own name, e.g. "GoTyme Bank".
  final String name;

  /// Ways people type it. Capitals, spaces and punctuation don't matter,
  /// so 'go tyme' also covers "GoTyme", "Go-Tyme" and "GOTYME".
  final List<String> aliases;

  /// The brand color as 0xAARRGGBB, used for the account page's banner.
  final int color;

  /// True for e-wallets (GCash, Maya), so new accounts default to E-wallet.
  final bool isWallet;

  String get iconAsset => 'assets/banks/$id.png';
}

const phBanks = <PhBank>[
  // E-wallets and digital banks
  PhBank(
    id: 'gcash',
    name: 'GCash',
    aliases: ['gcash'],
    color: 0xFF1C72FB,
    isWallet: true,
  ),
  PhBank(
    id: 'maya',
    name: 'Maya',
    aliases: ['maya', 'paymaya', 'maya bank'],
    color: 0xFF0B0B0B,
    isWallet: true,
  ),
  PhBank(
    id: 'gotyme',
    name: 'GoTyme Bank',
    aliases: ['gotyme', 'gotyme bank'],
    color: 0xFF05E6FA,
  ),
  PhBank(
    id: 'maribank',
    name: 'MariBank',
    aliases: ['maribank', 'mari bank', 'seabank', 'sea bank'],
    color: 0xFFEE6A1F,
  ),
  // Traditional banks
  PhBank(
    id: 'bdo',
    name: 'BDO',
    aliases: ['bdo', 'banco de oro', 'bdo unibank'],
    color: 0xFF014EA8,
  ),
  PhBank(
    id: 'bpi',
    name: 'BPI',
    aliases: ['bpi', 'bank of the philippine islands'],
    color: 0xFFC8343A,
  ),
  PhBank(
    id: 'metrobank',
    name: 'Metrobank',
    aliases: ['metrobank', 'metropolitan bank'],
    color: 0xFF4F5FB8,
  ),
  PhBank(
    id: 'landbank',
    name: 'LANDBANK',
    aliases: ['landbank', 'lbp', 'land bank of the philippines'],
    color: 0xFF3FA535,
  ),
  PhBank(
    id: 'pnb',
    name: 'PNB',
    aliases: ['pnb', 'philippine national bank'],
    color: 0xFF1B2A6B,
  ),
  PhBank(
    id: 'securitybank',
    name: 'Security Bank',
    aliases: ['security bank', 'secbank'],
    color: 0xFF314057,
  ),
  PhBank(
    id: 'unionbank',
    name: 'UnionBank',
    aliases: ['unionbank', 'ubp', 'union bank of the philippines'],
    color: 0xFFE8590C,
  ),
  PhBank(id: 'rcbc', name: 'RCBC', aliases: ['rcbc'], color: 0xFF1281D2),
  PhBank(
    id: 'chinabank',
    name: 'China Bank',
    aliases: ['chinabank', 'china banking corporation', 'my cbc'],
    color: 0xFFE3171A,
  ),
  PhBank(
    id: 'eastwest',
    name: 'EastWest',
    aliases: ['eastwest', 'eastwest bank', 'ewb'],
    color: 0xFF5A1C89,
  ),
  PhBank(
    id: 'psbank',
    name: 'PSBank',
    aliases: ['psbank', 'philippine savings bank'],
    color: 0xFFC8301F,
  ),
  PhBank(
    id: 'aub',
    name: 'AUB',
    aliases: ['aub', 'asia united bank'],
    color: 0xFFC1161E,
  ),
  PhBank(
    id: 'pbcom',
    name: 'PBCom',
    aliases: ['pbcom', 'philippine bank of communications'],
    color: 0xFFD7262E,
  ),
];

/// Splits a name into lowercase words of letters and digits:
/// "Go-Tyme Savings!" -> ['go', 'tyme', 'savings'].
List<String> _words(String text) =>
    RegExp(r'[a-z0-9]+')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

/// The bank an account name refers to, or null.
///
/// A match must line up with whole words, so "BDO Savings" and "Go Tyme"
/// match but "Mayaman Fund" doesn't count as Maya. When two banks match,
/// the longer match wins.
PhBank? bankForName(String accountName) {
  final words = _words(accountName);
  PhBank? best;
  var bestLength = 0;
  for (final bank in phBanks) {
    for (final alias in bank.aliases) {
      final target = _words(alias).join();
      if (target.length <= bestLength) continue;
      if (_hasWordRun(words, target)) {
        best = bank;
        bestLength = target.length;
      }
    }
  }
  return best;
}

/// True if some run of neighbouring [words], squashed together, spells
/// [target]. "metro bank" -> 'metro' + 'bank' = 'metrobank'.
bool _hasWordRun(List<String> words, String target) {
  for (var start = 0; start < words.length; start++) {
    var joined = '';
    for (var end = start; end < words.length; end++) {
      joined += words[end];
      if (joined == target) return true;
      if (joined.length >= target.length) break;
    }
  }
  return false;
}
