require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const rateLimit = require('express-rate-limit');

const { getSnowflakeConnection } = require('./utils/snowflake');

// Import routes
const bronzeRoutes = require('./routes/bronze');
const silverRoutes = require('./routes/silver');
const systemRoutes = require('./routes/system');

const app = express();
const PORT = process.env.PORT || 8080;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false, // Allow inline scripts for React
  crossOriginEmbedderPolicy: false
}));

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGINS 
    ? process.env.CORS_ORIGINS.split(',') 
    : ['http://localhost:5173', 'http://localhost:3000'],
  credentials: true
};
app.use(cors(corsOptions));

// Compression
app.use(compression());

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
}

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: (process.env.API_RATE_WINDOW || 15) * 60 * 1000,
  max: process.env.API_RATE_LIMIT || 100,
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const snowflake = getSnowflakeConnection();
    const health = await snowflake.healthCheck();
    
    res.status(health.healthy ? 200 : 503).json({
      status: health.healthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      mode: health.mode,
      snowflake: {
        connected: health.healthy,
        version: health.version,
        error: health.error
      },
      uptime: process.uptime()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// API routes
app.use('/api/bronze', bronzeRoutes);
app.use('/api/silver', silverRoutes);
app.use('/api', systemRoutes);

// Serve static files (React build)
app.use(express.static(path.join(__dirname, 'public')));

// Catch-all route for React Router
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal server error';
  
  res.status(statusCode).json({
    error: {
      message: message,
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    }
  });
});

// Initialize Snowflake connection on startup
async function initializeApp() {
  try {
    console.log('Initializing Snowflake Pipeline Application...');
    console.log(`Mode: ${process.env.NODE_ENV || 'development'}`);
    
    const snowflake = getSnowflakeConnection();
    await snowflake.connect();
    
    console.log('Snowflake connection established');
    
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Health check: http://localhost:${PORT}/health`);
    });
  } catch (error) {
    console.error('Failed to initialize application:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  
  try {
    const snowflake = getSnowflakeConnection();
    await snowflake.disconnect();
    console.log('Snowflake connection closed');
    process.exit(0);
  } catch (error) {
    console.error('Error during shutdown:', error);
    process.exit(1);
  }
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  
  try {
    const snowflake = getSnowflakeConnection();
    await snowflake.disconnect();
    console.log('Snowflake connection closed');
    process.exit(0);
  } catch (error) {
    console.error('Error during shutdown:', error);
    process.exit(1);
  }
});

// Start the application
if (require.main === module) {
  initializeApp();
}

module.exports = app;
