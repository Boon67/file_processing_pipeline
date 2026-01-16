# Snowflake Pipeline React Application

A modern React application that combines Bronze and Silver layer capabilities with support for both Snowpark Container Services (SPCS) and standalone deployment.

## Features

### Bronze Layer Capabilities
- 📤 **File Upload**: Upload CSV/Excel files with TPA selection
- 📊 **Processing Status**: Monitor file processing in real-time
- 📂 **File Stages**: Browse files across all stages
- 📋 **Raw Data Viewer**: View and filter raw data
- ⚙️ **Task Management**: Control pipeline tasks

### Silver Layer Capabilities
- 🗺️ **Field Mapping**: Create and manage field mappings
- 📏 **Transformation Rules**: Define data quality and business rules
- 🔄 **Data Transformation**: Execute transformations
- 📈 **Data Viewer**: View transformed data
- 📊 **Quality Dashboard**: Monitor data quality metrics

## Architecture

```
app/
├── src/                    # React frontend
│   ├── components/         # Reusable components
│   ├── pages/             # Page components
│   ├── services/          # API services
│   ├── hooks/             # Custom React hooks
│   └── utils/             # Utility functions
│
├── server/                # Node.js backend
│   ├── routes/            # API routes
│   ├── middleware/        # Express middleware
│   ├── utils/             # Utility functions
│   └── index.js           # Server entry point
│
├── Dockerfile             # Multi-stage Docker build
├── docker-compose.yml     # Local development
└── spcs/                  # SPCS deployment files
```

## Deployment Modes

### 1. Snowpark Container Services (SPCS)

Runs inside Snowflake using session token authentication.

**Features:**
- ✅ No credentials needed (uses session token)
- ✅ Runs within Snowflake security boundary
- ✅ Direct access to Snowflake resources
- ✅ Automatic scaling

**Token Location:** `/snowflake/session/token`

### 2. Standalone Deployment

Runs as a separate container with credential-based authentication.

**Features:**
- ✅ Can run anywhere (AWS, Azure, GCP, on-prem)
- ✅ Uses Snowflake credentials
- ✅ Independent scaling
- ✅ Flexible deployment options

## Quick Start

### Prerequisites

- Node.js 20+
- Docker
- Snowflake account

### Local Development

```bash
# Install dependencies
cd app
npm install
cd server && npm install && cd ..

# Set environment variables
cp .env.example .env
# Edit .env with your Snowflake credentials

# Start backend (terminal 1)
cd server
npm run dev

# Start frontend (terminal 2)
npm run dev
```

### Docker Build

```bash
# Build image
docker build -t snowflake-pipeline-app:latest .

# Run standalone
docker run -p 8080:8080 \
  -e SNOWFLAKE_ACCOUNT=your_account \
  -e SNOWFLAKE_USER=your_user \
  -e SNOWFLAKE_PASSWORD=your_password \
  -e SNOWFLAKE_DATABASE=DB_INGEST_PIPELINE \
  snowflake-pipeline-app:latest
```

### SPCS Deployment

```bash
# Build and push to Snowflake registry
docker build -t snowflake-pipeline-app:latest .
docker tag snowflake-pipeline-app:latest <org>-<account>.registry.snowflakecomputing.com/db_ingest_pipeline/public/snowflake-pipeline-app:latest
docker push <org>-<account>.registry.snowflakecomputing.com/db_ingest_pipeline/public/snowflake-pipeline-app:latest

# Deploy using SQL (see spcs/deploy.sql)
```

## Environment Variables

### Required for Standalone

```env
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_DATABASE=DB_INGEST_PIPELINE
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
```

### Required for SPCS

```env
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_DATABASE=DB_INGEST_PIPELINE
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SPCS_TOKEN_PATH=/snowflake/session/token
```

### Optional

```env
PORT=8080
NODE_ENV=production
LOG_LEVEL=info
```

## API Endpoints

### Bronze Layer

- `GET /api/bronze/files` - List files in processing queue
- `POST /api/bronze/upload` - Upload files
- `GET /api/bronze/stages` - List stage files
- `GET /api/bronze/raw-data` - Query raw data
- `GET /api/bronze/tasks` - Get task status
- `POST /api/bronze/tasks/:name/execute` - Execute task

### Silver Layer

