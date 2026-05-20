// Preview entry point — runs without Supabase/Sentry.
// Usage: fvm flutter run -t lib/main_preview.dart -d chrome
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/colors.dart';
import 'shared/animations/cards/card_deal_animation.dart';
import 'shared/animations/cards/card_fan_animation.dart';
import 'shared/animations/cards/card_flip_animation.dart';
import 'shared/animations/cards/card_play_animation.dart';
import 'shared/animations/cards/shuffle_animation.dart';
import 'shared/animations/celebrations/confetti_animation.dart';
import 'shared/animations/celebrations/fireworks_animation.dart';
import 'shared/animations/celebrations/trophy_animation.dart';
import 'shared/animations/gameplay/bid_counter_animation.dart';
import 'shared/animations/gameplay/score_update_animation.dart';
import 'shared/animations/gameplay/timer_ring_animation.dart';
import 'shared/animations/gameplay/trump_reveal_animation.dart';
import 'shared/animations/gameplay/turn_indicator_animation.dart';
import 'shared/animations/social/avatar_reaction_animation.dart';
import 'shared/animations/social/emoji_bubble_animation.dart';
import 'shared/animations/transitions/list_item_animations.dart';
import 'shared/animations/transitions/modal_transitions.dart';

void main() {
  runApp(const AnimationPreviewApp());
}

class AnimationPreviewApp extends StatelessWidget {
  const AnimationPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animation Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.feltDark,
      ),
      home: const AnimationShowcase(),
    );
  }
}

class AnimationShowcase extends StatefulWidget {
  const AnimationShowcase({super.key});

  @override
  State<AnimationShowcase> createState() => _AnimationShowcaseState();
}

class _AnimationShowcaseState extends State<AnimationShowcase> {
  int _currentPage = 0;

  final _pages = const [
    'Cards',
    'Gameplay',
    'Celebrations',
    'Social',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentPage,
        children: [
          _CardAnimationsPage(),
          _GameplayAnimationsPage(),
          _CelebrationsPage(),
          _SocialAnimationsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (i) => setState(() => _currentPage = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.feltMid,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white54,
        items: _pages
            .map((p) => BottomNavigationBarItem(
                  icon: Icon(_iconFor(p)),
                  label: p,
                ))
            .toList(),
      ),
    );
  }

  IconData _iconFor(String page) {
    switch (page) {
      case 'Cards':
        return Icons.style;
      case 'Gameplay':
        return Icons.sports_esports;
      case 'Celebrations':
        return Icons.celebration;
      case 'Social':
        return Icons.chat_bubble;
      default:
        return Icons.circle;
    }
  }
}

// ─── Card Animations ──────────────────────────────────────────

class _CardAnimationsPage extends StatefulWidget {
  @override
  State<_CardAnimationsPage> createState() => _CardAnimationsPageState();
}

class _CardAnimationsPageState extends State<_CardAnimationsPage> {
  Key _dealKey = UniqueKey();
  Key _shuffleKey = UniqueKey();
  int? _selectedCard;
  bool _isFaceUp = false;
  bool _showPlayAnim = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _sectionTitle('Card Animations'),
          const SizedBox(height: 24),

          // Card Fan
          _label('Card Fan (tap to select)'),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: Center(
              child: CardFanAnimation(
                cardCount: 7,
                selectedIndex: _selectedCard,
                cardBuilder: (i) => _buildMiniCard(i),
                onCardTap: (i) {
                  setState(() {
                    _selectedCard = _selectedCard == i ? null : i;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Card Flip
          _label('Card Flip (tap to flip)'),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _isFaceUp = !_isFaceUp),
              child: CardFlipAnimation(
                isFaceUp: _isFaceUp,
                front: _buildCard('A', '♠', AppColors.cardBlack),
                back: _buildCardBack(),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Shuffle
          _label('Shuffle Animation'),
          const SizedBox(height: 8),
          Center(
            child: ShuffleAnimation(
              key: _shuffleKey,
              cardWidth: 56,
              cardHeight: 80,
            ),
          ),
          _replayButton(() {
            setState(() => _shuffleKey = UniqueKey());
          }),
          const SizedBox(height: 32),

          // Deal
          _label('Card Deal Animation'),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: Center(
              child: CardDealAnimation(
                key: _dealKey,
                cardCount: 8,
                playerCount: 4,
                currentPlayerSeat: 0,
                cardWidth: 42,
                cardHeight: 60,
                cardBuilder: (i) => _buildSmallCardBack(),
              ),
            ),
          ),
          _replayButton(() {
            setState(() => _dealKey = UniqueKey());
          }),
          const SizedBox(height: 32),

          // Card Play
          _label('Card Play (tap to play)'),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _showPlayAnim
                ? CardPlayAnimation(
                    card: _buildCard('K', '♥', AppColors.cardRed),
                    startPosition: const Offset(140, 150),
                    endPosition: const Offset(140, 40),
                    onComplete: () {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) setState(() => _showPlayAnim = false);
                      });
                    },
                  )
                : Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      onPressed: () => setState(() => _showPlayAnim = true),
                      child: const Text('Play Card'),
                    ),
                  ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ─── Gameplay Animations ──────────────────────────────────────

class _GameplayAnimationsPage extends StatefulWidget {
  @override
  State<_GameplayAnimationsPage> createState() =>
      _GameplayAnimationsPageState();
}

class _GameplayAnimationsPageState extends State<_GameplayAnimationsPage> {
  bool _turnActive = true;
  int _bidCurrent = 0;
  int _score = 100;
  Key _timerKey = UniqueKey();
  Key _trumpKey = UniqueKey();
  String _trumpSuit = 'hearts';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _sectionTitle('Gameplay Animations'),
          const SizedBox(height: 24),

