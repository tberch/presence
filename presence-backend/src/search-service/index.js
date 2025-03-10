const express = require('express');
const app = express();
const port = process.env.PORT || 3004;

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/', (req, res) => {
  res.json({ service: 'search-service', message: 'Welcome to the search-service API' });
});

app.listen(port, () => {
  console.log(`search-service listening on port ${port}`);
});