- `GET /api/silver/mappings` - List field mappings
- `POST /api/silver/mappings` - Create mapping
- `GET /api/silver/rules` - List transformation rules
- `POST /api/silver/rules` - Create rule
- `POST /api/silver/transform` - Execute transformation
- `GET /api/silver/data` - Query transformed data

### System

- `GET /health` - Health check
- `GET /api/config` - Get configuration
- `GET /api/tpas` - List TPAs

## Technology Stack

### Frontend
- **React 18** - UI framework
- **Vite** - Build tool
- **TailwindCSS** - Styling
- **React Query** - Data fetching
- **React Router** - Routing
- **Recharts** - Data visualization
- **Lucide React** - Icons

### Backend
- **Node.js 20** - Runtime
- **Express** - Web framework
- **Snowflake SDK** - Snowflake connectivity
- **Multer** - File uploads
- **Helmet** - Security headers
- **Morgan** - Logging

### DevOps
- **Docker** - Containerization
- **Multi-stage builds** - Optimized images
- **Health checks** - Container monitoring

## Security

### SPCS Mode
- ✅ Session token authentication
- ✅ No credentials in environment
- ✅ Runs within Snowflake boundary
- ✅ Automatic token rotation

### Standalone Mode
- ✅ Environment variable credentials
- ✅ HTTPS recommended
- ✅ Rate limiting
- ✅ Security headers (Helmet)
- ✅ CORS configuration

### General
- ✅ Non-root user in container
- ✅ Minimal attack surface
- ✅ No sensitive data in logs
- ✅ Input validation

## Performance

### Optimizations
- ✅ Multi-stage Docker build (smaller image)
- ✅ Frontend build optimization (Vite)
- ✅ Connection pooling (Snowflake)
- ✅ Response compression (gzip)
- ✅ Static file caching
- ✅ React Query caching

### Monitoring
- Health check endpoint
- Request logging (Morgan)
- Error tracking
- Performance metrics

## Development

### Project Structure

```
app/
├── src/
│   ├── App.jsx                 # Main app component
│   ├── main.jsx               # Entry point
│   ├── components/
│   │   ├── Layout/            # Layout components
│   │   ├── Bronze/            # Bronze layer components
│   │   ├── Silver/            # Silver layer components
│   │   └── Common/            # Shared components
│   ├── pages/
│   │   ├── BronzeUpload.jsx
│   │   ├── BronzeStatus.jsx
│   │   ├── SilverMappings.jsx
│   │   └── SilverRules.jsx
│   ├── services/
│   │   ├── api.js             # API client
│   │   ├── bronze.js          # Bronze API
│   │   └── silver.js          # Silver API
│   └── utils/
│       ├── format.js          # Formatting utilities
│       └── validation.js      # Validation utilities
│
└── server/
    ├── index.js               # Server entry
    ├── routes/
    │   ├── bronze.js          # Bronze routes
    │   ├── silver.js          # Silver routes
    │   └── system.js          # System routes
    ├── middleware/
    │   ├── auth.js            # Authentication
    │   ├── error.js           # Error handling
    │   └── upload.js          # File upload
    └── utils/
        └── snowflake.js       # Snowflake connection
```

### Adding New Features

1. **Frontend**: Add component in `src/components/`
2. **Backend**: Add route in `server/routes/`
3. **API**: Add service method in `src/services/`
4. **Update**: Rebuild Docker image

### Testing

```bash
# Frontend tests
npm test

# Backend tests
cd server && npm test

# E2E tests
npm run test:e2e

# Build test
docker build -t test .
```

## Troubleshooting

### SPCS Token Not Found

**Problem**: Cannot read session token

**Solution**:
- Verify SPCS deployment
- Check token path: `/snowflake/session/token`
- Ensure volume mount is correct

### Connection Failed

**Problem**: Cannot connect to Snowflake

**Solution**:
- Check environment variables
- Verify credentials
- Test network connectivity
- Check Snowflake account status

### File Upload Fails

**Problem**: Cannot upload files

**Solution**:
- Check stage permissions
- Verify file size limits
- Check disk space
- Review error logs

## License

MIT

## Support

For issues and questions:
- Check documentation
- Review logs
- Contact support

---

**Version**: 1.0.0  
**Last Updated**: January 14, 2026  
**Status**: Ready for development
