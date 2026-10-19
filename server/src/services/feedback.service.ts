import db from '../db/knex';

export interface FeedbackData {
  impression: string;
  suggestion?: string;
  rating: number;
}

/**
 * Submit course feedback
 */
export async function createFeedback(userId: string, data: FeedbackData) {
  const [feedback] = await db('course_feedback')
    .insert({
      user_id: userId,
      impression: data.impression.trim(),
      suggestion: data.suggestion ? data.suggestion.trim() : null,
      rating: data.rating,
      created_at: new Date(),
    })
    .returning('*');

  return feedback;
}

/**
 * Fetch feedback history for the current user
 */
export async function getFeedbackByUser(userId: string) {
  return await db('course_feedback')
    .where({ user_id: userId })
    .orderBy('created_at', 'desc');
}

/**
 * Fetch all feedback entries (accessible by lecturer)
 */
export async function getAllFeedback() {
  return await db('course_feedback')
    .join('users', 'course_feedback.user_id', 'users.id')
    .select(
      'course_feedback.id',
      'course_feedback.impression',
      'course_feedback.suggestion',
      'course_feedback.rating',
      'course_feedback.created_at',
      'users.name as student_name',
      'users.nim as student_nim'
    )
    .orderBy('course_feedback.created_at', 'desc');
}
