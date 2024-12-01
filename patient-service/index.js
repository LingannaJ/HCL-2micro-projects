// Import the main application logic from app.js
const app = require('./app');

// Define the port from environment variables or default to 3000
const port = process.env.PORT || 3000;

// Start the server
app.listen(port, '0.0.0.0', () => {
  console.log(`Patient service listening at http://0.0.0.0:${port}`);
});
