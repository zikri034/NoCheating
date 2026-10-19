/**
 * Attempt Service (F04: Pelaksanaan Ujian)
 * Pure functions for deadline calculation, deterministic randomization, and MCQ grading.
 */

export function calculateServerDeadline(
  startTime: Date,
  durationMin: number,
  examEndAt: Date
): Date {
  const durationDeadline = new Date(startTime.getTime() + durationMin * 60 * 1000);
  return durationDeadline < examEndAt ? durationDeadline : examEndAt;
}

export function isDeadlineExceeded(
  currentTime: Date,
  serverDeadline: Date,
  graceSeconds: number = 60
): boolean {
  const allowedUntil = new Date(serverDeadline.getTime() + graceSeconds * 1000);
  return currentTime > allowedUntil;
}

export function seededRandom(seed: number): () => number {
  let s = Math.abs(seed) % 2147483647;
  if (s <= 0) s = 1;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

export function shuffleArray<T>(array: T[], rng: () => number): T[] {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export interface QuestionForAttempt {
  id: string;
  type: string;
  body: string;
  options?: any;
  max_score: number | string;
  position?: number;
  correct_option?: string;
}

export function randomizeQuestionsForAttempt(
  questions: QuestionForAttempt[],
  seed: number
): QuestionForAttempt[] {
  const rng = seededRandom(seed);
  const shuffledQuestions = shuffleArray(questions, rng);

  return shuffledQuestions.map((q, idx) => {
    let options = q.options;
    if (typeof options === 'string') {
      try {
        options = JSON.parse(options);
      } catch (_) {}
    }

    if (Array.isArray(options) && options.length > 1) {
      options = shuffleArray(options, rng);
    }

    return {
      id: q.id,
      type: q.type,
      body: q.body,
      options,
      max_score: Number(q.max_score),
      position: idx + 1,
    };
  });
}

export interface McqGradingResult {
  totalMcqScore: number;
  maxPossibleMcqScore: number;
  hasEssay: boolean;
  gradedQuestions: Array<{
    question_id: string;
    type: string;
    max_score: number;
    awarded_score: number;
    is_correct: boolean;
  }>;
}

export function gradeMultipleChoice(
  questions: Array<{ id: string; type: string; max_score: number | string; correct_option?: string | null }>,
  answers: Array<{ question_id: string; selected_option?: string | null }>
): McqGradingResult {
  let totalScore = 0;
  let maxPossibleScore = 0;
  let hasEssay = false;
  const gradedQuestions: McqGradingResult['gradedQuestions'] = [];

  const answerMap = new Map<string, string>();
  for (const a of answers) {
    if (a.selected_option) {
      answerMap.set(a.question_id, a.selected_option.trim().toUpperCase());
    }
  }

  for (const q of questions) {
    const maxScore = Number(q.max_score) || 0;
    if (q.type === 'mcq') {
      maxPossibleScore += maxScore;
      const studentAns = answerMap.get(q.id);
      const correctAns = q.correct_option ? q.correct_option.trim().toUpperCase() : null;
      const isCorrect = !!studentAns && !!correctAns && studentAns === correctAns;
      const awarded = isCorrect ? maxScore : 0;
      totalScore += awarded;

      gradedQuestions.push({
        question_id: q.id,
        type: 'mcq',
        max_score: maxScore,
        awarded_score: awarded,
        is_correct: isCorrect,
      });
    } else {
      hasEssay = true;
      gradedQuestions.push({
        question_id: q.id,
        type: q.type,
        max_score: maxScore,
        awarded_score: 0,
        is_correct: false,
      });
    }
  }

  return {
    totalMcqScore: Math.round(totalScore * 100) / 100,
    maxPossibleMcqScore: Math.round(maxPossibleScore * 100) / 100,
    hasEssay,
    gradedQuestions,
  };
}
