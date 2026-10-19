import crypto from 'crypto';
import * as mammoth from 'mammoth';
import { GoogleGenAI } from '@google/genai';
import {
  buildEssayGradingPrompt,
  essayGradingResultSchema,
  EssayGradingResult,
  GEMINI_JSON_SCHEMA,
  PromptInput,
  SYSTEM_INSTRUCTION,
  buildQuestionExtractionPrompt,
  extractedQuestionsResultSchema,
  ExtractedQuestionsResult,
  GEMINI_QUESTION_EXTRACTION_SCHEMA,
  QUESTION_EXTRACTION_SYSTEM_INSTRUCTION,
} from './prompts';

export interface GradeEssayOptions extends PromptInput {
  attemptId?: string;
}

export interface ExtractDocumentInput {
  buffer: Buffer;
  mimeType: string;
  originalFilename?: string;
}

export type MockGradingFunction = (input: GradeEssayOptions) => Promise<EssayGradingResult>;
export type MockExtractionFunction = (input: ExtractDocumentInput) => Promise<ExtractedQuestionsResult>;

export class GeminiService {
  private cache = new Map<string, EssayGradingResult>();
  private mockHandler: MockGradingFunction | null = null;
  private mockExtractionHandler: MockExtractionFunction | null = null;

  public setMockHandler(handler: MockGradingFunction | null) {
    this.mockHandler = handler;
  }

  public setMockExtractionHandler(handler: MockExtractionFunction | null) {
    this.mockExtractionHandler = handler;
  }

  public clearCache() {
    this.cache.clear();
  }

  public computeCacheKey(studentAnswer: string, rubric: string, model: string): string {
    return crypto
      .createHash('sha256')
      .update(`${studentAnswer.trim()}|${rubric.trim()}|${model}`)
      .digest('hex');
  }

  /**
   * Evaluasi dan koreksi essay menggunakan Gemini 2.0 Flash dengan Structured Output JSON.
   */
  public async gradeEssay(input: GradeEssayOptions): Promise<{
    result: EssayGradingResult;
    model: string;
    cached: boolean;
  }> {
    const model = process.env.GEMINI_MODEL || 'gemini-3.8-flash';
    const cacheKey = this.computeCacheKey(input.studentAnswer, input.rubric, model);

    // 1. Check in-memory cache
    if (this.cache.has(cacheKey)) {
      return {
        result: this.cache.get(cacheKey)!,
        model,
        cached: true,
      };
    }

    // 2. If a mock handler is configured (e.g. during testing)
    if (this.mockHandler) {
      const mockResult = await this.mockHandler(input);
      const validated = this.validateAndClampResult(mockResult, input.maxScore);
      this.cache.set(cacheKey, validated);
      return { result: validated, model, cached: false };
    }

    // 3. Fallback when GEMINI_API_KEY is not configured
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY_NOT_CONFIGURED');
    }

    const ai = new GoogleGenAI({ apiKey });
    const promptText = buildEssayGradingPrompt(input);

    // Retry configuration with exponential backoff (PRD F07)
    const maxRetries = 3;
    let delayMs = 1000;
    let lastError: any = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await ai.models.generateContent({
          model,
          contents: promptText,
          config: {
            systemInstruction: SYSTEM_INSTRUCTION,
            temperature: 0.1,
            responseMimeType: 'application/json',
            responseSchema: GEMINI_JSON_SCHEMA,
          },
        });

        const rawText = response.text;
        if (!rawText) {
          throw new Error('EMPTY_GEMINI_RESPONSE');
        }

        const parsedJson = JSON.parse(rawText);
        const validated = this.validateAndClampResult(parsedJson, input.maxScore);

