const snowflake = require('snowflake-sdk');
const fs = require('fs');
const path = require('path');

/**
 * Snowflake Connection Manager
 * Supports both SPCS (session token) and standalone (credentials) modes
 */
class SnowflakeConnection {
  constructor() {
    this.connection = null;
    this.isSPCS = this.detectSPCS();
  }

  /**
   * Detect if running in Snowpark Container Services
   * SPCS provides a session token at /snowflake/session/token
   */
  detectSPCS() {
    const tokenPath = process.env.SPCS_TOKEN_PATH || '/snowflake/session/token';
    try {
      return fs.existsSync(tokenPath);
    } catch (error) {
      return false;
    }
  }

  /**
   * Get Snowflake connection configuration
   */
  getConnectionConfig() {
    if (this.isSPCS) {
      return this.getSPCSConfig();
    } else {
      return this.getStandaloneConfig();
    }
  }

  /**
   * Get SPCS configuration using session token
   */
  getSPCSConfig() {
    const tokenPath = process.env.SPCS_TOKEN_PATH || '/snowflake/session/token';
    
    try {
      const token = fs.readFileSync(tokenPath, 'utf8').trim();
      
      return {
        account: process.env.SNOWFLAKE_ACCOUNT,
        authenticator: 'OAUTH',
        token: token,
        warehouse: process.env.SNOWFLAKE_WAREHOUSE || 'COMPUTE_WH',
        database: process.env.SNOWFLAKE_DATABASE || 'DB_INGEST_PIPELINE',
        schema: process.env.SNOWFLAKE_SCHEMA || 'BRONZE',
        application: 'SnowflakePipelineApp-SPCS'
      };
    } catch (error) {
      console.error('Error reading SPCS token:', error);
      throw new Error('Failed to read SPCS session token');
    }
  }

  /**
   * Get standalone configuration using credentials
   */
  getStandaloneConfig() {
    return {
      account: process.env.SNOWFLAKE_ACCOUNT,
      username: process.env.SNOWFLAKE_USER,
      password: process.env.SNOWFLAKE_PASSWORD,
      warehouse: process.env.SNOWFLAKE_WAREHOUSE || 'COMPUTE_WH',
      database: process.env.SNOWFLAKE_DATABASE || 'DB_INGEST_PIPELINE',
      schema: process.env.SNOWFLAKE_SCHEMA || 'BRONZE',
      application: 'SnowflakePipelineApp-Standalone'
    };
  }

  /**
   * Connect to Snowflake
   */
  async connect() {
    return new Promise((resolve, reject) => {
      const config = this.getConnectionConfig();
      
      console.log(`Connecting to Snowflake (${this.isSPCS ? 'SPCS' : 'Standalone'} mode)...`);
      
      this.connection = snowflake.createConnection(config);
      
      this.connection.connect((err, conn) => {
        if (err) {
          console.error('Unable to connect to Snowflake:', err);
          reject(err);
        } else {
          console.log('Successfully connected to Snowflake');
          console.log(`Database: ${config.database}, Schema: ${config.schema}`);
          resolve(conn);
        }
      });
    });
  }

  /**
   * Execute a SQL query
   */
  async execute(sqlText, binds = []) {
    if (!this.connection) {
      await this.connect();
    }

    return new Promise((resolve, reject) => {
      this.connection.execute({
        sqlText: sqlText,
        binds: binds,
        complete: (err, stmt, rows) => {
          if (err) {
            console.error('Failed to execute statement:', err);
            reject(err);
          } else {
            resolve(rows);
          }
        }
      });
    });
  }

  /**
   * Execute a query and return results as JSON
   */
  async query(sqlText, binds = []) {
    const rows = await this.execute(sqlText, binds);
    return rows || [];
  }

  /**
   * Upload file to Snowflake stage
   */
  async uploadFile(localPath, stagePath) {
    if (!this.connection) {
      await this.connect();
    }

    return new Promise((resolve, reject) => {
      this.connection.execute({
        sqlText: `PUT file://${localPath} ${stagePath} AUTO_COMPRESS=FALSE OVERWRITE=TRUE`,
        complete: (err, stmt, rows) => {
          if (err) {
            console.error('Failed to upload file:', err);
            reject(err);
          } else {
            resolve(rows);
          }
        }
      });
    });
  }

  /**
   * Close connection
   */
  async disconnect() {
    if (this.connection) {
      return new Promise((resolve, reject) => {
        this.connection.destroy((err, conn) => {
          if (err) {
            console.error('Unable to disconnect:', err);
            reject(err);
          } else {
            console.log('Disconnected from Snowflake');
            this.connection = null;
            resolve();
          }
        });
      });
    }
  }

  /**
   * Health check
   */
  async healthCheck() {
    try {
      const result = await this.query('SELECT CURRENT_VERSION() as version');
      return {
        healthy: true,
        mode: this.isSPCS ? 'SPCS' : 'Standalone',
        version: result[0]?.VERSION
      };
    } catch (error) {
      return {
        healthy: false,
        mode: this.isSPCS ? 'SPCS' : 'Standalone',
        error: error.message
      };
    }
  }
}

// Singleton instance
let snowflakeInstance = null;

function getSnowflakeConnection() {
  if (!snowflakeInstance) {
    snowflakeInstance = new SnowflakeConnection();
  }
  return snowflakeInstance;
}

module.exports = {
  SnowflakeConnection,
  getSnowflakeConnection
};
