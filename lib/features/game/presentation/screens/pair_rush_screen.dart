import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_exam_database.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_card.dart';

class GameCard {
  final String id;
  final String pairId;
  final String text;
  final bool isTerm; // true = term, false = definition
  bool isFlipped;
  bool isMatched;

  GameCard({
    required this.id,
    required this.pairId,
    required this.text,
    required this.isTerm,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class PairRushScreen extends StatefulWidget {
  const PairRushScreen({super.key});

  @override
  State<PairRushScreen> createState() => _PairRushScreenState();
}

class _PairRushScreenState extends State<PairRushScreen> {
  final LocalExamDatabase _localDb = LocalExamDatabase();
  bool _isLoading = true;
  bool _isPlaying = false;

  List<GameCard> _cards = [];
  GameCard? _firstSelected;
  GameCard? _secondSelected;
  bool _isChecking = false;

  int _score = 0;
  int _combo = 0;
  int _matchedPairs = 0;
  int _elapsedMs = 0;
  Timer? _gameTimer;

  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadPairsAndStart();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final dio = DioClient.create();
      final res = await dio.get('/game/scores');
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _leaderboard = (data['leaderboard'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPairsAndStart() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> rawPairs = [];

    try {
      final dio = DioClient.create();
      final res = await dio.get('/pairs');
      final data = res.data as Map<String, dynamic>;
      rawPairs = (data['pairs'] as List).cast<Map<String, dynamic>>();
      await _localDb.saveStudyPairs(rawPairs);
    } catch (_) {
      rawPairs = await _localDb.getCachedStudyPairs();
    }

    if (rawPairs.isEmpty) {
      // Fallback static study pairs
      rawPairs = [
        {'id': '1', 'course_id': 'c1', 'term': 'Widget', 'definition': 'Komponen antarmuka dasar Flutter'},
        {'id': '2', 'course_id': 'c1', 'term': 'Provider', 'definition': 'Manajemen state reaktif di Flutter'},
        {'id': '3', 'course_id': 'c1', 'term': 'AES-GCM', 'definition': 'Enkripsi data lokal terotentikasi'},
        {'id': '4', 'course_id': 'c1', 'term': 'Geofence', 'definition': 'Radius batas lokasi virtual GPS'},
        {'id': '5', 'course_id': 'c1', 'term': 'JWT', 'definition': 'Token autentikasi digital client-server'},
        {'id': '6', 'course_id': 'c1', 'term': 'Hash-Chain', 'definition': 'Rantai blok anti-manipulasi audit trail'},
      ];
    }

    _startNewGame(rawPairs);
  }

  void _startNewGame(List<Map<String, dynamic>> rawPairs) {
    _gameTimer?.cancel();

    // Pick 6 random pairs
    final shuffledPairs = List<Map<String, dynamic>>.from(rawPairs)..shuffle(Random());
    final selectedPairs = shuffledPairs.take(6).toList();

    final List<GameCard> cards = [];
    for (int i = 0; i < selectedPairs.length; i++) {
      final p = selectedPairs[i];
      final pairId = 'pair_$i';
      cards.add(GameCard(
        id: '${pairId}_term',
        pairId: pairId,
        text: p['term'] as String,
        isTerm: true,
      ));
      cards.add(GameCard(
        id: '${pairId}_def',
        pairId: pairId,
        text: p['definition'] as String,
        isTerm: false,
      ));
    }

    // Shuffle all 12 cards
    cards.shuffle(Random());

    setState(() {
      _cards = cards;
      _score = 0;
      _combo = 0;
      _matchedPairs = 0;
      _elapsedMs = 0;
      _isPlaying = true;
      _firstSelected = null;
      _secondSelected = null;
      _isChecking = false;
      _isLoading = false;
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _elapsedMs += 100;
        });
      }
    });
  }

  void _onCardTap(GameCard card) {
    if (!_isPlaying || _isChecking || card.isMatched || card.isFlipped) return;

    setState(() {
      card.isFlipped = true;
    });

    if (_firstSelected == null) {
      _firstSelected = card;
    } else {
      _secondSelected = card;
      _checkMatch();
    }
  }

  void _checkMatch() async {
    _isChecking = true;
    final first = _firstSelected!;
    final second = _secondSelected!;

    if (first.pairId == second.pairId && first.isTerm != second.isTerm) {
      // MATCH!
      _combo++;
      final comboBonus = _combo * 20;
      _score += (100 + comboBonus);
      _matchedPairs++;

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          first.isMatched = true;
          second.isMatched = true;
          _firstSelected = null;
          _secondSelected = null;
          _isChecking = false;
        });
      }