          // Turn Indicator
          _label('Turn Indicator (tap to toggle)'),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _turnActive = !_turnActive),
              child: TurnIndicatorAnimation(
                isActive: _turnActive,
                child: const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accentSoft,
                  child: Text('😎', style: TextStyle(fontSize: 28)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Timer Ring
          _label('Timer Ring'),
          const SizedBox(height: 8),
          Center(
            child: TimerRingAnimation(
              key: _timerKey,
              seconds: 15,
            ),
          ),
          _replayButton(() {
            setState(() => _timerKey = UniqueKey());
          }),
          const SizedBox(height: 32),

          // Bid Counter
          _label('Bid Counter (tap to increment)'),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _bidCurrent = (_bidCurrent + 1) % 5;
                });
              },
              child: BidCounterAnimation(
                current: _bidCurrent,
                bid: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Score Update
          _label('Score Update (tap to add points)'),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _score += 10 + Random().nextInt(20);
                });
              },
              child: ScoreUpdateAnimation(
                score: _score,
                delta: 15,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Trump Reveal
          _label('Trump Reveal'),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Center(
              child: TrumpRevealAnimation(
                key: _trumpKey,
                suit: _trumpSuit,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final suit in ['hearts', 'diamonds', 'clubs', 'spades'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.feltLight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _trumpSuit = suit;
                        _trumpKey = UniqueKey();
                      });
                    },
                    child: Text(_suitSymbol(suit),
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  String _suitSymbol(String suit) {
    switch (suit) {
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

// ─── Celebrations ─────────────────────────────────────────────

class _CelebrationsPage extends StatefulWidget {
  @override
  State<_CelebrationsPage> createState() => _CelebrationsPageState();
}

class _CelebrationsPageState extends State<_CelebrationsPage> {
  bool _confetti = false;
  bool _fireworks = false;
  bool _trophy = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              _sectionTitle('Celebrations'),
              const SizedBox(height: 24),

              _label('Confetti'),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent),
                  onPressed: () {
                    setState(() => _confetti = true);
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) setState(() => _confetti = false);
                    });
                  },
                  icon: const Icon(Icons.celebration),
                  label: const Text('Launch Confetti'),
                ),
              ),
              const SizedBox(height: 32),

              _label('Fireworks'),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent),
                  onPressed: () {
                    setState(() => _fireworks = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _fireworks = false);
                    });
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Launch Fireworks'),
                ),
              ),
              const SizedBox(height: 32),

              _label('Trophy'),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      width: 200,
                      child: TrophyAnimation(isPlaying: _trophy),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent),
                      onPressed: () {
                        setState(() => _trophy = false);
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (mounted) setState(() => _trophy = true);
                        });
                      },
                      icon: const Icon(Icons.emoji_events),
                      label: const Text('Show Trophy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Modal transition demo
              _label('Modal Entry Transition'),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent),
                  onPressed: () => _showModalDemo(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Show Modal'),
                ),
              ),

              const SizedBox(height: 32),

              // List item animation demo
              _label('List Item Stagger Animation'),
              const SizedBox(height: 8),
              _StaggeredListDemo(),
              const SizedBox(height: 48),
            ],
          ),
        ),

        // Confetti overlay
        if (_confetti)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiAnimation(isPlaying: _confetti),
            ),
          ),

        // Fireworks overlay
        if (_fireworks)
          Positioned.fill(
            child: IgnorePointer(
              child: FireworksAnimation(isPlaying: _fireworks),
            ),
          ),
      ],
    );
  }

  void _showModalDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Center(
        child: ModalEntryTransition(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.feltMid,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Modal Entry',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
                const SizedBox(height: 12),
                Text(
                  'scale(0.88→1) + translateY(16→0)\n350ms overshoot bounce',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredListDemo extends StatefulWidget {
  @override
  State<_StaggeredListDemo> createState() => _StaggeredListDemoState();
}

class _StaggeredListDemoState extends State<_StaggeredListDemo> {
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          key: _key,
          children: List.generate(5, (i) {
            return ListItemAnimation(
              index: i,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.playerColor(i),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Text('List Item ${i + 1}',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        _replayButton(() {
          setState(() => _key = UniqueKey());
        }),
      ],
    );
  }
}

// ─── Social Animations ────────────────────────────────────────

class _SocialAnimationsPage extends StatefulWidget {
  @override
  State<_SocialAnimationsPage> createState() => _SocialAnimationsPageState();
}

class _SocialAnimationsPageState extends State<_SocialAnimationsPage> {
  bool _isReacting = false;
  final List<_EmojiEntry> _emojis = [];
  int _emojiCounter = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              _sectionTitle('Social Animations'),
              const SizedBox(height: 24),

              // Avatar Reaction
              _label('Avatar Reaction (tap avatar)'),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isReacting = false);
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) setState(() => _isReacting = true);
                    });
                  },
                  child: AvatarReactionAnimation(
                    isReacting: _isReacting,
                    reactionColor: AppColors.accent,
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.accentSoft,
                      child: Text('🎮', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Emoji Bubbles
              _label('Emoji Bubbles (tap an emoji)'),
              const SizedBox(height: 8),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['😀', '🎉', '❤️', '👏', '🔥'].map((emoji) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _emojis.add(_EmojiEntry(
                              id: _emojiCounter++,
                              emoji: emoji,
                              x: 120 + Random().nextDouble() * 100,
                            ));
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 200), // space for floating emojis
            ],
          ),
        ),

        // Floating emoji bubbles
        for (final entry in _emojis)
          EmojiBubbleAnimation(
            key: ValueKey(entry.id),
            emoji: entry.emoji,
            startPosition: Offset(entry.x, 400),
            onComplete: () {
              if (mounted) {
                setState(() {
                  _emojis.removeWhere((e) => e.id == entry.id);
                });
              }
            },
          ),
      ],
    );
  }
}

