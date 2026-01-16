"""
Snowflake File Processing Pipeline - File Upload Interface
===========================================================

A Streamlit in Snowflake (SiS) application for uploading CSV and Excel 
files to the Snowflake ingestion pipeline source stage.

Features:
- Upload single or multiple files
- Support for CSV and Excel (.xlsx, .xls) formats
- Real-time file validation
- Automatic upload to configured Snowflake stage
- View processing queue status
- Monitor uploaded files

Usage:
    Run directly in Snowflake as a Streamlit app
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.exceptions import SnowparkSQLException
import tempfile
import os
import time

# Page configuration
st.set_page_config(
    page_title="File Processing Pipeline",
    page_icon="📁",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Set up sidebar navigation FIRST (before any other sidebar content)
st.sidebar.title("📑 Navigation")
page = st.sidebar.radio(
    "Select a page:",
    [
        "📤 Upload Files",
        "📊 Processing Status",
        "📂 File Stages",
        "📋 Raw Data Viewer",
        "⚙️ Task Management"
    ],
    label_visibility="collapsed"
)
st.sidebar.markdown("---")

# Custom CSS
st.markdown("""
    <style>
    .main-header {
        font-size: 2.5rem;
        color: #1E88E5;
        font-weight: bold;
        margin-bottom: 1rem;
    }
    .success-box {
        padding: 1rem;
        border-radius: 0.5rem;
        background-color: #D4EDDA;
        border: 1px solid #C3E6CB;
        color: #155724;
        margin: 1rem 0;
    }
    .error-box {
        padding: 1rem;
        border-radius: 0.5rem;
        background-color: #F8D7DA;
        border: 1px solid #F5C6CB;
        color: #721C24;
        margin: 1rem 0;
    }
    .info-box {
        padding: 1rem;
        border-radius: 0.5rem;
        background-color: #D1ECF1;
        border: 1px solid #BEE5EB;
        color: #0C5460;
        margin: 1rem 0;
    }
    </style>
""", unsafe_allow_html=True)

# Get Snowflake session (Streamlit in Snowflake)
def get_snowflake_session():
    """Get active Snowflake session for Streamlit in Snowflake"""
    try:
        return get_active_session()
    except Exception as e:
        st.error(f"Error getting Snowflake session: {e}")
        return None

# Load configuration from Snowflake stage
@st.cache_data(ttl=300)
def load_config_from_stage(_session):
    """Load configuration from config file stored in Snowflake stage"""
    config = {
        'DATABASE_NAME': 'db_ingest_pipeline',
        'SCHEMA_NAME': 'BRONZE',
        'WAREHOUSE_NAME': 'COMPUTE_WH',
        'SRC_STAGE_NAME': 'SRC',
        'COMPLETED_STAGE_NAME': 'COMPLETED',
        'ERROR_STAGE_NAME': 'ERROR',
        'ARCHIVE_STAGE_NAME': 'ARCHIVE',
        'DISCOVER_TASK_NAME': 'discover_files_task',
        'PROCESS_TASK_NAME': 'process_files_task',
        'MOVE_SUCCESS_TASK_NAME': 'move_successful_files_task',
        'MOVE_FAILED_TASK_NAME': 'move_failed_files_task',
        'ARCHIVE_TASK_NAME': 'archive_old_files_task',
        'DISCOVER_TASK_SCHEDULE_MINUTES': '60'
    }
    
    try:
        # Try to read from config stage - try custom.config first, then default.config
        for config_file in ['custom.config', 'default.config']:
            try:
                # Get file from stage
                result = _session.sql(f"SELECT $1 FROM @CONFIG_STAGE/{config_file}").collect()
                
                # Parse config file
                for row in result:
                    line = row[0].strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip().strip('"').strip("'")
                        if key in config:
                            config[key] = value
                
                # If we found a config file, break
                st.sidebar.success(f"✓ Loaded config: {config_file}")
                break
            except:
                continue
        
    except Exception as e:
        st.sidebar.warning(f"⚠️ Using default configuration")
    
    return config

def validate_file(file):
    """Validate uploaded file"""
    valid_extensions = ['.csv', '.xlsx', '.xls']
    file_ext = os.path.splitext(file.name)[1].lower()
    
    if file_ext not in valid_extensions:
        return False, f"Invalid file type: {file_ext}. Supported types: {', '.join(valid_extensions)}"
    
    # Check file size (max 100MB)
    max_size = 100 * 1024 * 1024  # 100MB
    if file.size > max_size:
        return False, f"File too large: {file.size / (1024*1024):.2f}MB. Maximum: 100MB"
    
    return True, "Valid"

def upload_file_to_stage(session, file, stage_name, tpa_folder=None):
    """Upload file to Snowflake stage preserving original filename and optional TPA folder structure"""
    try:
        # Create temporary directory to preserve original filename
        temp_dir = tempfile.mkdtemp()
        temp_file_path = os.path.join(temp_dir, file.name)
        
        # Write file with original name
        with open(temp_file_path, 'wb') as tmp_file:
            tmp_file.write(file.getvalue())
        
        # Construct stage path with optional TPA subfolder
        if tpa_folder:
            stage_path = f"@{stage_name}/{tpa_folder}"
        else:
            stage_path = f"@{stage_name}"
        
        # Upload to stage (this will preserve the original filename)
        put_result = session.file.put(
            temp_file_path,
            stage_path,
            auto_compress=False,
            overwrite=True
        )
        
        # Clean up temporary file and directory
        os.unlink(temp_file_path)
        os.rmdir(temp_dir)
        
        # Check result
        if put_result and len(put_result) > 0:
            status = put_result[0].status
            if status == "UPLOADED" or status == "SKIPPED":
                return True, "Upload successful"
            else:
                return False, f"Upload failed: {status}"
        return False, "Upload failed: No result returned"
        
    except Exception as e:
        return False, f"Upload error: {str(e)}"

def get_processed_files_summary(session, database_name, schema_name):
    """Get summary of all processed files with status and TPA"""
    try:
        query = f"""
        SELECT 
            fpq.file_name,
            fpq.file_type,
            fpq.status,
            fpq.discovered_timestamp,
            fpq.processed_timestamp,
            fpq.process_result,
            fpq.error_message,
            COALESCE(rdt.tpa, 'N/A') as tpa
        FROM {database_name}.{schema_name}.file_processing_queue fpq
        LEFT JOIN (
            SELECT DISTINCT file_name, tpa
            FROM {database_name}.{schema_name}.RAW_DATA_TABLE
        ) rdt ON fpq.file_name = rdt.file_name
        ORDER BY fpq.discovered_timestamp DESC
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names: remove quotes and convert to lowercase
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error fetching processed files: {e}")
        return pd.DataFrame()

