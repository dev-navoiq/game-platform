import 'package:collection/collection.dart';
import 'package:game_core/game_core.dart';

/// The colour of a player's chips on the board.
enum ChipColor { red, blue, green }

/// A single cell on the Sequence board.
class SequenceCell {
  final PlayingCard? card; // null = corner (wild/free)
  final ChipColor? chip; // null = unoccupied
  final bool isPartOfSequence;

  const SequenceCell({
    this.card,
    this.chip,
    this.isPartOfSequence = false,
  });

  bool get isCorner => card == null;
  bool get isOccupied => isCorner || chip != null;
  bool get isChipLocked => isPartOfSequence; // Cannot remove locked chips

  SequenceCell withChip(ChipColor color) =>
      SequenceCell(card: card, chip: color, isPartOfSequence: isPartOfSequence);

  SequenceCell withoutChip() =>
      SequenceCell(card: card, chip: null, isPartOfSequence: false);

  SequenceCell asPartOfSequence() =>
      SequenceCell(card: card, chip: chip, isPartOfSequence: true);

  @override
  bool operator ==(Object other) =>
      other is SequenceCell &&
      card == other.card &&
      chip == other.chip &&
      isPartOfSequence == other.isPartOfSequence;

  @override
  int get hashCode => Object.hash(card, chip, isPartOfSequence);
}

/// The 10×10 Sequence board.
///
/// Board layout follows the standard Sequence game (Jax Ltd).
/// Each non-jack card from a standard 52-card deck appears exactly twice
/// (from two decks) on the 96 non-corner squares.
class SequenceBoard {
  static const int size = 10;

  /// Corners are free/wild spaces — any colour can use them.
  static final Set<(int, int)> corners = {
    (0, 0), (0, 9), (9, 0), (9, 9),
  };

  /// Standard Sequence board card layout.
  /// null = corner (free space). Jacks do not appear on the board.
  static final List<List<PlayingCard?>> cardLayout = _buildLayout();

  static List<List<PlayingCard?>> _buildLayout() {
    // Standard Sequence board card placement.
    // Each non-jack card appears exactly twice across the 96 non-corner cells.
    const W = null; // Wild corner
    PlayingCard c(Suit s, Rank r) => PlayingCard(s, r);
    final S = Suit.spades;
    final H = Suit.hearts;
    final D = Suit.diamonds;
    final C = Suit.clubs;
    final n2 = Rank.two, n3 = Rank.three, n4 = Rank.four;
    final n5 = Rank.five, n6 = Rank.six, n7 = Rank.seven;
    final n8 = Rank.eight, n9 = Rank.nine, n10 = Rank.ten;
    final nQ = Rank.queen, nK = Rank.king, nA = Rank.ace;

    // Row-by-row layout matching the standard Sequence game board.
    return [
      // Row 0
      [W, c(S,n2), c(S,n3), c(S,n4), c(S,n5), c(S,n6), c(S,n7), c(S,n8), c(S,n9), W],
      // Row 1
      [c(C,n6), c(C,n5), c(C,n4), c(C,n3), c(C,n2), c(H,nA), c(H,nK), c(H,nQ), c(H,n10), c(S,n10)],
      // Row 2
      [c(C,n7), c(D,nA), c(D,nK), c(D,nQ), c(D,n10), c(D,n9), c(D,n8), c(D,n7), c(H,n9), c(S,nQ)],
      // Row 3
      [c(C,n8), c(C,n10), c(C,nQ), c(C,nK), c(C,nA), c(S,nA), c(S,nK), c(S,nQ), c(H,n8), c(S,nK)],
      // Row 4
      [c(C,n9), c(C,n9), c(C,n8), c(C,n7), c(C,n6), c(C,n5), c(C,n4), c(C,n3), c(H,n7), c(S,nA)],
      // Row 5
      [c(C,n10), c(H,n2), c(H,n3), c(H,n4), c(H,n5), c(H,n6), c(H,n7), c(H,n8), c(H,n6), c(C,nA)],
      // Row 6
      [c(C,nQ), c(H,n5), c(D,n4), c(D,n3), c(D,n2), c(D,nA), c(D,nK), c(D,nQ), c(H,n5), c(C,nK)],
      // Row 7
      [c(C,nK), c(H,n6), c(D,n5), c(D,n6), c(D,n7), c(D,n8), c(D,n9), c(D,n10), c(H,n4), c(C,nQ)],
      // Row 8
      [c(C,nA), c(H,n7), c(H,n8), c(H,n9), c(H,n10), c(H,nQ), c(H,nK), c(H,nA), c(H,n3), c(C,n10)],
      // Row 9
      [W, c(S,nA), c(S,nK), c(S,nQ), c(S,n10), c(S,n9), c(S,n8), c(S,n7), c(S,n6), W],
    ];
  }

  final List<List<SequenceCell>> _cells;

  SequenceBoard._(this._cells);

  factory SequenceBoard.empty() {
    final cells = List.generate(
      size,
      (row) => List.generate(
        size,
        (col) => SequenceCell(
          card: cardLayout[row][col],
          chip: null,
          isPartOfSequence:
              corners.contains((row, col)), // corners are always "occupied"
        ),
      ),
    );
    return SequenceBoard._(cells);
  }

  SequenceCell cellAt(int row, int col) => _cells[row][col];

  bool isCorner(int row, int col) => corners.contains((row, col));

  bool isOccupied(int row, int col) {
    final cell = _cells[row][col];
    return cell.isCorner || cell.chip != null;
  }

  bool isChipLocked(int row, int col) => _cells[row][col].isChipLocked;

  SequenceBoard withChip(int row, int col, ChipColor color) {
    final newCells = _copyGrid();
    newCells[row][col] = newCells[row][col].withChip(color);
    return SequenceBoard._(newCells);
  }

  SequenceBoard withoutChip(int row, int col) {
    final newCells = _copyGrid();
    newCells[row][col] = newCells[row][col].withoutChip();
    return SequenceBoard._(newCells);
  }

  SequenceBoard markSequence(Set<(int, int)> positions) {
    final newCells = _copyGrid();
    for (final (r, c) in positions) {
      newCells[r][c] = newCells[r][c].asPartOfSequence();
    }
    return SequenceBoard._(newCells);
  }

  /// Find all positions on the board where [card] is placed.
  List<(int, int)> positionsForCard(PlayingCard card) {
    final positions = <(int, int)>[];
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (_cells[row][col].card == card) {
          positions.add((row, col));
        }
      }
    }
    return positions;
  }

  List<List<SequenceCell>> _copyGrid() => List.generate(
        size,
        (r) => List<SequenceCell>.from(_cells[r]),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SequenceBoard) return false;
    return const DeepCollectionEquality().equals(_cells, other._cells);
  }

  @override
  int get hashCode => const DeepCollectionEquality().hash(_cells);
}
