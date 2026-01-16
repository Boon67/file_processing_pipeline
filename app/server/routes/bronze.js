const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const { getSnowflakeConnection } = require('../utils/snowflake');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../uploads');
    await fs.mkdir(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedExtensions = ['.csv', '.xlsx', '.xls'];
    const ext = path.extname(file.originalname).toLowerCase();
    
    if (allowedExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only CSV and Excel files are allowed'));
    }
  }
});

/**
 * GET /api/bronze/files
 * Get files in processing queue with TPA information
 * Matches Streamlit query: get_processed_files_summary()
 */
router.get('/files', async (req, res, next) => {
  try {
    const { status, tpa, limit = 100, offset = 0 } = req.query;
    const snowflake = getSnowflakeConnection();
    const database = process.env.SNOWFLAKE_DATABASE || 'DB_INGEST_PIPELINE';
    
    // Match Streamlit query exactly
    let query = `
      SELECT 
        fpq.file_name,
        fpq.file_type,
        fpq.status,
        fpq.discovered_timestamp,
        fpq.processed_timestamp,
        fpq.process_result,
        fpq.error_message,
        COALESCE(rdt.tpa, 'N/A') as tpa
      FROM ${database}.BRONZE.file_processing_queue fpq
      LEFT JOIN (
        SELECT DISTINCT file_name, tpa
        FROM ${database}.BRONZE.RAW_DATA_TABLE
      ) rdt ON fpq.file_name = rdt.file_name
      WHERE 1=1
    `;
    
    const binds = [];
    
    if (status) {
      query += ` AND fpq.status = ?`;
      binds.push(status);
    }
    
    if (tpa) {
      query += ` AND rdt.tpa = ?`;
      binds.push(tpa);
    }
    
    query += ` ORDER BY fpq.discovered_timestamp DESC`;
    
    const files = await snowflake.query(query, binds);
    
    res.json({
      files: files,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: files.length
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/bronze/upload
 * Upload files to Bronze layer
 */
router.post('/upload', upload.array('files', 10), async (req, res, next) => {
  try {
    const { tpa } = req.body;
    
    if (!tpa) {
      return res.status(400).json({ error: 'TPA is required' });
    }
    
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files uploaded' });
    }
    
    const snowflake = getSnowflakeConnection();
    const uploadedFiles = [];
    
    for (const file of req.files) {
      try {
        // Upload to Snowflake stage
        const stagePath = `@bronze.file_stage/${tpa}/${file.originalname}`;
        await snowflake.uploadFile(file.path, stagePath);
        
        // Add to processing queue
        await snowflake.execute(`
          INSERT INTO bronze.file_processing_queue (file_name, file_size, status)
          VALUES (?, ?, 'pending')
        `, [`${tpa}/${file.originalname}`, file.size]);
        
        uploadedFiles.push({
          originalName: file.originalname,
          size: file.size,
          tpa: tpa,
          status: 'uploaded'
        });
        
        // Clean up local file
        await fs.unlink(file.path);
      } catch (error) {
        console.error(`Error uploading ${file.originalname}:`, error);
        uploadedFiles.push({
          originalName: file.originalname,
          size: file.size,
          tpa: tpa,
          status: 'failed',
          error: error.message
        });
      }
    }
    
    res.json({
      message: 'Files uploaded successfully',
      files: uploadedFiles
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/bronze/stages
 * List files in stages
 */
router.get('/stages', async (req, res, next) => {
  try {
    const { stage = 'file_stage' } = req.query;
    const snowflake = getSnowflakeConnection();
    
    const files = await snowflake.query(`
      LIST @bronze.${stage}
    `);
    
    res.json({
      stage: stage,
      files: files
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/bronze/raw-data
 * Query raw data table
 */
router.get('/raw-data', async (req, res, next) => {
  try {
    const { tpa, file_id, limit = 100, offset = 0 } = req.query;
    const snowflake = getSnowflakeConnection();
    
    let query = `
      SELECT 
        file_id,
        row_number,
        tpa,
        data,
        created_timestamp
      FROM bronze.raw_data_table
      WHERE 1=1
    `;
    
    const binds = [];
    
    if (tpa) {
      query += ` AND tpa = ?`;
      binds.push(tpa);
    }
    
    if (file_id) {
      query += ` AND file_id = ?`;
      binds.push(file_id);
    }
    
    query += ` ORDER BY created_timestamp DESC, row_number LIMIT ? OFFSET ?`;
    binds.push(parseInt(limit), parseInt(offset));
    
    const rows = await snowflake.query(query, binds);
    
    // Get summary statistics
    const summary = await snowflake.query(`
      SELECT 
        COUNT(*) as total_rows,
        COUNT(DISTINCT tpa) as total_tpas,
        COUNT(DISTINCT file_id) as total_files
      FROM bronze.raw_data_table
      ${tpa ? 'WHERE tpa = ?' : ''}
    `, tpa ? [tpa] : []);
    
    res.json({
      data: rows,
      summary: summary[0],
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset)
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/bronze/tasks
 * Get task status
 */
router.get('/tasks', async (req, res, next) => {
  try {
    const snowflake = getSnowflakeConnection();
    
    const tasks = await snowflake.query(`
      SHOW TASKS IN SCHEMA bronze
    `);
    
    res.json({
      tasks: tasks
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/bronze/tasks/:name/execute
 * Execute a task manually
 */
router.post('/tasks/:name/execute', async (req, res, next) => {
  try {
    const { name } = req.params;
    const snowflake = getSnowflakeConnection();
    
    await snowflake.execute(`EXECUTE TASK bronze.${name}`);
    
    res.json({
      message: `Task ${name} executed successfully`
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/bronze/summary
 * Get Bronze layer summary statistics
 * Matches Streamlit query: get_processed_files_stats()
 */
router.get('/summary', async (req, res, next) => {
  try {
    const snowflake = getSnowflakeConnection();
    const database = process.env.SNOWFLAKE_DATABASE || 'DB_INGEST_PIPELINE';
    
    // Match Streamlit query exactly
    const summary = await snowflake.query(`
      SELECT 
        COUNT(*) as total_files,
        SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_files,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_files,
        SUM(CASE WHEN status = 'PROCESSING' THEN 1 ELSE 0 END) as processing_files,
        SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending_files,
        SUM(CASE WHEN process_result LIKE '%rows%' THEN 
          TRY_CAST(REGEXP_SUBSTR(process_result, '[0-9]+') AS INTEGER) 
          ELSE 0 END) as total_rows_processed
      FROM ${database}.BRONZE.file_processing_queue
    `);
    
    const rawDataSummary = await snowflake.query(`
      SELECT 
        COUNT(*) as total_records,
        COUNT(DISTINCT tpa) as total_tpas,
        COUNT(DISTINCT file_name) as total_files
      FROM ${database}.BRONZE.RAW_DATA_TABLE
    `);
    
    res.json({
      files: summary[0],
      rawData: rawDataSummary[0]
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
