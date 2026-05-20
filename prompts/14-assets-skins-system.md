# 13 - Assets & Skins System

> Create a flexible asset management system supporting card skins, room themes, and brand customization.

## Task

Build an asset system that supports:
- Multiple card skin packs (Classic, Modern, Neon, Gold, Brand)
- Room/table themes (Classic, Casino, Nature, Space, Brand)
- Board game visual themes
- Dynamic asset loading from CDN
- Offline caching
- Brand skin creation for advertisers

---

## Asset Directory Structure

```
apps/flutter_app/assets/
├── cards/
│   ├── classic/                 # Default card skin
│   │   ├── hearts/
│   │   │   ├── A.png
│   │   │   ├── K.png
│   │   │   └── ...
│   │   ├── diamonds/
│   │   ├── clubs/
│   │   ├── spades/
│   │   └── back.png
│   ├── modern/
│   │   └── ... (same structure)
│   ├── minimal/
│   ├── neon/
│   └── shared/
│       ├── suits/               # Suit icons for UI
│       │   ├── heart.svg
│       │   ├── diamond.svg
│       │   ├── club.svg
│       │   └── spade.svg
│       └── placeholder.png
├── boards/
│   ├── chess/
│   │   ├── classic/
│   │   │   ├── board.png
│   │   │   ├── pieces/
│   │   │   │   ├── white_king.png
│   │   │   │   └── ...
│   │   └── wood/
│   ├── ludo/
│   │   ├── classic/
│   │   │   ├── board.png
│   │   │   └── tokens/
│   │   └── neon/
│   └── sequence/
│       └── classic/
├── rooms/
│   ├── classic/
│   │   ├── background.png
│   │   ├── table.png
│   │   └── felt.png
│   ├── casino/
│   ├── nature/
│   ├── space/
│   └── brand_template/
│       ├── background_template.psd
│       └── guidelines.pdf
├── audio/
│   ├── common/
│   │   ├── card_deal.mp3
│   │   ├── card_play.mp3
│   │   ├── card_flip.mp3
│   │   ├── shuffle.mp3
│   │   ├── win.mp3
│   │   ├── lose.mp3
│   │   ├── turn_start.mp3
│   │   ├── timer_warning.mp3
│   │   ├── button_tap.mp3
│   │   └── notification.mp3
│   ├── twenty_nine/
│   │   ├── trump_reveal.mp3
│   │   └── bid_place.mp3
│   └── chess/
│       ├── piece_move.mp3
│       ├── capture.mp3
│       └── check.mp3
├── animations/
│   ├── confetti.riv
│   ├── fireworks.riv
│   ├── trophy.riv
│   └── loading.riv
├── emotes/
│   ├── thumbs_up.png
│   ├── laugh.png
│   ├── surprised.png
│   └── ...
├── avatars/
│   ├── frames/
│   │   ├── default.png
│   │   ├── silver.png
│   │   └── gold.png
│   └── defaults/
│       ├── avatar_1.png
│       └── ...
└── ui/
    ├── icons/
    └── backgrounds/
```

---

## Asset Manager

