# Architecture Overview

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│                      (React Application)                        │
│                      [To Be Implemented]                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTP/HTTPS
                             │
┌────────────────────────────┴────────────────────────────────────┐
│                      Express Server (Port 8080)                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      Middleware Stack                     │  │
│  │  • Helmet (Security Headers)                             │  │
│  │  • CORS (Cross-Origin)                                   │  │
│  │  • Compression (gzip)                                    │  │
│  │  • Morgan (Logging)                                      │  │
│  │  • Rate Limiting (100 req/15min)                         │  │
│  │  • Body Parser (JSON, URL-encoded)                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      API Routes                           │  │
│  │  • /api/bronze/*  - Bronze Layer Operations              │  │
│  │  • /api/silver/*  - Silver Layer Operations              │  │
│  │  • /api/*         - System Operations                    │  │
│  │  • /health        - Health Check                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Snowflake Connection Manager                 │  │
│  │  • Auto-detect mode (SPCS vs Standalone)                 │  │
│  │  • Connection pooling                                    │  │
│  │  • Query execution                                       │  │
│  │  • File upload                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Snowflake SDK
                             │
┌────────────────────────────┴────────────────────────────────────┐
│                      Snowflake Database                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Bronze Layer (DB_INGEST_PIPELINE.BRONZE)                 │  │
│  │  • TPA_MASTER                                            │  │
│  │  • FILE_PROCESSING_QUEUE                                 │  │
│  │  • RAW_DATA_TABLE                                        │  │
│  │  • FILE_STAGE, ERROR_STAGE, ARCHIVE_STAGE               │  │
│  │  • Processing procedures and tasks                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Silver Layer (DB_INGEST_PIPELINE.SILVER)                 │  │
│  │  • FIELD_MAPPINGS                                        │  │
│  │  • TRANSFORMATION_RULES                                  │  │
│  │  • TARGET_SCHEMAS                                        │  │
│  │  • Transformed data tables (claims, members, etc.)       │  │
│  │  • Transformation procedures                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Architectures

### Standalone Deployment

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       │
┌──────┴──────────────────────────────────────────────────────────┐
│                    Load Balancer (Optional)                      │
└──────┬──────────────────────────────────────────────────────────┘
       │
       │ HTTP
       │
┌──────┴──────────────────────────────────────────────────────────┐
│                      Docker Container                            │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   React Application                         │ │
│  │                   (Static Files)                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Express Server                            │ │
│  │                   (Node.js 20)                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Environment Variables                          │ │
│  │  • SNOWFLAKE_ACCOUNT                                       │ │
│  │  • SNOWFLAKE_USER                                          │ │
│  │  • SNOWFLAKE_PASSWORD                                      │ │
│  │  • SNOWFLAKE_DATABASE                                      │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────┬──────────────────────────────────────────────────────────┘
       │
       │ Snowflake SDK
       │ (Credential Auth)
       │
┌──────┴──────────────────────────────────────────────────────────┐
│                    Snowflake Cloud                               │
│                    (account.snowflakecomputing.com)              │
└─────────────────────────────────────────────────────────────────┘
```

### SPCS Deployment

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       │
┌──────┴──────────────────────────────────────────────────────────┐
│              Snowflake Ingress (Public Endpoint)                 │
│              (pipeline-app.snowflakecomputing.app)               │
└──────┬──────────────────────────────────────────────────────────┘
       │
       │ Internal Network
       │
┌──────┴──────────────────────────────────────────────────────────┐
│                    SPCS Compute Pool                             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                 Container Instance 1                        │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              React Application                        │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Express Server                           │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │         Session Token Volume                          │  │ │
│  │  │         /snowflake/session/token                      │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                 Container Instance 2                        │ │
│  │                 (Auto-scaled)                               │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────┬──────────────────────────────────────────────────────────┘
       │
       │ Internal Snowflake Network
       │ (Session Token Auth)
       │
┌──────┴──────────────────────────────────────────────────────────┐
│                    Snowflake Database                            │
│                    (Same Account)                                │
└─────────────────────────────────────────────────────────────────┘
```

## Component Architecture

### Backend Components

```
server/
├── index.js                    Main Server
│   ├── Express App Setup
│   ├── Middleware Configuration
│   ├── Route Registration
│   ├── Error Handling
│   └── Graceful Shutdown
│
├── routes/
│   ├── bronze.js              Bronze Layer API
│   │   ├── File Upload (Multer)
│   │   ├── Processing Queue
│   │   ├── Stage Management
│   │   ├── Raw Data Queries
│   │   └── Task Execution
│   │
│   ├── silver.js              Silver Layer API
│   │   ├── Field Mappings CRUD
│   │   ├── Transformation Rules CRUD
│   │   ├── Data Transformation
│   │   ├── Data Queries
│   │   └── Quality Metrics
│   │
│   └── system.js              System API
│       ├── Configuration
│       ├── TPA Management
│       ├── Schema Management
│       └── Statistics
│
└── utils/
    └── snowflake.js           Snowflake Connection
        ├── Mode Detection
        ├── Connection Management
        ├── Query Execution
        ├── File Upload
        └── Health Check
```

### Frontend Components (To Be Implemented)

```
src/
├── App.jsx                     Main Application
│   ├── Router Setup
│   ├── Layout
│   └── Global State
│
├── components/
│   ├── Layout/
│   │   ├── Header.jsx         Navigation
│   │   ├── Sidebar.jsx        Menu
│   │   └── Footer.jsx         Footer
│   │
│   ├── Bronze/
│   │   ├── FileUpload.jsx     Upload Component
│   │   ├── StatusTable.jsx    Processing Status
│   │   ├── StagesBrowser.jsx  Stage Files
│   │   └── RawDataTable.jsx   Raw Data Viewer
│   │
│   ├── Silver/
│   │   ├── MappingEditor.jsx  Field Mappings
│   │   ├── RulesEditor.jsx    Transform Rules
│   │   ├── DataViewer.jsx     Data Browser
│   │   └── QualityChart.jsx   Quality Metrics
│   │
│   └── Common/
│       ├── Button.jsx
│       ├── Card.jsx
│       ├── Table.jsx
│       ├── Modal.jsx
│       └── Loading.jsx
│
├── pages/
│   ├── BronzeUpload.jsx
│   ├── BronzeStatus.jsx
│   ├── SilverMappings.jsx
│   └── SilverRules.jsx
│
├── services/
│   ├── api.js                 Axios Instance
│   ├── bronze.js              Bronze API Calls
│   ├── silver.js              Silver API Calls
│   └── system.js              System API Calls
│
└── hooks/
    ├── useBronze.js           Bronze Operations
    ├── useSilver.js           Silver Operations
    └── useAuth.js             Authentication
```

## Data Flow

### File Upload Flow

```
1. User selects TPA and files
   ↓
2. React uploads to /api/bronze/upload
   ↓
3. Express receives files (Multer)
   ↓
4. Files saved to local temp directory
   ↓
5. Snowflake SDK uploads to @bronze.file_stage/<tpa>/
   ↓
6. Record added to file_processing_queue
   ↓
7. Local temp files deleted
   ↓
8. Response sent to React
   ↓
9. Snowflake task discovers and processes files
   ↓
10. Data inserted into raw_data_table
```

### Data Transformation Flow

```
1. User configures field mappings (TPA-specific)
   ↓
2. User configures transformation rules (TPA-specific)
   ↓
3. User triggers transformation
   ↓
4. React calls /api/silver/transform
   ↓
5. Express calls silver.transform_data(tpa, table)
   ↓
6. Snowflake procedure:
   - Reads raw_data_table (filtered by TPA)
   - Applies field mappings (TPA-specific or global)
   - Applies transformation rules (TPA-specific or global)
   - Validates data quality
   - Inserts into target table
   ↓
7. Response sent to React
   ↓
8. User views transformed data
```

## Authentication Flow

### Standalone Mode

```
1. Application starts
   ↓
2. Reads environment variables:
   - SNOWFLAKE_ACCOUNT
   - SNOWFLAKE_USER
   - SNOWFLAKE_PASSWORD
   ↓
3. Creates Snowflake connection with credentials
   ↓
4. Connection established
   ↓
5. API requests use this connection
```

### SPCS Mode

```
1. Application starts in SPCS container
   ↓
2. Detects /snowflake/session/token exists
   ↓
3. Reads session token from file
   ↓
4. Creates Snowflake connection with:
   - authenticator: 'OAUTH'
   - token: <session_token>
   ↓
5. Connection established (no credentials needed)
   ↓
6. API requests use this connection
   ↓
7. Token automatically rotated by Snowflake
```

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Network Security                                       │
│  • HTTPS/TLS encryption                                         │
│  • Firewall rules                                               │
│  • CORS configuration                                           │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: Application Security                                   │
│  • Rate limiting (100 req/15min)                                │
│  • Security headers (Helmet)                                    │
│  • Input validation                                             │
│  • SQL injection prevention (parameterized queries)             │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Authentication & Authorization                         │
│  • Session token (SPCS) or credentials (Standalone)             │
│  • Snowflake RBAC                                               │
│  • Service-level permissions                                    │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4: Container Security                                     │
│  • Non-root user (nodejs:1001)                                  │
│  • Minimal base image (Alpine)                                  │
│  • No unnecessary packages                                      │
│  • Read-only file system (where possible)                       │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ Layer 5: Data Security                                          │
│  • Encrypted at rest (Snowflake)                                │
│  • Encrypted in transit (TLS)                                   │
│  • No sensitive data in logs                                    │
│  • Secure credential storage                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Scalability Architecture

### Horizontal Scaling (SPCS)

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │    Load Balancer        │
              └────────────┬────────────┘
                           │
        ┏━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━┓
        ┃                                     ┃
   ┌────┴────┐                           ┌────┴────┐
   │Instance │                           │Instance │
   │    1    │                           │    2    │
   └────┬────┘                           └────┬────┘
        ┃                                     ┃
        ┗━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┛
                          │
                   ┌──────┴──────┐
                   │  Snowflake  │
                   │  Database   │
                   └─────────────┘

Auto-scaling based on:
• CPU utilization
• Request rate
• Response time
```

### Vertical Scaling

```
Instance Families:
┌────────────────┬──────────┬────────┬──────────┐
│ Family         │ vCPUs    │ Memory │ Use Case │
├────────────────┼──────────┼────────┼──────────┤
│ CPU_X64_XS     │ 1        │ 2 GB   │ Dev/Test │
│ CPU_X64_S      │ 2        │ 4 GB   │ Small    │
│ CPU_X64_M      │ 4        │ 8 GB   │ Medium   │
│ CPU_X64_L      │ 8        │ 16 GB  │ Large    │
│ CPU_X64_XL     │ 16       │ 32 GB  │ X-Large  │
└────────────────┴──────────┴────────┴──────────┘
```

## Monitoring Architecture

### Health Monitoring

```
┌─────────────────────────────────────────────────────────────────┐
│                      Health Check Endpoint                       │
│                      GET /health                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────┴────┐    ┌────┴────┐   ┌────┴────┐
         │ Server  │    │Snowflake│   │ System  │
         │ Status  │    │Connection│   │ Metrics │
         └─────────┘    └─────────┘   └─────────┘
              │              │              │
         ┌────┴────┐    ┌────┴────┐   ┌────┴────┐
         │Uptime   │    │Version  │   │CPU/Mem  │
         │Mode     │    │Healthy  │   │Requests │
         └─────────┘    └─────────┘   └─────────┘
```

### Logging Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Application Logs                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────┴────┐    ┌────┴────┐   ┌────┴────┐
         │ Morgan  │    │ Console │   │ Error   │
         │ (HTTP)  │    │  Logs   │   │  Logs   │
         └─────────┘    └─────────┘   └─────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                      ┌──────┴──────┐
                      │   Docker    │
                      │   Logs      │
                      └──────┬──────┘
                             │
                      ┌──────┴──────┐
                      │    SPCS     │
                      │   Logs      │
                      └─────────────┘
```

## Technology Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend Layer                           │
│  React 18 • Vite • TailwindCSS • React Query • React Router     │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/REST
┌────────────────────────────┴────────────────────────────────────┐
│                         Backend Layer                            │
│  Node.js 20 • Express 4 • Snowflake SDK • Multer               │
└────────────────────────────┬────────────────────────────────────┘
                             │ Snowflake Protocol
┌────────────────────────────┴────────────────────────────────────┐
│                         Data Layer                               │
│  Snowflake • Bronze Schema • Silver Schema • Stages             │
└─────────────────────────────────────────────────────────────────┘
```

---

**Version**: 1.0.0  
**Last Updated**: January 14, 2026  
**Status**: Architecture Documented ✅
