/// Chess game configuration.
class ChessConfig {
  final bool showLegalMoves;
  final bool allowTakeback;
  final bool autoQueen; // Auto-promote pawns to queen

  const ChessConfig({
    this.showLegalMoves = true,
    this.allowTakeback = false,
    this.autoQueen = false,
  });

  Map<String, dynamic> toJson() => {
        'showLegalMoves': showLegalMoves,
        'allowTakeback': allowTakeback,
        'autoQueen': autoQueen,
      };

  factory ChessConfig.fromJson(Map<String, dynamic> json) => ChessConfig(
        showLegalMoves: json['showLegalMoves'] ?? true,
        allowTakeback: json['allowTakeback'] ?? false,
        autoQueen: json['autoQueen'] ?? false,
      );
}
