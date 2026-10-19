import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import db from './db/knex';
import authRoutes from './routes/auth';
import biometricRoutes from './routes/biometric';
import meRoutes from './routes/me';
import examRoutes from './routes/exams';
import questionRoutes from './routes/questions';
import courseRoutes from './routes/courses';
import attemptRoutes from './routes/attempts';
import reviewRoutes, { essayGradesRouter } from './routes/reviews';
import chainRoutes from './routes/chain';
import fxRoutes from './routes/fx';
import gameRoutes from './routes/game';
import feedbackRoutes from './routes/feedback';

dotenv.config();

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());

// Serve static uploads
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/auth/biometric', biometricRoutes);
app.use('/api/me', meRoutes);
app.use('/api/exams', examRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/attempts', attemptRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/essay-grades', essayGradesRouter);
app.use('/api/chain', chainRoutes);
app.use('/api/fx', fxRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api', gameRoutes);

// Server Time (authoritative timer sync)
app.get('/api/time', (_req, res) => {
  res.json({ time: new Date().toISOString() });
});

// Health Check
app.get('/api/health', async (_req, res) => {
  try {
    await db.raw('SELECT 1');
    res.json({ status: 'ok', database: 'connected' });
  } catch (_error) {
    res.status(500).json({ status: 'error', message: 'Database connection failed' });
  }
});

// Global Error Handler
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: {
      code: err.code || 'INTERNAL_SERVER_ERROR',
      message: err.message || 'An unexpected error occurred'
    }
  });
});

const PORT = process.env.PORT || 3000;
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
}

export default app;