class _EmojiEntry {
  final int id;
  final String emoji;
  final double x;
  _EmojiEntry({required this.id, required this.emoji, required this.x});
}

// ─── Shared helpers ───────────────────────────────────────────

Widget _sectionTitle(String text) {
  return Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  );
}

Widget _label(String text) {
  return Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textFeltMuted,
    ),
  );
}

Widget _replayButton(VoidCallback onPressed) {
  return Center(
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.replay, size: 16, color: AppColors.accentSoft),
      label: Text('Replay',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.accentSoft)),
    ),
  );
}

Widget _buildCard(String rank, String suit, Color color) {
  return Container(
    width: 62,
    height: 90,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(rank,
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        Text(suit, style: TextStyle(fontSize: 16, color: color)),
      ],
    ),
  );
}

Widget _buildCardBack() {
  return Container(
    width: 62,
    height: 90,
    decoration: BoxDecoration(
      color: const Color(0xFF1a1a2a),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: 40,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withOpacity(0.15),
              AppColors.accentSoft.withOpacity(0.08),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildMiniCard(int index) {
  const ranks = ['2', '5', '7', '9', 'J', 'Q', 'A'];
  const suits = ['♠', '♥', '♦', '♣', '♠', '♥', '♦'];
  final isRed = suits[index % suits.length] == '♥' ||
      suits[index % suits.length] == '♦';
  final color = isRed ? AppColors.cardRed : AppColors.cardBlack;

  return Container(
    width: 52,
    height: 76,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(ranks[index % ranks.length],
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        Text(suits[index % suits.length],
            style: TextStyle(fontSize: 12, color: color)),
      ],
    ),
  );
}

Widget _buildSmallCardBack() {
  return Container(
    width: 42,
    height: 60,
    decoration: BoxDecoration(
      color: const Color(0xFF1a1a2a),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white24),
    ),
  );
}