      if (_matchedPairs >= 6) {
        _endGame();
      }
    } else {
      // MISMATCH!
      _combo = 0;
      _score = max(0, _score - 20);

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          first.isFlipped = false;
          second.isFlipped = false;
          _firstSelected = null;
          _secondSelected = null;
          _isChecking = false;
        });
      }
    }
  }

  void _endGame() async {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    // Submit score to server
    try {
      final dio = DioClient.create();
      await dio.post('/game/scores', data: {
        'score': _score,
        'duration_ms': _elapsedMs,
      });
      _loadLeaderboard();
    } catch (_) {}

    if (mounted) {
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: NeoColors.bg,
            border: Border.all(color: NeoColors.ink, width: 3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: NeoColors.ink, offset: Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: NeoColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, size: 48, color: NeoColors.ink),
              ),
              const SizedBox(height: 16),
              const Text(
                'GAME SELESAI!',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: NeoColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Skor Akhir: $_score',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: NeoColors.ink,
                ),
              ),
              Text(
                'Waktu: ${(_elapsedMs / 1000).toStringAsFixed(1)} detik',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 14,
                  color: NeoColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      text: 'MAIN LAGI',
                      variant: NeoButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _loadPairsAndStart();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeoButton(
                      text: 'TUTUP',
                      variant: NeoButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: const Text(
          'PAIR RUSH (T10)',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: NeoColors.ink),
            onPressed: () => _showLeaderboardSheet(),
            tooltip: 'Papan Skor',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: NeoColors.ink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Game Header: Score, Combo, Timer
                  NeoCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('SKOR', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('$_score', style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.w800, fontSize: 20)),
                          ],
                        ),
                        Container(width: 2, height: 32, color: NeoColors.ink),
                        Column(
                          children: [
                            const Text('KOMBO', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('${_combo}x', style: TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.w800, fontSize: 20, color: _combo > 1 ? NeoColors.danger : NeoColors.ink)),
                          ],
                        ),
                        Container(width: 2, height: 32, color: NeoColors.ink),
                        Column(
                          children: [
                            const Text('WAKTU', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('${(_elapsedMs / 1000).toStringAsFixed(1)}s', style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.w800, fontSize: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cards Grid 4 columns x 3 rows
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      return _buildCardWidget(card);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Reset / New Game button
                  NeoButton(
                    text: 'ACAK & MULAI ULANG',
                    variant: NeoButtonVariant.secondary,
                    onPressed: _loadPairsAndStart,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCardWidget(GameCard card) {
    Color bgColor = NeoColors.surface;
    if (card.isMatched) {
      bgColor = NeoColors.success;
    } else if (card.isFlipped) {
      bgColor = card.isTerm ? NeoColors.primary : NeoColors.secondary;
    }

    return GestureDetector(
      onTap: () => _onCardTap(card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: NeoColors.ink, width: 2.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: card.isMatched
              ? null
              : const [
                  BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
                ],
        ),
        child: Center(
          child: card.isMatched
              ? const Icon(Icons.check, color: NeoColors.ink, size: 28)
              : card.isFlipped
                  ? Text(
                      card.text,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: card.isTerm ? 'Space Grotesk' : 'Hanken Grotesk',
                        fontWeight: card.isTerm ? FontWeight.w800 : FontWeight.w600,
                        fontSize: card.isTerm ? 13 : 11,
                        color: NeoColors.ink,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.help_outline, color: NeoColors.ink, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'KARTU',
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: NeoColors.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  void _showLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: NeoColors.bg,
          border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOP 10 PAPAN SKOR',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: NeoColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: NeoColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: NeoColors.ink, thickness: 2),
            Expanded(
              child: _leaderboard.isEmpty
                  ? const Center(child: Text('Belum ada skor yang dicatat.'))
                  : ListView.separated(
                      itemCount: _leaderboard.length,
                      separatorBuilder: (context, index) => const Divider(color: NeoColors.ink, thickness: 1),
                      itemBuilder: (context, index) {
                        final entry = _leaderboard[index];
                        final rank = entry['rank'];
                        Color medalColor = NeoColors.surface;
                        if (rank == 1) medalColor = NeoColors.primary;
                        if (rank == 2) medalColor = NeoColors.secondary;
                        if (rank == 3) medalColor = NeoColors.tertiary;

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: medalColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: NeoColors.ink, width: 2),
                            ),
                            child: Text(
                              '#$rank',
                              style: const TextStyle(
                                fontFamily: 'Space Mono',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            entry['user_name'] ?? 'Mahasiswa',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${entry['score']} PTS',
                                style: const TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${((entry['duration_ms'] ?? 0) / 1000).toStringAsFixed(1)}s',
                                style: TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontSize: 11,
                                  color: NeoColors.ink.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