def get_processed_files_stats(session, database_name, schema_name):
    """Get statistics about processed files"""
    try:
        query = f"""
        SELECT 
            COUNT(*) as total_files,
            SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_files,
            SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_files,
            SUM(CASE WHEN status = 'PROCESSING' THEN 1 ELSE 0 END) as processing_files,
            SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending_files,
            SUM(CASE WHEN process_result LIKE '%rows%' THEN 
                TRY_CAST(REGEXP_SUBSTR(process_result, '[0-9]+') AS INTEGER) 
                ELSE 0 END) as total_rows_processed
        FROM {database_name}.{schema_name}.file_processing_queue
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names: remove quotes and convert to lowercase
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error fetching statistics: {e}")
        return pd.DataFrame()

def get_stage_files(session, stage_name):
    """Get list of files in stage"""
    try:
        query = f"LIST @{stage_name}"
        result = session.sql(query).to_pandas()
        # Normalize column names (remove quotes and convert to lowercase)
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        return result
    except Exception as e:
        st.error(f"Error listing stage: {e}")
        return pd.DataFrame()

def get_task_status(session, database_name, schema_name, task_name):
    """Get status of a specific task"""
    try:
        query = f"""
        SHOW TASKS LIKE '{task_name}' IN SCHEMA {database_name}.{schema_name}
        """
        result = session.sql(query).to_pandas()
        if not result.empty:
            return result.iloc[0]
        return None
    except Exception as e:
        st.error(f"Error getting task status: {e}")
        return None

def get_all_tasks_status(session, database_name, schema_name):
    """Get status of all tasks in the schema"""
    try:
        query = f"""
        SHOW TASKS IN SCHEMA {database_name}.{schema_name}
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names: remove quotes and convert to lowercase
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error getting tasks: {e}")
        return pd.DataFrame()

def execute_task(session, database_name, schema_name, task_name):
    """Execute a task immediately"""
    try:
        query = f"EXECUTE TASK {database_name}.{schema_name}.{task_name}"
        session.sql(query).collect()
        return True, "Task executed successfully"
    except Exception as e:
        return False, f"Error executing task: {str(e)}"

def resume_task(session, database_name, schema_name, task_name):
    """Resume a suspended task"""
    try:
        query = f"ALTER TASK {database_name}.{schema_name}.{task_name} RESUME"
        session.sql(query).collect()
        return True, "Task resumed successfully"
    except Exception as e:
        return False, f"Error resuming task: {str(e)}"

def suspend_task(session, database_name, schema_name, task_name):
    """Suspend a running task"""
    try:
        query = f"ALTER TASK {database_name}.{schema_name}.{task_name} SUSPEND"
        session.sql(query).collect()
        return True, "Task suspended successfully"
    except Exception as e:
        return False, f"Error suspending task: {str(e)}"

def get_task_history(session, database_name, schema_name, task_name, limit=10):
    """Get recent task execution history using ACCOUNT_USAGE (accessible from stored procedures)"""
    try:
        # INFORMATION_SCHEMA.TASK_HISTORY() is not accessible from stored procedures
        # Use SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY instead (has ~45 min latency but works in SiS)
        query = f"""
        SELECT 
            name,
            state,
            scheduled_time,
            completed_time,
            return_value,
            error_code,
            error_message
        FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
        WHERE database_name = '{database_name.upper()}'
          AND schema_name = '{schema_name.upper()}'
          AND name = '{task_name.upper()}'
          AND scheduled_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
        ORDER BY scheduled_time DESC
        LIMIT {limit}
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names: remove quotes and convert to lowercase
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.warning(f"Unable to load task history from local database: {str(e)}")
        return pd.DataFrame()

@st.cache_data(ttl=300)
def get_tpa_list(_session, database_name, schema_name):
    """Get list of active TPAs from TPA_MASTER table"""
    try:
        query = f"""
        SELECT 
            TPA_CODE,
            TPA_NAME,
            TPA_DESCRIPTION
        FROM {database_name}.{schema_name}.TPA_MASTER
        WHERE ACTIVE = TRUE
        ORDER BY TPA_CODE
        """
        result = _session.sql(query).to_pandas()
        
        # Normalize column names: remove quotes and convert to lowercase
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error loading TPA list: {e}")
        # Return empty dataframe if table doesn't exist yet
        return pd.DataFrame(columns=['tpa_code', 'tpa_name', 'tpa_description'])

def get_raw_data_summary(session, database_name, schema_name):
    """Get summary statistics of RAW_DATA_TABLE"""
    try:
        query = f"""
        SELECT 
            COUNT(*) as total_rows,
            COUNT(DISTINCT FILE_NAME) as unique_files,
            COUNT(DISTINCT TPA) as unique_tpas,
            MIN(LOAD_TIMESTAMP) as earliest_load,
            MAX(LOAD_TIMESTAMP) as latest_load
        FROM {database_name}.{schema_name}.RAW_DATA_TABLE
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error fetching raw data summary: {e}")
        return pd.DataFrame()

