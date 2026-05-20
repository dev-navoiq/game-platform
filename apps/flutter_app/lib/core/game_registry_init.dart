import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import 'package:game_hearts/game_hearts.dart';
import 'package:game_spades/game_spades.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_rummy/game_rummy.dart';
import 'package:game_chess/game_chess.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:game_sequence/game_sequence.dart';

final gameRegistry = GameRegistry();

void initializeGameRegistry() {
  registerTwentyNine(gameRegistry);
  registerOhHell(gameRegistry);
  registerHearts(gameRegistry);
  registerSpades(gameRegistry);
  registerBridge(gameRegistry);
  registerRummy(gameRegistry);
  registerChess(gameRegistry);
  registerLudo(gameRegistry);
  registerSequence(gameRegistry);
}