        this.cache.set(cacheKey, validated);
        return { result: validated, model, cached: false };
      } catch (err: any) {
        lastError = err;
        const statusCode = err?.status || err?.statusCode || 0;
        const isRateLimitOrServerError =
          statusCode === 429 || (statusCode >= 500 && statusCode < 600);

        if (attempt < maxRetries && isRateLimitOrServerError) {
          await new Promise((resolve) => setTimeout(resolve, delayMs));
          delayMs *= 2;
        } else if (!isRateLimitOrServerError) {
          break;
        }
      }
    }

    throw lastError || new Error('GEMINI_GRADING_FAILED');
  }

  /**
   * Ekstraksi naskah soal dari dokumen (PDF / Word DOCX / Text) menggunakan Gemini 2.0 Flash.
   */
  public async extractQuestionsFromDocument(input: ExtractDocumentInput): Promise<{
    result: ExtractedQuestionsResult;
    model: string;
  }> {
    const model = process.env.GEMINI_MODEL || 'gemini-3.8-flash';

    if (this.mockExtractionHandler) {
      const mockResult = await this.mockExtractionHandler(input);
      const validated = extractedQuestionsResultSchema.parse(mockResult);
      return { result: validated, model };
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY_NOT_CONFIGURED');
    }

    const ai = new GoogleGenAI({ apiKey });
    const filename = (input.originalFilename || '').toLowerCase();
    const mime = input.mimeType.toLowerCase();

    let contentsPayload: any;

    if (mime.includes('pdf') || filename.endsWith('.pdf')) {
      // PDF directly sent as inlineData
      contentsPayload = [
        {
          inlineData: {
            mimeType: 'application/pdf',
            data: input.buffer.toString('base64'),
          },
        },
        {
          text: buildQuestionExtractionPrompt(),
        },
      ];
    } else if (
      mime.includes('word') ||
      mime.includes('officedocument') ||
      filename.endsWith('.docx') ||
      filename.endsWith('.doc')
    ) {
      // DOCX extracted via mammoth
      let extractedText = '';
      try {
        const mammothResult = await mammoth.extractRawText({ buffer: input.buffer });
        extractedText = mammothResult.value;
      } catch (err: any) {
        throw new Error(`DOCX_PARSING_FAILED: ${err.message}`);
      }
      contentsPayload = buildQuestionExtractionPrompt(extractedText);
    } else {
      // Plain text or fallback
      const text = input.buffer.toString('utf-8');
      contentsPayload = buildQuestionExtractionPrompt(text);
    }

    const maxRetries = 3;
    let delayMs = 1000;
    let lastError: any = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await ai.models.generateContent({
          model,
          contents: contentsPayload,
          config: {
            systemInstruction: QUESTION_EXTRACTION_SYSTEM_INSTRUCTION,
            temperature: 0.1,
            responseMimeType: 'application/json',
            responseSchema: GEMINI_QUESTION_EXTRACTION_SCHEMA,
          },
        });

        const rawText = response.text;
        if (!rawText) {
          throw new Error('EMPTY_GEMINI_RESPONSE');
        }

        const parsedJson = JSON.parse(rawText);
        const validated = extractedQuestionsResultSchema.parse(parsedJson);

        // Sort questions strictly by question number
        validated.questions.sort((a, b) => a.number - b.number);
        validated.total_questions = validated.questions.length;

        return { result: validated, model };
      } catch (err: any) {
        lastError = err;
        const statusCode = err?.status || err?.statusCode || 0;
        const isRateLimitOrServerError =
          statusCode === 429 || (statusCode >= 500 && statusCode < 600);

        if (attempt < maxRetries && isRateLimitOrServerError) {
          await new Promise((resolve) => setTimeout(resolve, delayMs));
          delayMs *= 2;
        } else if (!isRateLimitOrServerError) {
          break;
        }
      }
    }

    throw lastError || new Error('GEMINI_QUESTION_EXTRACTION_FAILED');
  }

  /**
   * Validasi dengan Zod schema dan clamp skor ke rentang 0..maxScore
   */
  public validateAndClampResult(data: unknown, maxScore: number): EssayGradingResult {
    const parsed = essayGradingResultSchema.parse(data);

    // Clamp total score
    let clampedScore = Math.max(0, Math.min(maxScore, parsed.score));

    // Clamp rubric breakdown items
    const clampedBreakdown = parsed.rubric_breakdown.map((item) => ({
      ...item,
      points: Math.max(0, Math.min(item.max_points, item.points)),
    }));

    return {
      ...parsed,
      score: Number(clampedScore.toFixed(2)),
      rubric_breakdown: clampedBreakdown,
    };
  }
}

export const geminiService = new GeminiService();
