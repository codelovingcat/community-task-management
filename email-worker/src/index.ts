import 'dotenv/config';
import cron from 'node-cron';
import { processEmailQueue } from './worker';
import { processGeneralEmailQueue } from './generalQueueWorker';

function logRaw(message: string): void {
  console.log('[EmailWorker] ' + message);
}

process.on('unhandledRejection', (reason: unknown) => {
  const msg = reason instanceof Error ? reason.message : String(reason);
  logRaw('unhandledRejection: ' + msg);
});

process.on('uncaughtException', (err: Error) => {
  logRaw('uncaughtException: ' + err.message);
});

async function processAllQueues(): Promise<void> {
  // Keep speaker queue failures isolated from general transactional mail.
  try {
    await processEmailQueue();
  } catch (error) {
    logRaw('speaker queue error: ' + (error instanceof Error ? error.message : String(error)));
  }

  try {
    await processGeneralEmailQueue();
  } catch (error) {
    logRaw('general queue error: ' + (error instanceof Error ? error.message : String(error)));
  }
}

async function start(): Promise<void> {
  console.log('[EmailWorker] Servis başlatıldı. Cron: her 5 dakikada bir.');
  await processAllQueues();

  cron.schedule('*/5 * * * *', async () => {
    await processAllQueues();
  });
}

void start();