def get_raw_data_by_filters(session, database_name, schema_name, tpa_filter=None, file_filter=None, limit=100, offset=0):
    """Get raw data with filters and pagination"""
    try:
        where_clauses = []
        
        if tpa_filter:
            tpa_list = "', '".join(tpa_filter)
            where_clauses.append(f"TPA IN ('{tpa_list}')")
        
        if file_filter:
            file_list = "', '".join(file_filter)
            where_clauses.append(f"FILE_NAME IN ('{file_list}')")
        
        where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
        
        query = f"""
        SELECT 
            RAW_ID,
            FILE_NAME,
            TPA,
            FILE_ROW_NUMBER,
            RAW_DATA,
            LOAD_TIMESTAMP,
            FILE_SIZE,
            FILE_LAST_MODIFIED
        FROM {database_name}.{schema_name}.RAW_DATA_TABLE
        WHERE {where_clause}
        ORDER BY LOAD_TIMESTAMP DESC, RAW_ID DESC
        LIMIT {limit}
        OFFSET {offset}
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error fetching raw data: {e}")
        return pd.DataFrame()

def get_raw_data_files_and_tpas(session, database_name, schema_name):
    """Get distinct files and TPAs for filter options"""
    try:
        query = f"""
        SELECT DISTINCT
            FILE_NAME,
            TPA
        FROM {database_name}.{schema_name}.RAW_DATA_TABLE
        ORDER BY TPA, FILE_NAME
        """
        result = session.sql(query).to_pandas()
        
        # Normalize column names
        if not result.empty:
            result.columns = result.columns.str.strip('"').str.lower()
        
        return result
    except Exception as e:
        st.error(f"Error fetching files and TPAs: {e}")
        return pd.DataFrame()

def main():
    # Get Snowflake session
    session = get_snowflake_session()
    
    if not session:
        st.error("❌ Unable to connect to Snowflake session")
        st.stop()
    
    # Header
    st.markdown('<p class="main-header">📁 File Processing Pipeline</p>', unsafe_allow_html=True)
    st.markdown("Upload CSV and Excel files to the Snowflake ingestion pipeline")
    
    # Sidebar - Configuration
    with st.sidebar:
        st.header("⚙️ Configuration")
        
        # Load config from stage (default.config or custom.config)
        config = load_config_from_stage(session)
        
        # Display loaded configuration (read-only)
        st.subheader("Pipeline Configuration")
        database = config.get('DATABASE_NAME', 'db_ingest_pipeline')
        schema = config.get('SCHEMA_NAME', 'BRONZE')
        warehouse = config.get('WAREHOUSE_NAME', 'COMPUTE_WH')
        src_stage = config.get('SRC_STAGE_NAME', 'SRC')
        completed_stage = config.get('COMPLETED_STAGE_NAME', 'COMPLETED')
        error_stage = config.get('ERROR_STAGE_NAME', 'ERROR')
        
        st.text_input("Database", value=database, disabled=True, key="db_display")
        st.text_input("Schema", value=schema, disabled=True, key="schema_display")
        st.text_input("Warehouse", value=warehouse, disabled=True, key="wh_display")
        st.text_input("Source Stage", value=src_stage, disabled=True, key="src_display")
        
        # Store in session state
        st.session_state['database'] = database
        st.session_state['schema'] = schema
        st.session_state['warehouse'] = warehouse
        st.session_state['src_stage'] = src_stage
        
        st.divider()
        
        # Connection info
        st.subheader("🔌 Connection Status")
        st.success("✓ Connected to Snowflake")
        
        # Show current context
        with st.expander("View Session Info"):
            try:
                current_user = session.sql("SELECT CURRENT_USER()").collect()[0][0]
                current_role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]
                st.text(f"User: {current_user}")
                st.text(f"Role: {current_role}")
                st.text(f"Database: {database}")
                st.text(f"Schema: {schema}")
                st.text(f"Warehouse: {warehouse}")
            except Exception as e:
                st.error(f"Error getting session info: {e}")
    
    # Tab 1: Upload Files
    if page == "📤 Upload Files":
        st.subheader("Upload Files")
        
        # TPA Selection
        st.markdown("### 🏢 Select Third Party Administrator (TPA)")
        st.info("💡 The TPA determines the subfolder where files will be uploaded. This helps organize files by provider and enables TPA-specific processing rules.")
        
        # Load TPA list from database
        tpa_df = get_tpa_list(session, database, schema)
        
        if tpa_df.empty:
            st.error("❌ No TPAs found in database. Please contact your administrator to add TPAs to the TPA_MASTER table.")
            st.stop()
        
        # Create TPA options dictionary for display
        tpa_options_dict = {}
        for _, row in tpa_df.iterrows():
            tpa_code = row['tpa_code']
            tpa_name = row['tpa_name']
            tpa_options_dict[f"{tpa_code} - {tpa_name}"] = tpa_code
        
        col1, col2 = st.columns([3, 1])
        
        with col1:
            selected_tpa_display = st.selectbox(
                "Select TPA *",
                options=list(tpa_options_dict.keys()),
                help="Choose the Third Party Administrator for these files (required)"
            )
            
            # Get the TPA code from the selected display value
            tpa_folder = tpa_options_dict[selected_tpa_display]
        
        with col2:
            st.text_input("TPA Code", value=tpa_folder, disabled=True, help="Files will be uploaded to this subfolder")
        
        # Show TPA description if available
        selected_tpa_row = tpa_df[tpa_df['tpa_code'] == tpa_folder]
        if not selected_tpa_row.empty and pd.notna(selected_tpa_row.iloc[0]['tpa_description']):
            st.caption(f"ℹ️ {selected_tpa_row.iloc[0]['tpa_description']}")
        
        st.markdown("---")
        
        # Display target path
        st.markdown(f"**Target Path:** `@{database}.{schema}.{src_stage}/{tpa_folder}/`")
        
        # File uploader
        uploaded_files = st.file_uploader(
            "Choose CSV or Excel files",
            type=['csv', 'xlsx', 'xls'],
            accept_multiple_files=True,
            help="Select one or more CSV or Excel files to upload"
        )
        
        if uploaded_files:
            st.info(f"📎 {len(uploaded_files)} file(s) selected")
            
            # Show file details
            with st.expander("View file details", expanded=True):
                for file in uploaded_files:
                    col1, col2, col3 = st.columns([3, 2, 1])
                    with col1:
                        st.text(f"📄 {file.name}")
                    with col2:
                        st.text(f"Size: {file.size / 1024:.2f} KB")
                    with col3:
                        is_valid, msg = validate_file(file)
                        if is_valid:
                            st.success("✓")
                        else:
                            st.error("✗")
                            st.caption(msg)
            
            # Process files checkbox
            st.markdown("---")
            process_immediately = st.checkbox(
                "🚀 Process Files Immediately",
                value=True,
                help="Automatically trigger file discovery and processing after upload (recommended)"
            )
            
            if process_immediately:
                st.info("✓ Files will be processed immediately after upload")
            else:
                schedule_minutes = config.get('DISCOVER_TASK_SCHEDULE_MINUTES', '5')
                st.info(f"⏰ Files will be processed on next scheduled run (every {schedule_minutes} minutes)")
            
            # Upload button
            if st.button("🚀 Upload to Snowflake", type="primary", use_container_width=True):
                progress_bar = st.progress(0)
                status_placeholder = st.empty()
                
                success_count = 0
                failed_count = 0
                
                for idx, file in enumerate(uploaded_files):
                    # Validate file
                    is_valid, msg = validate_file(file)
                    if not is_valid:
                        status_placeholder.error(f"❌ {file.name}: {msg}")
                        failed_count += 1
                        continue
                    
                    # Upload file with TPA folder
                    status_placeholder.info(f"⏳ Uploading {file.name} to {tpa_folder}/...")
                    success, message = upload_file_to_stage(
                        session,
                        file,
                        f"{database}.{schema}.{src_stage}",
                        tpa_folder=tpa_folder
                    )
                    
                    if success:
                        status_placeholder.success(f"✅ {file.name}: {message} (TPA: {tpa_folder})")
                        success_count += 1
                    else:
                        status_placeholder.error(f"❌ {file.name}: {message}")
                        failed_count += 1
                    
                    # Update progress
                    progress_bar.progress((idx + 1) / len(uploaded_files))
                
                # Final summary
                st.divider()
                col1, col2, col3 = st.columns(3)
                with col1:
                    st.metric("Total Files", len(uploaded_files))
                with col2:
                    st.metric("Successful", success_count)
                with col3:
                    st.metric("Failed", failed_count)
                
                if success_count > 0:
                    st.success(f"🎉 Successfully uploaded {success_count} file(s)!")
                    
                    # Trigger immediate processing if checkbox is checked
                    if process_immediately:
                        st.markdown("---")
                        st.info("🔄 Triggering file discovery and processing...")
                        
                        try:
                            # Get discovery task name from config
                            discover_task = config.get('DISCOVER_TASK_NAME', 'discover_files_task')
                            
                            # Execute discovery task
                            status_placeholder.info(f"⏳ Executing {discover_task}...")
                            success, message = execute_task(session, database, schema, discover_task)
                            
                            if success:
                                status_placeholder.success(f"✅ Discovery task executed successfully!")
                                st.success("🎯 Files are now being discovered and will be processed shortly")
                                
                                # Show link to processing status
                                st.info("💡 **Next Steps:**\n"
                                       "- Go to the **📊 Processing Status** tab to monitor progress\n"
                                       "- Processing typically takes 1-2 minutes per file\n"
                                       "- Check **🚨 Error Files** tab if any files fail")
                            else:
                                status_placeholder.warning(f"⚠️ Could not execute discovery task: {message}")
                                schedule_minutes = config.get('DISCOVER_TASK_SCHEDULE_MINUTES', '5')
                                st.info(f"Files will be processed on next scheduled run (every {schedule_minutes} minutes)")
                        
                        except Exception as e:
                            st.error(f"❌ Error triggering discovery: {str(e)}")
                            schedule_minutes = config.get('DISCOVER_TASK_SCHEDULE_MINUTES', '5')
                            st.info(f"Files will be processed on next scheduled run (every {schedule_minutes} minutes)")
                    else:
                        schedule_minutes = config.get('DISCOVER_TASK_SCHEDULE_MINUTES', '5')
                        st.info(f"💡 Files will be automatically processed by the pipeline within {schedule_minutes} minutes.")
    
    # Tab 2: Processing Status
    if page == "📊 Processing Status":
        st.subheader("Processing Status")
        st.markdown("View all files that have been processed through the pipeline with their status and statistics.")
        
        # Manual refresh button
        if st.button("🔄 Refresh Now", key="refresh_now_top"):
            st.rerun()
        
        # Get statistics (this will refresh each time the tab is rendered)
        stats_df = get_processed_files_stats(session, database, schema)
        
        if not stats_df.empty:
            # Display summary metrics
            col1, col2, col3, col4, col5 = st.columns(5)
            
            # Safely extract values, handling NaN
            total = int(stats_df['total_files'].iloc[0]) if pd.notna(stats_df['total_files'].iloc[0]) else 0
            successful = int(stats_df['successful_files'].iloc[0]) if pd.notna(stats_df['successful_files'].iloc[0]) else 0
            failed = int(stats_df['failed_files'].iloc[0]) if pd.notna(stats_df['failed_files'].iloc[0]) else 0
            processing = int(stats_df['processing_files'].iloc[0]) if pd.notna(stats_df['processing_files'].iloc[0]) else 0
            pending = int(stats_df['pending_files'].iloc[0]) if pd.notna(stats_df['pending_files'].iloc[0]) else 0
            total_rows = int(stats_df['total_rows_processed'].iloc[0]) if pd.notna(stats_df['total_rows_processed'].iloc[0]) else 0
            
            with col1:
                st.metric("Total Files", total)
            with col2:
                st.metric("✅ Success", successful, delta=f"{(successful/total*100):.1f}%" if total > 0 else "0%")
            with col3:
                st.metric("❌ Failed", failed, delta=f"{(failed/total*100):.1f}%" if total > 0 else "0%", delta_color="inverse")
            with col4:
                st.metric("⏳ Processing", processing)
            with col5:
                st.metric("📊 Total Rows", f"{total_rows:,}")
        
        st.markdown("---")
        
        # Get all processed files first (needed for TPA filter options)
        files_df = get_processed_files_summary(session, database, schema)
        
        if not files_df.empty:
            # Filter options
            col1, col2, col3 = st.columns([2, 2, 2])
            
            with col1:
                status_filter = st.multiselect(
                    "Filter by Status",
                    options=["SUCCESS", "FAILED", "PROCESSING", "PENDING"],
                    default=["SUCCESS", "FAILED", "PROCESSING", "PENDING"]
                )
            
            with col2:
                file_type_filter = st.multiselect(
                    "Filter by File Type",
                    options=["CSV", "EXCEL"],
                    default=["CSV", "EXCEL"]
                )
            
            with col3:
                # Get unique TPAs from the data
                tpa_options = sorted(files_df['tpa'].unique().tolist())
                tpa_filter = st.multiselect(
                    "Filter by TPA",
                    options=tpa_options,
                    default=tpa_options
                )
            
            # Apply filters
            if status_filter:
                files_df = files_df[files_df['status'].isin(status_filter)]
            if file_type_filter:
                files_df = files_df[files_df['file_type'].isin(file_type_filter)]
            if tpa_filter:
                files_df = files_df[files_df['tpa'].isin(tpa_filter)]
            
            # Display count
            st.markdown(f"**Showing {len(files_df)} files**")
            
            # Display files table
            if len(files_df) > 0:
                # Format the dataframe for display
                display_df = files_df.copy()
                
                # Add status emoji
                status_emoji = {
                    'SUCCESS': '✅',
                    'FAILED': '❌',
                    'PROCESSING': '⏳',
                    'PENDING': '⏸️'
                }
                display_df['status'] = display_df['status'].apply(lambda x: f"{status_emoji.get(x, '')} {x}")
                
                # Format timestamps
                if 'discovered_timestamp' in display_df.columns:
                    display_df['discovered_timestamp'] = pd.to_datetime(display_df['discovered_timestamp']).dt.strftime('%Y-%m-%d %H:%M:%S')
                if 'processed_timestamp' in display_df.columns:
                    display_df['processed_timestamp'] = pd.to_datetime(display_df['processed_timestamp']).dt.strftime('%Y-%m-%d %H:%M:%S')
                
                # Rename columns for display
                display_df = display_df.rename(columns={
                    'file_name': 'File Name',
                    'file_type': 'Type',
                    'status': 'Status',
                    'tpa': 'TPA',
                    'discovered_timestamp': 'Discovered',
                    'processed_timestamp': 'Processed',
                    'process_result': 'Result',
                    'error_message': 'Error'
                })
                
                # Reorder columns to show TPA after Type
                column_order = ['File Name', 'Type', 'TPA', 'Status', 'Discovered', 'Processed', 'Result', 'Error']
                # Only include columns that exist in the dataframe
                column_order = [col for col in column_order if col in display_df.columns]
                display_df = display_df[column_order]
                
                # Display with expandable error messages
                st.dataframe(
                    display_df,
                    use_container_width=True,
                    hide_index=True,
                    column_config={
                        "Type": st.column_config.TextColumn(width="small"),
                        "TPA": st.column_config.TextColumn(width="small"),
                        "Status": st.column_config.TextColumn(width="small"),
                        "Result": st.column_config.TextColumn(width="medium"),
                        "Error": st.column_config.TextColumn(width="large")
                    }
                )
                
                # Download option
                csv = files_df.to_csv(index=False)
                st.download_button(
                    label="📥 Download as CSV",
                    data=csv,
                    file_name=f"processed_files_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.csv",
                    mime="text/csv"
                )
                
                # Reprocess failed files section
                failed_files = files_df[files_df['status'] == 'FAILED']
                if not failed_files.empty:
                    st.markdown("---")
                    st.markdown("### 🔄 Reprocess Failed Files")
                    st.markdown(f"Found **{len(failed_files)}** failed file(s) that can be reprocessed")
                    
                    # Select file to reprocess
                    failed_file_names = failed_files['file_name'].tolist()
                    
                    col1, col2 = st.columns([3, 1])
                    
                    with col1:
                        selected_failed_file = st.selectbox(
                            "Select file to reprocess:",
                            options=failed_file_names,
                            key="reprocess_failed_file_select"
                        )
                    
                    with col2:
                        st.markdown("<br>", unsafe_allow_html=True)  # Spacer for alignment
                        if st.button("🔄 Reprocess File", type="primary", use_container_width=True, key="reprocess_from_status"):
                            if selected_failed_file:
                                with st.spinner(f"Reprocessing {selected_failed_file}..."):
                                    try:
                                        # Call the reprocess procedure
                                        reprocess_query = f"""
                                            CALL {database}.{schema}.reprocess_error_file('{selected_failed_file}')
                                        """
                                        result = session.sql(reprocess_query).collect()
                                        
                                        if result and len(result) > 0:
                                            message = result[0][0]
                                            if "SUCCESS" in message:
                                                st.success(f"✅ {message}")
                                                
                                                # Trigger discovery if checkbox is checked
                                                if st.checkbox("🚀 Start Discovery Now", value=True, key="trigger_discovery_after_reprocess"):
                                                    try:
                                                        discover_task = config.get('DISCOVER_TASK_NAME', 'discover_files_task')
                                                        success, msg = execute_task(session, database, schema, discover_task)
                                                        if success:
                                                            st.success("✅ Discovery task executed - file will be reprocessed shortly")
                                                        else:
                                                            st.warning(f"⚠️ Could not execute discovery: {msg}")
                                                            st.info("File has been moved to source stage and will be picked up on next scheduled run")
                                                    except Exception as e:
                                                        st.warning(f"⚠️ Could not trigger discovery: {str(e)}")
                                                        st.info("File has been moved to source stage and will be picked up on next scheduled run")
                                                else:
                                                    schedule_minutes = config.get('DISCOVER_TASK_SCHEDULE_MINUTES', '5')
                                                    st.info(f"File will be processed on next scheduled run (every {schedule_minutes} minutes)")
                                                
                                                time.sleep(2)
                                                st.rerun()
                                            else:
                                                st.error(f"❌ {message}")
                                    except Exception as e:
                                        st.error(f"❌ Error reprocessing file: {str(e)}")
                    
                    # Batch reprocess option
                    st.markdown("---")
                    st.markdown("#### 🔄 Batch Reprocess All Failed Files")
                    st.warning(f"⚠️ This will reprocess all {len(failed_files)} failed file(s)")
                    
                    col1, col2 = st.columns([3, 1])
                    
                    with col1:
                        batch_trigger_discovery = st.checkbox(
                            "🚀 Start Discovery After Batch Reprocess",
                            value=True,
                            key="batch_trigger_discovery"
                        )
                    
                    with col2:
                        if st.button("🔄 Reprocess All", type="primary", use_container_width=True, key="batch_reprocess_from_status"):
                            with st.spinner(f"Reprocessing {len(failed_files)} files..."):
                                try:
                                    reprocess_all_query = f"""
                                        CALL {database}.{schema}.reprocess_all_error_files()
                                    """
                                    result = session.sql(reprocess_all_query).collect()
                                    
                                    if result and len(result) > 0:
                                        message = result[0][0]
                                        st.success(f"✅ {message}")
                                        
                                        # Trigger discovery if checkbox is checked
                                        if batch_trigger_discovery:
                                            try:
                                                discover_task = config.get('DISCOVER_TASK_NAME', 'discover_files_task')
                                                success, msg = execute_task(session, database, schema, discover_task)
                                                if success:
                                                    st.success("✅ Discovery task executed - files will be reprocessed shortly")
                                                else:
                                                    st.warning(f"⚠️ Could not execute discovery: {msg}")
                                            except Exception as e:
                                                st.warning(f"⚠️ Could not trigger discovery: {str(e)}")
                                        
                                        time.sleep(2)
                                        st.rerun()
                                except Exception as e:
                                    st.error(f"❌ Error reprocessing files: {str(e)}")
            else:
                st.info("No files match the selected filters")
        else:
            st.info("No processed files found")
    
    # Tab 4: Stage Files
    # Tab 3: Stage Files
    if page == "📂 File Stages":
        st.subheader("File Stages")
        
        # Stage selector
        col1, col2 = st.columns([3, 1])
        with col1:
            stage_options = {
                f"Source ({src_stage})": f"{database}.{schema}.{src_stage}",
                f"Completed ({config.get('COMPLETED_STAGE_NAME', 'COMPLETED')})": f"{database}.{schema}.{config.get('COMPLETED_STAGE_NAME', 'COMPLETED')}",
                f"Error ({config.get('ERROR_STAGE_NAME', 'ERROR')})": f"{database}.{schema}.{config.get('ERROR_STAGE_NAME', 'ERROR')}",
                f"Archive ({config.get('ARCHIVE_STAGE_NAME', 'ARCHIVE')})": f"{database}.{schema}.{config.get('ARCHIVE_STAGE_NAME', 'ARCHIVE')}"
            }
            selected_stage_label = st.selectbox("Select Stage", list(stage_options.keys()))
            selected_stage = stage_options[selected_stage_label]
        
        with col2:
            st.write("")  # Spacer
            st.write("")  # Spacer
            if st.button("🔄 Refresh", key="refresh_stage_files", use_container_width=True):
                st.rerun()
        
        if session:
            stage_df = get_stage_files(session, selected_stage)
            
            if not stage_df.empty:
                st.info(f"📂 {len(stage_df)} file(s) in {selected_stage_label}")
                
                # Display detailed table
                st.markdown("**File Details:**")
                st.dataframe(
                    stage_df,
                    use_container_width=True,
                    hide_index=True,
                    column_config={
                        "name": "File Path",
                        "size": st.column_config.NumberColumn(
                            "Size (bytes)",
                            format="%d"
                        ),
                        "md5": "MD5 Hash",
                        "last_modified": st.column_config.DatetimeColumn(
                            "Last Modified",
                            format="YYYY-MM-DD HH:mm:ss"
                        )
                    }
                )
            else:
                st.info(f"📭 No files in {selected_stage_label}")
    
    # Tab 4: Raw Data Viewer
    if page == "📋 Raw Data Viewer":
        st.subheader("Raw Data Viewer")
        st.markdown("View the contents of the RAW_DATA_TABLE with filtering and pagination.")
        
        # Get summary statistics
        summary_df = get_raw_data_summary(session, database, schema)
        
        if not summary_df.empty:
            # Display summary metrics
            col1, col2, col3, col4, col5 = st.columns(5)
            
            total_rows = int(summary_df['total_rows'].iloc[0]) if pd.notna(summary_df['total_rows'].iloc[0]) else 0
            unique_files = int(summary_df['unique_files'].iloc[0]) if pd.notna(summary_df['unique_files'].iloc[0]) else 0
            unique_tpas = int(summary_df['unique_tpas'].iloc[0]) if pd.notna(summary_df['unique_tpas'].iloc[0]) else 0
            
            with col1:
                st.metric("Total Rows", f"{total_rows:,}")
            with col2:
                st.metric("Unique Files", unique_files)
            with col3:
                st.metric("Unique TPAs", unique_tpas)
            with col4:
                if pd.notna(summary_df['earliest_load'].iloc[0]):
                    earliest = pd.to_datetime(summary_df['earliest_load'].iloc[0]).strftime('%Y-%m-%d')
                    st.metric("Earliest Load", earliest)
                else:
                    st.metric("Earliest Load", "N/A")
            with col5:
                if pd.notna(summary_df['latest_load'].iloc[0]):
                    latest = pd.to_datetime(summary_df['latest_load'].iloc[0]).strftime('%Y-%m-%d')
                    st.metric("Latest Load", latest)
                else:
                    st.metric("Latest Load", "N/A")
        
        st.markdown("---")
        
        # Get files and TPAs for filter options
        files_tpas_df = get_raw_data_files_and_tpas(session, database, schema)
        
        if not files_tpas_df.empty:
            # Filter options
            col1, col2, col3 = st.columns([2, 2, 1])
            
            with col1:
                # TPA filter - single select with "All TPAs" option
                tpa_options = sorted(files_tpas_df['tpa'].unique().tolist())
                tpa_options_with_all = ["All TPAs"] + tpa_options
                
                selected_tpa = st.selectbox(
                    "Filter by TPA",
                    options=tpa_options_with_all,
                    index=0,
                    help="Select a TPA to view data from that provider"
                )
                
                # Convert selection to filter list
                if selected_tpa == "All TPAs":
                    tpa_filter = None
                else:
                    tpa_filter = [selected_tpa]
            
            with col2:
                # File filter (only show files for selected TPA)
                if tpa_filter:
                    file_options = sorted(files_tpas_df[files_tpas_df['tpa'].isin(tpa_filter)]['file_name'].unique().tolist())
                else:
                    file_options = sorted(files_tpas_df['file_name'].unique().tolist())
                
                file_filter = st.multiselect(
                    "Filter by File",
                    options=file_options,
                    default=file_options[:3] if len(file_options) > 3 else file_options,
                    help="Select one or more files to view"
                )
            
            with col3:
                # Limit/pagination
                limit = st.selectbox(
                    "Rows per page",
                    options=[50, 100, 250, 500, 1000],
                    index=1,
                    help="Number of rows to display"
                )
            
            # Refresh button
            col1, col2 = st.columns([1, 5])
            with col1:
                if st.button("🔄 Refresh", use_container_width=True):
                    st.rerun()
            
            st.markdown("---")
            
            # Get raw data with filters
            raw_data_df = get_raw_data_by_filters(
                session, 
                database, 
                schema, 
                tpa_filter=tpa_filter if tpa_filter else None,
                file_filter=file_filter if file_filter else None,
                limit=limit,
                offset=0
            )
            
            if not raw_data_df.empty:
                st.markdown(f"**Showing {len(raw_data_df)} rows** (limited to {limit} per page)")
                
                # Format the dataframe for display
                display_df = raw_data_df.copy()
                
                # Format timestamps
                if 'load_timestamp' in display_df.columns:
                    display_df['load_timestamp'] = pd.to_datetime(display_df['load_timestamp']).dt.strftime('%Y-%m-%d %H:%M:%S')
                if 'file_last_modified' in display_df.columns:
                    display_df['file_last_modified'] = pd.to_datetime(display_df['file_last_modified']).dt.strftime('%Y-%m-%d %H:%M:%S')
                
                # Format file size
                if 'file_size' in display_df.columns:
                    display_df['file_size_kb'] = (display_df['file_size'] / 1024).round(2)
                
                # Convert RAW_DATA (VARIANT) to string for display
                if 'raw_data' in display_df.columns:
                    display_df['raw_data'] = display_df['raw_data'].astype(str)
                
                # Rename columns for display
                display_df = display_df.rename(columns={
                    'raw_id': 'ID',
                    'file_name': 'File Name',
                    'tpa': 'TPA',
                    'file_row_number': 'Row #',
                    'raw_data': 'Data (JSON)',
                    'load_timestamp': 'Loaded',
                    'file_size_kb': 'File Size (KB)',
                    'file_last_modified': 'File Modified'
                })
                
                # Select columns to display
                display_columns = ['ID', 'File Name', 'TPA', 'Row #', 'Data (JSON)', 'Loaded']
                if 'File Size (KB)' in display_df.columns:
                    display_columns.append('File Size (KB)')
                
                # Only include columns that exist
                display_columns = [col for col in display_columns if col in display_df.columns]
                display_df = display_df[display_columns]
                
                # Display data table
                st.dataframe(
                    display_df,
                    use_container_width=True,
                    hide_index=True,
                    column_config={
                        "ID": st.column_config.NumberColumn(width="small"),
                        "File Name": st.column_config.TextColumn(width="medium"),
                        "TPA": st.column_config.TextColumn(width="small"),
                        "Row #": st.column_config.NumberColumn(width="small"),
                        "Data (JSON)": st.column_config.TextColumn(width="large"),
                        "Loaded": st.column_config.TextColumn(width="medium"),
                        "File Size (KB)": st.column_config.NumberColumn(width="small", format="%.2f")
                    },
                    height=600
                )
                
                # Download option
                csv = raw_data_df.to_csv(index=False)
                st.download_button(
                    label="📥 Download as CSV",
                    data=csv,
                    file_name=f"raw_data_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.csv",
                    mime="text/csv"
                )
                
                # Show sample data expansion
                with st.expander("🔍 View Sample Row Details"):
                    if len(raw_data_df) > 0:
                        sample_row = raw_data_df.iloc[0]
                        st.json(sample_row.to_dict())
            else:
                st.info("No data found matching the selected filters")
        else:
            st.info("📭 No data in RAW_DATA_TABLE")
    
    # Tab 5: Task Management
    # Tab 4: Task Management
    if page == "⚙️ Task Management":
        st.subheader("Task Management & Control")
        
        if st.button("🔄 Refresh Task Status", use_container_width=True):
            st.rerun()
        
        if session:
            # Get task configuration
            config = load_config_from_stage(session)
            task_names = [
                config.get('DISCOVER_TASK_NAME', 'discover_files_task'),
                config.get('PROCESS_TASK_NAME', 'process_files_task'),
                config.get('MOVE_SUCCESS_TASK_NAME', 'move_successful_files_task'),
                config.get('MOVE_FAILED_TASK_NAME', 'move_failed_files_task'),
                'reprocess_error_files_task',
                'archive_old_files_task'
            ]
            
            # Tasks that can be executed manually (no dependencies or independent)
            executable_tasks = [
                config.get('DISCOVER_TASK_NAME', 'discover_files_task').upper(),
                'REPROCESS_ERROR_FILES_TASK',
                'ARCHIVE_OLD_FILES_TASK'
            ]
            
            # Get all tasks status
            tasks_df = get_all_tasks_status(session, database, schema)
            
            if not tasks_df.empty:
                # Debug: Show available columns if 'name' column is missing
                if 'name' not in tasks_df.columns:
                    st.error(f"⚠️ Unexpected column names in task data. Found columns: {list(tasks_df.columns)}")
                    st.info("Please report this issue. Expected 'name' column but found different columns.")
                    return
                
                # Filter to only our pipeline tasks (case-insensitive comparison)
                # Convert both task names to uppercase for comparison
                task_names_upper = [name.upper() for name in task_names]
                pipeline_tasks = tasks_df[tasks_df['name'].str.upper().isin(task_names_upper)]
                
                if not pipeline_tasks.empty:
                    st.markdown("### Pipeline Tasks Overview")
                    
                    # Display task cards
                    for idx, task_row in pipeline_tasks.iterrows():
                        task_name = task_row['name']
                        task_state = task_row['state']
                        
                        # Determine task order and icon (case-insensitive matching)
                        task_order = {
                            config.get('DISCOVER_TASK_NAME', 'discover_files_task').upper(): ('1️⃣', 'Discover Files', True),
                            config.get('PROCESS_TASK_NAME', 'process_files_task').upper(): ('2️⃣', 'Process Files', False),
                            config.get('MOVE_SUCCESS_TASK_NAME', 'move_successful_files_task').upper(): ('3️⃣', 'Move Successful', False),
                            config.get('MOVE_FAILED_TASK_NAME', 'move_failed_files_task').upper(): ('4️⃣', 'Move Failed', False),
                            'REPROCESS_ERROR_FILES_TASK': ('🔄', 'Reprocess Error Files', True),
                            'ARCHIVE_OLD_FILES_TASK': ('📦', 'Archive Old Files', True)
                        }
                        
                        icon, display_name, can_execute = task_order.get(task_name.upper(), ('⚙️', task_name, False))
                        
                        # Only expand the first task by default
                        is_expanded = (idx == 0)
                        
                        # Create expandable section for each task
                        with st.expander(f"{icon} **{display_name}** - Status: **{task_state}**", expanded=is_expanded):
                            col1, col2 = st.columns([3, 2])
                            
                            with col1:
                                # Compact display using columns
                                info_col1, info_col2 = st.columns(2)
                                with info_col1:
                                    st.text(f"Task Name: {task_name}")
                                    st.text(f"State: {task_state}")
                                with info_col2:
                                    st.text(f"Schedule: {task_row.get('schedule', 'N/A')}")
                                    st.text(f"Warehouse: {task_row.get('warehouse', 'N/A')}")
                                
                                # Show predecessor if exists
                                if 'predecessors' in task_row and task_row['predecessors']:
                                    st.text(f"Depends On: {task_row['predecessors']}")
                            
                            with col2:
                                st.markdown("**Actions:**")
                                
                                # Process Now button - only for executable tasks
                                if can_execute:
                                    if st.button(f"▶️ Execute Now", key=f"exec_{task_name}", use_container_width=True):
                                        with st.spinner(f"Executing {task_name}..."):
                                            success, message = execute_task(session, database, schema, task_name)
                                            if success:
                                                st.success(message)
                                                st.rerun()
                                            else:
                                                st.error(message)
                                else:
                                    st.info("⚠️ This task has dependencies and runs automatically after its predecessor completes.")
                                
                                # Resume/Suspend buttons
                                if task_state == 'suspended':
                                    if st.button(f"▶️ Resume", key=f"resume_{task_name}", use_container_width=True):
                                        with st.spinner(f"Resuming {task_name}..."):
                                            success, message = resume_task(session, database, schema, task_name)
                                            if success:
                                                st.success(message)
                                                st.rerun()
                                            else:
                                                st.error(message)
                                elif task_state == 'started':
                                    if st.button(f"⏸️ Suspend", key=f"suspend_{task_name}", use_container_width=True):
                                        with st.spinner(f"Suspending {task_name}..."):
                                            success, message = suspend_task(session, database, schema, task_name)
                                            if success:
                                                st.success(message)
                                                st.rerun()
                                            else:
                                                st.error(message)
                            
                            # Show recent task history (more compact)
                            st.markdown("---")
                            st.markdown("**Recent Executions (Last 24 hours):**")
                            st.caption("⏱️ Task history has up to 45 min latency")
                            
                            history_df = get_task_history(session, database, schema, task_name, limit=5)
                            
                            if not history_df.empty:
                                # Calculate runtime in seconds
                                display_df = history_df[['state', 'scheduled_time', 'completed_time', 'error_message']].copy()
                                
                                # Add runtime column (in seconds)
                                display_df['runtime_seconds'] = (
                                    pd.to_datetime(display_df['completed_time']) - 
                                    pd.to_datetime(display_df['scheduled_time'])
                                ).dt.total_seconds()
                                
                                # Show runtime statistics (compact)
                                valid_runtimes = display_df['runtime_seconds'].dropna()
                                if len(valid_runtimes) > 0:
                                    col1, col2, col3, col4 = st.columns(4)
                                    with col1:
                                        st.metric("Avg Runtime", f"{valid_runtimes.mean():.2f}s", label_visibility="visible")
                                    with col2:
                                        st.metric("Min Runtime", f"{valid_runtimes.min():.2f}s", label_visibility="visible")
                                    with col3:
                                        st.metric("Max Runtime", f"{valid_runtimes.max():.2f}s", label_visibility="visible")
                                    with col4:
                                        st.metric("Total Runs", len(valid_runtimes), label_visibility="visible")
                                
                                # Reorder columns to show runtime before error_message
                                display_df = display_df[['state', 'scheduled_time', 'completed_time', 'runtime_seconds', 'error_message']]
                                
                                st.dataframe(
                                    display_df,
                                    use_container_width=True,
                                    hide_index=True,
                                    height=200,  # Compact height
                                    column_config={
                                        "state": st.column_config.TextColumn(
                                            "Status",
                                            width="small"
                                        ),
                                        "scheduled_time": st.column_config.DatetimeColumn(
                                            "Scheduled",
                                            format="MM/DD HH:mm:ss",
                                            width="medium"
                                        ),
                                        "completed_time": st.column_config.DatetimeColumn(
                                            "Completed",
                                            format="MM/DD HH:mm:ss",
                                            width="medium"
                                        ),
                                        "runtime_seconds": st.column_config.NumberColumn(
                                            "Runtime (s)",
                                            format="%.2f",
                                            width="small"
                                        ),
                                        "error_message": st.column_config.TextColumn(
                                            "Error",
                                            width="medium"
                                        )
                                    }
                                )
                            else:
                                st.info("No execution history in the last 24 hours")
                    
                    # Bulk actions
                    st.markdown("---")
                    st.markdown("### Bulk Actions")
                    
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        if st.button("▶️ Resume All Tasks", type="secondary", use_container_width=True):
                            with st.spinner("Resuming all tasks..."):
                                success_count = 0
                                for task_name in task_names:
                                    success, _ = resume_task(session, database, schema, task_name)
                                    if success:
                                        success_count += 1
                                
                                if success_count == len(task_names):
                                    st.success(f"✓ All {success_count} tasks resumed")
                                else:
                                    st.warning(f"⚠️ {success_count}/{len(task_names)} tasks resumed")
                                st.rerun()
                    
                    with col2:
                        if st.button("⏸️ Suspend All Tasks", type="secondary", use_container_width=True):
                            with st.spinner("Suspending all tasks..."):
                                success_count = 0
                                for task_name in task_names:
                                    success, _ = suspend_task(session, database, schema, task_name)
                                    if success:
                                        success_count += 1
                                
                                if success_count == len(task_names):
                                    st.success(f"✓ All {success_count} tasks suspended")
                                else:
                                    st.warning(f"⚠️ {success_count}/{len(task_names)} tasks suspended")
                                st.rerun()
                    
                    with col3:
                        if st.button("🔄 Execute Discovery Now", type="primary", use_container_width=True):
                            with st.spinner("Executing discovery task..."):
                                discover_task = config.get('DISCOVER_TASK_NAME', 'discover_files_task')
                                success, message = execute_task(session, database, schema, discover_task)
                                if success:
                                    st.success("✓ Discovery task executed - files will be processed shortly")
                                    st.rerun()
                                else:
                                    st.error(message)
                    
                else:
                    st.warning("⚠️ No pipeline tasks found in schema")
            else:
                st.error("❌ Unable to retrieve task information")
    
    # Footer
    st.divider()
    st.caption("Snowflake File Processing Pipeline | Streamlit in Snowflake")

if __name__ == "__main__":
    main()