```dart
// lib/core/assets/asset_manager.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AssetManager {
  static final AssetManager instance = AssetManager._();
  AssetManager._();

  static const String _cdnBaseUrl = 'https://cdn.gameplatform.com/assets';
  static const String _manifestFile = 'asset_manifest.json';

  late Directory _cacheDir;
  late Map<String, AssetManifest> _manifests;
  final Map<String, ImageProvider> _imageCache = {};

  Future<void> initialize() async {
    _cacheDir = await getApplicationCacheDirectory();
    _manifests = {};

    // Load local manifest
    await _loadLocalManifest();

    // Check for updates in background
    _checkForUpdates();
  }

  Future<void> _loadLocalManifest() async {
    try {
      final manifestString = await rootBundle.loadString('assets/$_manifestFile');
      final manifestJson = json.decode(manifestString) as Map<String, dynamic>;

      for (final entry in manifestJson.entries) {
        _manifests[entry.key] = AssetManifest.fromJson(entry.value);
      }
    } catch (e) {
      // Use default manifest
      _manifests = _getDefaultManifest();
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse('$_cdnBaseUrl/$_manifestFile'));
      if (response.statusCode == 200) {
        final remoteManifest = json.decode(response.body) as Map<String, dynamic>;
        // Compare versions and download updates if needed
        await _processManifestUpdates(remoteManifest);
      }
    } catch (e) {
      // Offline, use cached assets
    }
  }

  Future<void> _processManifestUpdates(Map<String, dynamic> remote) async {
    for (final entry in remote.entries) {
      final skinId = entry.key;
      final remoteVersion = entry.value['version'] as int;
      final localVersion = _manifests[skinId]?.version ?? 0;

      if (remoteVersion > localVersion) {
        await _downloadSkin(skinId, entry.value);
      }
    }
  }

  Future<void> _downloadSkin(String skinId, Map<String, dynamic> data) async {
    final assets = data['assets'] as List;
    final skinDir = Directory('${_cacheDir.path}/skins/$skinId');
    await skinDir.create(recursive: true);

    for (final asset in assets) {
      final url = asset['url'] as String;
      final localPath = asset['path'] as String;

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final file = File('${skinDir.path}/$localPath');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(response.bodyBytes);
        }
      } catch (e) {
        // Skip failed downloads
      }
    }

    // Update local manifest
    _manifests[skinId] = AssetManifest.fromJson(data);
  }

  Map<String, AssetManifest> _getDefaultManifest() {
    return {
      'cards_classic': AssetManifest(
        id: 'cards_classic',
        type: AssetType.cardSkin,
        version: 1,
        isLocal: true,
        basePath: 'assets/cards/classic',
      ),
      'rooms_classic': AssetManifest(
        id: 'rooms_classic',
        type: AssetType.roomTheme,
        version: 1,
        isLocal: true,
        basePath: 'assets/rooms/classic',
      ),
    };
  }

  /// Get card image for a specific skin
  ImageProvider getCardImage({
    required String skinId,
    required String suit,
    required String rank,
  }) {
    final cacheKey = '$skinId/$suit/$rank';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    final manifest = _manifests[skinId];
    ImageProvider provider;

    if (manifest == null || manifest.isLocal) {
      // Load from bundled assets
      provider = AssetImage('assets/cards/$skinId/$suit/$rank.png');
    } else {
      // Load from cache
      final file = File('${_cacheDir.path}/skins/$skinId/$suit/$rank.png');
      if (file.existsSync()) {
        provider = FileImage(file);
      } else {
        // Fallback to classic
        provider = AssetImage('assets/cards/classic/$suit/$rank.png');
      }
    }

    _imageCache[cacheKey] = provider;
    return provider;
  }

  /// Get card back image
  ImageProvider getCardBack(String skinId) {
    return getCardImage(skinId: skinId, suit: '', rank: 'back');
  }

  /// Get room background
  ImageProvider getRoomBackground(String themeId) {
    final manifest = _manifests['rooms_$themeId'];

    if (manifest == null || manifest.isLocal) {
      return AssetImage('assets/rooms/$themeId/background.png');
    } else {
      final file = File('${_cacheDir.path}/skins/rooms_$themeId/background.png');
      if (file.existsSync()) {
        return FileImage(file);
      }
      return const AssetImage('assets/rooms/classic/background.png');
    }
  }

  /// Get table felt texture
  ImageProvider getTableFelt(String themeId) {
    return AssetImage('assets/rooms/$themeId/felt.png');
  }

  /// Get chess piece image
  ImageProvider getChessPiece({
    required String themeId,
    required String color,
    required String piece,
  }) {
    return AssetImage('assets/boards/chess/$themeId/pieces/${color}_$piece.png');
  }

  /// Get ludo token image
  ImageProvider getLudoToken({
    required String themeId,
    required String color,
  }) {
    return AssetImage('assets/boards/ludo/$themeId/tokens/$color.png');
  }

  /// Get audio path
  String getAudioPath(String category, String name) {
    return 'assets/audio/$category/$name.mp3';
  }

  /// Get animation path
  String getAnimationPath(String name) {
    return 'assets/animations/$name.riv';
  }

  /// Get available skins of a type
  List<SkinInfo> getAvailableSkins(AssetType type) {
    return _manifests.values
        .where((m) => m.type == type)
        .map((m) => SkinInfo(
              id: m.id,
              displayName: m.displayName ?? m.id,
              previewUrl: m.previewUrl,
              isPremium: m.isPremium,
              isBrand: m.brandName != null,
              brandName: m.brandName,
            ))
        .toList();
  }

  /// Preload assets for a game
  Future<void> preloadGameAssets({
    required String gameType,
    required String cardSkin,
    required String roomTheme,
  }) async {
    // Preload card images
    final suits = ['hearts', 'diamonds', 'clubs', 'spades'];
    final ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];

    for (final suit in suits) {
      for (final rank in ranks) {
        precacheImage(
          getCardImage(skinId: cardSkin, suit: suit, rank: rank),
          navigatorKey.currentContext!,
        );
      }
    }

    // Preload room assets
    precacheImage(getRoomBackground(roomTheme), navigatorKey.currentContext!);
    precacheImage(getTableFelt(roomTheme), navigatorKey.currentContext!);
  }

  void clearCache() {
    _imageCache.clear();
    // Optionally delete cached files
  }
}

enum AssetType {
  cardSkin,
  roomTheme,
  boardTheme,
  avatarFrame,
  emotePack,
}

class AssetManifest {
  final String id;
  final AssetType type;
  final int version;
  final bool isLocal;
  final String basePath;
  final String? displayName;
  final String? previewUrl;
  final bool isPremium;
  final String? brandName;
  final List<String>? assets;

  AssetManifest({
    required this.id,
    required this.type,
    required this.version,
    required this.isLocal,
    required this.basePath,
    this.displayName,
    this.previewUrl,
    this.isPremium = false,
    this.brandName,
    this.assets,
  });

  factory AssetManifest.fromJson(Map<String, dynamic> json) {
    return AssetManifest(
      id: json['id'] as String,
      type: AssetType.values.byName(json['type'] as String),
      version: json['version'] as int,
      isLocal: json['isLocal'] as bool? ?? false,
      basePath: json['basePath'] as String? ?? '',
      displayName: json['displayName'] as String?,
      previewUrl: json['previewUrl'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      brandName: json['brandName'] as String?,
      assets: (json['assets'] as List?)?.cast<String>(),
    );
  }
}

class SkinInfo {
  final String id;
  final String displayName;
  final String? previewUrl;
  final bool isPremium;
  final bool isBrand;
  final String? brandName;

  SkinInfo({
    required this.id,
    required this.displayName,
    this.previewUrl,
    this.isPremium = false,
    this.isBrand = false,
    this.brandName,
  });
}
```

