const express = require('express');
const app = express();
const port = process.env.PORT || 3002;

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/', (req, res) => {
  res.json({ service: 'chat-service', message: 'Welcome to the chat-service API' });
});

app.listen(port, () => {
  console.log(`chat-service listening on port ${port}`);
});
