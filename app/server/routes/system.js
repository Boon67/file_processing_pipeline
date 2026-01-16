const express = require('express');
const router = express.Router();
const { getSnowflakeConnection } = require('../utils/snowflake');

/**
 * GET /api/config
 * Get system configuration
 */
router.get('/config', async (req, res, next) => {
  try {
    const snowflake = getSnowflakeConnection();
    
    res.json({
      mode: snowflake.isSPCS ? 'SPCS' : 'Standalone',
      database: process.env.SNOWFLAKE_DATABASE || 'DB_INGEST_PIPELINE',
      warehouse: process.env.SNOWFLAKE_WAREHOUSE || 'COMPUTE_WH',
      environment: process.env.NODE_ENV || 'development',
      version: '1.0.0'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/tpas
 * Get list of TPAs
 * Matches Streamlit query: get_tpa_list()
 */
router.get('/tpas', async (req, res, next) => {
  try {
    const { active_only = 'true' } = req.query;
    const snowflake = getSnowflakeConnection();
    const database = process.env.SNOWFLAKE_DATABASE || 'DB_INGEST_PIPELINE';
    
    // Match Streamlit query exactly
    let query = `
      SELECT 
        TPA_CODE,
        TPA_NAME,
        TPA_DESCRIPTION
      FROM ${database}.BRONZE.TPA_MASTER
      WHERE 1=1
    `;
    
    if (active_only === 'true') {
      query += ` AND ACTIVE = TRUE`;
    }
    
    query += ` ORDER BY TPA_CODE`;
    
    const result = await snowflake.query(query);
    
    // Normalize column names to lowercase (matching Streamlit)
    const tpas = result.map(row => ({
      tpa_code: row.TPA_CODE || row.tpa_code,
      tpa_name: row.TPA_NAME || row.tpa_name,
      tpa_description: row.TPA_DESCRIPTION || row.tpa_description,
    }));
    
    res.json({
      tpas: tpas
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/tpas
 * Create new TPA
 */
router.post('/tpas', async (req, res, next) => {
  try {
    const { tpa_code, tpa_name, tpa_description } = req.body;
    
    if (!tpa_code || !tpa_name) {
      return res.status(400).json({ 
        error: 'TPA code and name are required' 
      });
    }
    
    const snowflake = getSnowflakeConnection();
    
    await snowflake.execute(`
      INSERT INTO bronze.tpa_master (tpa_code, tpa_name, tpa_description)
      VALUES (?, ?, ?)
    `, [tpa_code, tpa_name, tpa_description]);
    
    res.status(201).json({
      message: 'TPA created successfully',
      tpa_code: tpa_code
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/schemas
 * Get target schemas
 */
router.get('/schemas', async (req, res, next) => {
  try {
    const snowflake = getSnowflakeConnection();
    
    const schemas = await snowflake.query(`
      SELECT 
        schema_id,
        schema_name,
        schema_version,
        schema_definition,
        active,
        created_timestamp
      FROM silver.target_schemas
      WHERE active = TRUE
      ORDER BY schema_name
    `);
    
    res.json({
      schemas: schemas
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/stats
 * Get overall system statistics
 */
router.get('/stats', async (req, res, next) => {
  try {
    const snowflake = getSnowflakeConnection();
    
    // Bronze stats
    const bronzeStats = await snowflake.query(`
      SELECT 
        COUNT(*) as total_files,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_files,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_files,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_files
      FROM bronze.file_processing_queue
    `);
    
    const rawDataStats = await snowflake.query(`
      SELECT 
        COUNT(*) as total_records,
        COUNT(DISTINCT tpa) as total_tpas,
        COUNT(DISTINCT file_id) as total_files
      FROM bronze.raw_data_table
    `);
    
    // Silver stats
    const mappingStats = await snowflake.query(`
      SELECT 
        COUNT(*) as total_mappings,
        COUNT(DISTINCT tpa) as tpas_with_mappings,
        SUM(CASE WHEN active = TRUE THEN 1 ELSE 0 END) as active_mappings
      FROM silver.field_mappings
    `);
    
    const ruleStats = await snowflake.query(`
      SELECT 
        COUNT(*) as total_rules,
        SUM(CASE WHEN active = TRUE THEN 1 ELSE 0 END) as active_rules
      FROM silver.transformation_rules
    `);
    
    res.json({
      bronze: {
        files: bronzeStats[0],
        rawData: rawDataStats[0]
      },
      silver: {
        mappings: mappingStats[0],
        rules: ruleStats[0]
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