---

## Skin Selector Widget

```dart
// lib/shared/widgets/skins/skin_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SkinSelector extends ConsumerWidget {
  final AssetType skinType;
  final String currentSkinId;
  final ValueChanged<String> onSkinSelected;
  final bool showLockedSkins;

  const SkinSelector({
    super.key,
    required this.skinType,
    required this.currentSkinId,
    required this.onSkinSelected,
    this.showLockedSkins = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skins = AssetManager.instance.getAvailableSkins(skinType);
    final ownedSkins = ref.watch(ownedSkinsProvider);
    final tier = ref.watch(subscriptionTierProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: skins.length,
      itemBuilder: (context, index) {
        final skin = skins[index];
        final isOwned = _isSkinOwned(skin, ownedSkins, tier);
        final isSelected = skin.id == currentSkinId;

        if (!showLockedSkins && !isOwned) {
          return const SizedBox.shrink();
        }

        return _SkinCard(
          skin: skin,
          isOwned: isOwned,
          isSelected: isSelected,
          onTap: () {
            if (isOwned) {
              onSkinSelected(skin.id);
            } else {
              _showPurchaseDialog(context, skin);
            }
          },
        );
      },
    );
  }

  bool _isSkinOwned(SkinInfo skin, List<String> owned, SubscriptionTier tier) {
    // Free skins
    if (!skin.isPremium) return true;

    // Max tier owns everything
    if (tier == SubscriptionTier.max) return true;

    // Check if specifically owned
    return owned.contains(skin.id);
  }

  void _showPurchaseDialog(BuildContext context, SkinInfo skin) {
    showDialog(
      context: context,
      builder: (context) => _SkinPurchaseDialog(skin: skin),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final SkinInfo skin;
  final bool isOwned;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkinCard({
    required this.skin,
    required this.isOwned,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Preview image
              if (skin.previewUrl != null)
                Image.network(
                  skin.previewUrl!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.image, size: 40),
                ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // Locked overlay
              if (!isOwned)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      color: Colors.white54,
                      size: 32,
                    ),
                  ),
                ),

              // Brand badge
              if (skin.isBrand)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      skin.brandName ?? 'Brand',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Premium badge
              if (skin.isPremium && !skin.isBrand)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Name
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  skin.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Playing Card Widget with Skin Support

```dart
// lib/shared/widgets/playing_card.dart

import 'package:flutter/material.dart';
import '../core/assets/asset_manager.dart';

class PlayingCardWidget extends StatefulWidget {
  final String suit;
  final String rank;
  final String skinId;
  final bool isFaceDown;
  final bool isSelected;
  final bool isPlayable;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool enableFlipAnimation;

