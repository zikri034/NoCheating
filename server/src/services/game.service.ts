import db from '../db/knex';

export interface StudyPair {
  id: string;
  course_id: string;
  term: string;
  definition: string;
}

export interface LeaderboardEntry {
  rank: number;
  user_id: string;
  user_name: string;
  score: number;
  duration_ms: number;
  created_at: string;
}

/**
 * Fetch study pairs for courses
 */
export async function getStudyPairs(courseId?: string): Promise<StudyPair[]> {
  const query = db('study_pairs').select('*');
  if (courseId) {
    query.where({ course_id: courseId });
  }
  return await query;
}

/**
 * Record a student's game score
 */
export async function submitScore(
  userId: string,
  score: number,
  durationMs: number
) {
  const [record] = await db('game_scores')
    .insert({
      user_id: userId,
      score,
      duration_ms: durationMs,
      created_at: new Date(),
    })
    .returning('*');

  return record;
}

/**
 * Fetch top scores for Pair Rush leaderboard
 */
export async function getLeaderboard(limit = 10): Promise<LeaderboardEntry[]> {
  const records = await db('game_scores')
    .join('users', 'game_scores.user_id', 'users.id')
    .select(
      'game_scores.user_id',
      'users.name as user_name',
      'game_scores.score',
      'game_scores.duration_ms',
      'game_scores.created_at'
    )
    .orderBy([
      { column: 'game_scores.score', order: 'desc' },
      { column: 'game_scores.duration_ms', order: 'asc' },
    ])
    .limit(limit);

  return records.map((r, index) => ({
    rank: index + 1,
    user_id: r.user_id,
    user_name: r.user_name,
    score: Number(r.score),
    duration_ms: Number(r.duration_ms),
    created_at: new Date(r.created_at).toISOString(),
  }));
}
