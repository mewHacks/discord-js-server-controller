const express = require('express');
const { sendNotification } = require('../bot/bot');

const app = express();
app.use(express.json());

// ─── Health check ───────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

// ─── Predefined notification endpoints ─────────────────────────────

app.post('/notify/started', async (_req, res) => {
  try {
    await sendNotification({
      title: '✅  Server Started',
      description: 'The VM server is now **running** and ready to accept connections.',
      color: 0x00c853,
    });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/notify/stopped', async (_req, res) => {
  try {
    await sendNotification({
      title: '⛔  Server Stopped',
      description: 'The VM server has been **stopped**.',
      color: 0xd50000,
    });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/notify/stopping', async (_req, res) => {
  try {
    await sendNotification({
      title: '🛑  Server Stopping',
      description: 'The VM server is **shutting down**. It will be unavailable shortly.',
      color: 0xff6d00,
    });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/notify/starting', async (_req, res) => {
  try {
    await sendNotification({
      title: '🚀  Server Starting',
      description: 'The VM server is **booting up**. Please wait…',
      color: 0x2979ff,
    });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// ─── Generic event endpoint ─────────────────────────────────────────
app.post('/notify/event', async (req, res) => {
  const { title, description, color } = req.body;

  if (!title || !description) {
    return res
      .status(400)
      .json({ error: '"title" and "description" are required in the request body.' });
  }

  try {
    await sendNotification({
      title,
      description,
      color: color ?? 0x607d8b,
    });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = app;