  const PlayingCardWidget({
    super.key,
    required this.suit,
    required this.rank,
    this.skinId = 'classic',
    this.isFaceDown = false,
    this.isSelected = false,
    this.isPlayable = true,
    this.width = 60,
    this.height = 90,
    this.onTap,
    this.enableFlipAnimation = true,
  });

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _showFront = !widget.isFaceDown;
    if (widget.isFaceDown) {
      _flipController.value = 1;
    }
  }

  @override
  void didUpdateWidget(PlayingCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFaceDown != oldWidget.isFaceDown && widget.enableFlipAnimation) {
      _animateFlip();
    }
  }

  void _animateFlip() {
    if (widget.isFaceDown) {
      _flipController.forward().then((_) {
        setState(() => _showFront = false);
      });
    } else {
      _flipController.reverse().then((_) {
        setState(() => _showFront = true);
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: _flipAnimation.value < 0.5 ? _buildFront() : _buildBack(),
        );
      },
    );

    // Selection state
    if (widget.isSelected) {
      card = Transform.translate(
        offset: const Offset(0, -15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: card,
        ),
      );
    }

    // Playable state
    if (!widget.isPlayable) {
      card = Opacity(opacity: 0.5, child: card);
    }

    if (widget.onTap != null && widget.isPlayable) {
      card = GestureDetector(onTap: widget.onTap, child: card);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: card,
    );
  }

  Widget _buildFront() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(
          image: AssetManager.instance.getCardImage(
            skinId: widget.skinId,
            suit: widget.suit.toLowerCase(),
            rank: widget.rank,
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackFront(),
        ),
      ),
    );
  }

  Widget _buildBack() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.14159),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: AssetManager.instance.getCardBack(widget.skinId),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackBack(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackFront() {
    final isRed = widget.suit == 'hearts' || widget.suit == 'diamonds';
    final suitSymbol = _getSuitSymbol();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // Top left
          Positioned(
            top: 4,
            left: 4,
            child: Column(
              children: [
                Text(
                  widget.rank,
                  style: TextStyle(
                    fontSize: widget.width * 0.25,
                    fontWeight: FontWeight.bold,
                    color: isRed ? Colors.red : Colors.black,
                  ),
                ),
                Text(
                  suitSymbol,
                  style: TextStyle(
                    fontSize: widget.width * 0.2,
                    color: isRed ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          // Center
          Center(
            child: Text(
              suitSymbol,
              style: TextStyle(
                fontSize: widget.width * 0.5,
                color: isRed ? Colors.red : Colors.black,
              ),
            ),
          ),
          // Bottom right (rotated)
          Positioned(
            bottom: 4,
            right: 4,
            child: Transform.rotate(
              angle: 3.14159,
              child: Column(
                children: [
                  Text(
                    widget.rank,
                    style: TextStyle(
                      fontSize: widget.width * 0.25,
                      fontWeight: FontWeight.bold,
                      color: isRed ? Colors.red : Colors.black,
                    ),
                  ),
                  Text(
                    suitSymbol,
                    style: TextStyle(
                      fontSize: widget.width * 0.2,
                      color: isRed ? Colors.red : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: CustomPaint(
        painter: _CardBackPatternPainter(),
      ),
    );
  }

  String _getSuitSymbol() {
    switch (widget.suit.toLowerCase()) {
      case 'hearts':
        return '♥';
      case 'diamonds':
        return '♦';
      case 'clubs':
        return '♣';
      case 'spades':
        return '♠';
      default:
        return '?';
    }
  }
}

class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines
    const spacing = 10.0;
    for (var i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

---

## Brand Skin Guidelines

For brands wanting to create custom skins:

### Card Skin Requirements
- 52 card face images (4 suits × 13 ranks)
- 1 card back image
- Resolution: 200×280 pixels minimum
- Format: PNG with transparency
- File naming: `{suit}/{rank}.png` (e.g., `hearts/A.png`)

### Room Theme Requirements
- 1 background image (1920×1080 minimum)
- 1 table texture (512×512, tileable)
- 1 felt texture (512×512, tileable)
- Brand logo (transparent PNG, max 200×100)
- Color scheme specification

### Submission Process
1. Contact partnerships@gameplatform.com
2. Provide brand guidelines and assets
3. Review and approval (3-5 business days)
4. Integration and testing
5. Campaign activation

---

## Expected Output

- Complete asset management system
- Card skin support with multiple themes
- Room theme support with brand customization
- Dynamic asset loading from CDN
- Offline caching strategy
- Skin selector UI component
- Playing card widget with skin support
- Brand skin creation guidelines
- Asset manifest for version control
