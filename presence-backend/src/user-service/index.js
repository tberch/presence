const express = require('express');
const app = express();
const port = process.env.PORT || 3003;

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/', (req, res) => {
  res.json({ service: 'user-service', message: 'Welcome to the user-service API' });
});

app.listen(port, () => {
  console.log(`user-service listening on port ${port}`);
});
