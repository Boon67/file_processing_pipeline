"""
Silver Layer Data Management Application
=========================================
Streamlit in Snowflake application for managing Silver layer transformations.
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# Get Snowpark session
session = get_active_session()

# ============================================
# PAGE CONFIGURATION
# ============================================

APP_TITLE = "Silver Transformation Manager"
APP_ICON = "🥈"

# Custom CSS for dark header and styling
st.markdown("""
    <style>
    /* Hide default Streamlit header */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    
    /* Sidebar styling */
    [data-testid="stSidebar"] {
        background-color: #f8fafc;
    }
    
    /* TPA selector styling */
    .stSelectbox {
        margin-top: 0 !important;
    }
    </style>
""", unsafe_allow_html=True)

# Get list of TPAs
@st.cache_data(ttl=300)
def get_tpa_list(_session):
    """Get list of active TPAs from TPA_MASTER table"""
    try:
        query = """
            SELECT TPA_CODE, TPA_NAME, TPA_DESCRIPTION
            FROM BRONZE.TPA_MASTER
            WHERE ACTIVE = TRUE
            ORDER BY TPA_CODE
        """
        result = _session.sql(query).collect()
        return [(row['TPA_CODE'], row['TPA_NAME']) for row in result]
    except Exception as e:
        st.error(f"Error loading TPAs: {e}")
        return []

tpa_list = get_tpa_list(session)

# Create header with TPA selector
col1, col2 = st.columns([3, 1])

with col1:
    if tpa_list:
        # Initialize session state for TPA if not exists
        if 'selected_tpa' not in st.session_state:
            st.session_state.selected_tpa = tpa_list[0][0]
        
        # TPA selector
        tpa_options = {f"{name}": code for code, name in tpa_list}
        selected_tpa_name = st.selectbox(
            "TPA",
            options=list(tpa_options.keys()),
            index=list(tpa_options.values()).index(st.session_state.selected_tpa) if st.session_state.selected_tpa in tpa_options.values() else 0,
            key="tpa_selector",
            label_visibility="collapsed"
        )
        st.session_state.selected_tpa = tpa_options[selected_tpa_name]
        st.session_state.selected_tpa_name = selected_tpa_name
    else:
        st.warning("⚠️ No TPAs found. Please configure TPAs in TPA_MASTER table.")
        st.session_state.selected_tpa = None
        st.session_state.selected_tpa_name = "No TPA"

with col2:
    st.markdown("""
        <div style="text-align: right; margin-top: 1rem;">
            <span style="color: #64748b; font-size: 0.875rem;">🥈 Silver Layer</span>
        </div>
    """, unsafe_allow_html=True)

st.markdown("---")

# Set up sidebar navigation
st.sidebar.title("📑 Navigation")
page = st.sidebar.radio(
    "Select a page:",
    [
        "📐 Target Table Designer",
        "🗺️ Field Mapper",
        "⚙️ Rules Engine",
        "📊 Transformation Monitor",
        "📋 Data Viewer",
        "📈 Data Quality Metrics",
        "🔧 Task Management"
    ],
    label_visibility="collapsed"
)
st.sidebar.markdown("---")

# ============================================
# CONFIGURATION
# ============================================

# Load configuration from Snowflake stage
@st.cache_data(ttl=300)
def load_config_from_stage(_session):
    """Load configuration from config file stored in Snowflake stage"""
    config = {
        'DATABASE_NAME': 'db_ingest_pipeline',
        'SCHEMA_NAME': 'BRONZE',
        'SILVER_SCHEMA_NAME': 'SILVER',
        'WAREHOUSE_NAME': 'COMPUTE_WH',
        'SILVER_STAGE_NAME': 'SILVER_STAGE',
        'SILVER_CONFIG_STAGE_NAME': 'SILVER_CONFIG',
        'SILVER_STREAMLIT_STAGE_NAME': 'SILVER_STREAMLIT',
        'DEFAULT_LLM_MODEL': 'SNOWFLAKE-ARCTIC',
        'DEFAULT_BATCH_SIZE': '10000',
        'SILVER_TRANSFORM_SCHEDULE_MINUTES': '15',
        'SILVER_STREAMLIT_APP_NAME': 'SILVER_DATA_MANAGER'
    }
    
    try:
        # Try to load from CONFIG_STAGE (uploaded during deployment)
        # First try custom.config, then fall back to default.config
        config_files = ['custom.config', 'default.config']
        
        for config_file in config_files:
            try:
                # Check if file exists in PUBLIC.CONFIG_STAGE
                result = _session.sql(f"""
                    SELECT $1 as line
                    FROM @{config['DATABASE_NAME']}.PUBLIC.CONFIG_STAGE/{config_file}
                    (FILE_FORMAT => (TYPE=CSV FIELD_DELIMITER=NONE RECORD_DELIMITER=NONE))
                """).collect()
                
                if result:
                    # Parse config file
                    for row in result:
                        line = row['LINE'].strip()
                        # Skip comments and empty lines
                        if line and not line.startswith('#') and '=' in line:
                            key, value = line.split('=', 1)
                            key = key.strip()
                            value = value.strip().strip('"').strip("'")
                            config[key] = value
                    
                    # Store config source for later display
                    config['_config_source'] = config_file
                    break
            except:
                continue
                
    except Exception as e:
        # If loading from stage fails, use defaults
        config['_config_source'] = 'default'
    
    return config

# Load configuration
config = load_config_from_stage(session)

# Display config info at bottom of sidebar
st.sidebar.markdown("---")
config_source = config.get('_config_source', 'default')
if config_source != 'default':
    st.sidebar.caption(f"✅ Config: {config_source}")
else:
    st.sidebar.caption("ℹ️ Using default config")

# Database Configuration
DATABASE_NAME = config.get('DATABASE_NAME', 'db_ingest_pipeline')
BRONZE_SCHEMA = config.get('SCHEMA_NAME', 'BRONZE')
SILVER_SCHEMA = config.get('SILVER_SCHEMA_NAME', 'SILVER')
WAREHOUSE_NAME = config.get('WAREHOUSE_NAME', 'COMPUTE_WH')

# Silver Layer Configuration
SILVER_STAGE_NAME = config.get('SILVER_STAGE_NAME', 'SILVER_STAGE')
SILVER_CONFIG_STAGE_NAME = config.get('SILVER_CONFIG_STAGE_NAME', 'SILVER_CONFIG')
SILVER_STREAMLIT_STAGE_NAME = config.get('SILVER_STREAMLIT_STAGE_NAME', 'SILVER_STREAMLIT')

# Build fully qualified names for easy reference
DB_SILVER = f"{DATABASE_NAME}.{SILVER_SCHEMA}"
DB_BRONZE = f"{DATABASE_NAME}.{BRONZE_SCHEMA}"

# LLM Configuration
DEFAULT_LLM_MODEL = config.get('DEFAULT_LLM_MODEL', 'SNOWFLAKE-ARCTIC')
DEFAULT_BATCH_SIZE = int(config.get('DEFAULT_BATCH_SIZE', '10000'))
SILVER_TRANSFORM_SCHEDULE_MINUTES = config.get('SILVER_TRANSFORM_SCHEDULE_MINUTES', '15')

DATA_TYPES = [
    "VARCHAR(20)", "VARCHAR(50)", "VARCHAR(100)", "VARCHAR(200)", 
    "VARCHAR(500)", "VARCHAR(1000)", "VARCHAR(5000)",
    "NUMBER(10,0)", "NUMBER(15,2)", "NUMBER(18,2)", "NUMBER(38,0)", 
    "FLOAT", "DOUBLE",
    "BOOLEAN", "DATE", 
    "TIMESTAMP_NTZ", "TIMESTAMP_LTZ", "TIMESTAMP_TZ",
    "VARIANT", "OBJECT", "ARRAY"
]

DEFAULT_VALUES = [
    "(None)",
    "CURRENT_TIMESTAMP()",
    "CURRENT_DATE()",
    "CURRENT_USER()",
    "0",
    "1",
    "TRUE",
    "FALSE",
    "''",
    "NULL"
]

RULE_TYPES = ["DATA_QUALITY", "BUSINESS_LOGIC", "STANDARDIZATION", "DEDUPLICATION"]
ERROR_ACTIONS = ["LOG", "REJECT", "QUARANTINE"]

# ============================================
# UTILITY FUNCTIONS
# ============================================

@st.cache_data(ttl=60)
def check_deployment_status(_session):
    """Check if Silver layer is fully deployed"""
    required_tables = [
        'target_schemas',
        'field_mappings',
        'transformation_rules',
        'silver_processing_log'
    ]
    
    missing_objects = []
    
    for table in required_tables:
        try:
            _session.sql(f"SELECT 1 FROM {DB_SILVER}.{table} LIMIT 1").collect()
        except:
            missing_objects.append(table)
    
    return {
        'is_deployed': len(missing_objects) == 0,
        'missing_objects': missing_objects
    }

def get_table_path(table_name, schema=None):
    """Get fully qualified table path"""
    schema = schema or SILVER_SCHEMA
    return f"{DATABASE_NAME}.{schema}.{table_name}"

def execute_query(query, show_error=True):
    """Execute a SQL query and return results as DataFrame"""
    try:
        result = session.sql(query).collect()
        if result:
            return pd.DataFrame([row.as_dict() for row in result])
        return pd.DataFrame()
    except Exception as e:
        if show_error:
            error_msg = str(e)
            if "does not exist or not authorized" in error_msg:
                st.warning("⚠️ Required database objects not found. Please ensure the Silver layer is fully deployed.")
            else:
                st.error(f"Query error: {error_msg}")
        return pd.DataFrame()


def execute_procedure(proc_call):
    """Execute a stored procedure and return result"""
    try:
        result = session.sql(proc_call).collect()
        if result and len(result) > 0:
            return str(list(result[0].as_dict().values())[0])
        return "Procedure executed successfully"
    except Exception as e:
        return f"Error: {str(e)}"


# ============================================
# APP CONFIGURATION
# ============================================

st.set_page_config(
    page_title=APP_TITLE,
    page_icon=APP_ICON,
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
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

# ============================================
# SIDEBAR - CONFIGURATION
# ============================================

with st.sidebar:
    st.header("⚙️ Configuration")
    
    # Display loaded configuration (read-only)
    st.subheader("Database Configuration")
    st.text_input("Database", value=DATABASE_NAME, disabled=True, key="db_display")
    st.text_input("Bronze Schema", value=BRONZE_SCHEMA, disabled=True, key="bronze_schema_display")
    st.text_input("Silver Schema", value=SILVER_SCHEMA, disabled=True, key="silver_schema_display")
    st.text_input("Warehouse", value=WAREHOUSE_NAME, disabled=True, key="wh_display")
    
    st.divider()
    
    st.subheader("Silver Layer Settings")
    st.text_input("Silver Stage", value=SILVER_STAGE_NAME, disabled=True, key="silver_stage_display")
    st.text_input("Config Stage", value=SILVER_CONFIG_STAGE_NAME, disabled=True, key="config_stage_display")
    st.text_input("Transform Schedule", value=f"{SILVER_TRANSFORM_SCHEDULE_MINUTES} min", disabled=True, key="schedule_display")
    
    st.divider()
    
    st.subheader("Processing Configuration")
    st.text_input("LLM Model", value=DEFAULT_LLM_MODEL, disabled=True, key="llm_display")
    st.text_input("Batch Size", value=f"{DEFAULT_BATCH_SIZE:,}", disabled=True, key="batch_display")
    
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
            st.text(f"Database: {DATABASE_NAME}")
            st.text(f"Bronze Schema: {BRONZE_SCHEMA}")
            st.text(f"Silver Schema: {SILVER_SCHEMA}")
            st.text(f"Warehouse: {WAREHOUSE_NAME}")
        except Exception as e:
            st.error(f"Error getting session info: {e}")

# ============================================
# MAIN CONTENT
# ============================================

st.markdown(f"## {APP_ICON} {APP_TITLE}")
st.markdown("Transform Bronze raw data into clean, standardized Silver tables")
st.markdown("---")

# ============================================
# DEPLOYMENT STATUS CHECK
# ============================================

# Check deployment status and show banner if not fully deployed
deployment_status = check_deployment_status(session)

if not deployment_status['is_deployed']:
    st.warning(f"""
    ⚠️ **Silver Layer Not Fully Deployed**
    
    The following database objects are missing:
    {', '.join([f'`{obj}`' for obj in deployment_status['missing_objects']])}
    
    **To complete deployment:**
    1. Run the Silver layer deployment script: `./deploy_silver.sh`
    2. Or run the full deployment: `./deploy.sh`
    3. Refresh this page once deployment is complete
    
    Some features may not work until deployment is complete.
    """)

# ============================================
# PAGE: TARGET TABLE DESIGNER
# ============================================

if page == "📐 Target Table Designer":
    st.markdown("### 📐 Target Table Designer")
    st.markdown("Define target tables for the Silver layer")
    
    # Add custom CSS for compact layout
    st.markdown("""
        <style>
        /* Reduce spacing in forms and columns */
        .stForm {
            padding: 0.5rem 0 !important;
        }
        div[data-testid="column"] {
            padding: 0.25rem !important;
        }
        /* Reduce input field heights */
        .stTextInput input, .stSelectbox select {
            font-size: 0.875rem !important;
            padding: 0.25rem 0.5rem !important;
            min-height: 2rem !important;
        }
        /* Reduce checkbox size */
        .stCheckbox {
            font-size: 0.875rem !important;
        }
        /* Reduce button padding */
        .stButton button {
            padding: 0.25rem 0.5rem !important;
            font-size: 0.875rem !important;
            min-height: 2rem !important;
        }
        /* Reduce text size in columns */
        div[data-testid="column"] p {
            font-size: 0.875rem !important;
            margin-bottom: 0.25rem !important;
        }
        /* Reduce header sizes */
        h4 {
            font-size: 1.1rem !important;
            margin-top: 0.5rem !important;
            margin-bottom: 0.5rem !important;
        }
        /* Reduce markdown spacing */
        .element-container {
            margin-bottom: 0.25rem !important;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Get table summary
    summary_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_target_schemas_summary ORDER BY table_name")
    
    # Two-column layout: Table selector on left, Details on right
    col_left, col_right = st.columns([1, 3])
    
    with col_left:
        st.markdown("### Tables")
        
        # New Table button
        if st.button("➕ New Table", use_container_width=True, type="primary"):
            st.session_state['selected_table'] = '__NEW__'
            st.rerun()
        
        st.markdown("---")
        
        # List existing tables
        if not summary_df.empty:
            table_list = summary_df["TABLE_NAME"].tolist()
            
            # Initialize selected table (but don't override __NEW__)
            current_table = st.session_state.get('selected_table')
            if 'selected_table' not in st.session_state or (current_table not in table_list and current_table != '__NEW__'):
                st.session_state['selected_table'] = table_list[0]
                current_table = table_list[0]
            
            # Only show radio buttons if not creating a new table
            if current_table != '__NEW__':
                # Get current selection index
                if current_table in table_list:
                    current_index = table_list.index(current_table)
                else:
                    current_index = 0
                
                # Radio button for table selection
                selected_table_name = st.radio(
                    "Select a table:",
                    options=table_list,
                    index=current_index,
                    key="table_radio",
                    label_visibility="collapsed"
                )
                
                # Update session state if selection changed
                if selected_table_name != st.session_state.get('selected_table'):
                    st.session_state['selected_table'] = selected_table_name
                    st.rerun()
            else:
                # Show message when creating new table
                st.info("Creating new table...")
        else:
            st.info("No tables yet. Click '➕ New Table' to create one.")
    
    with col_right:
        selected_table = st.session_state.get('selected_table')
        
        # Handle delete confirmation
        if not summary_df.empty:
            for table_name in summary_df["TABLE_NAME"].tolist():
                if st.session_state.get(f'confirm_delete_{table_name}'):
                    st.warning(f"⚠️ Delete table **{table_name}**?")
                    col1, col2 = st.columns(2)
                    with col1:
                        if st.button("✅ Yes, Delete", key=f"confirm_yes_{table_name}", type="primary", use_container_width=True):
                            result = execute_procedure(f"CALL {DB_SILVER}.drop_silver_table('{table_name}', TRUE)")
                            if "Error" in result:
                                st.error(result)
                            else:
                                st.success(result)
                                st.session_state.pop(f'confirm_delete_{table_name}', None)
                                st.session_state['selected_table'] = None
                                st.rerun()
                    with col2:
                        if st.button("❌ Cancel", key=f"confirm_no_{table_name}", use_container_width=True):
                            st.session_state.pop(f'confirm_delete_{table_name}', None)
                            st.rerun()
                    st.stop()
        
        # Show create new table form
        if selected_table == '__NEW__':
            st.markdown("### ➕ Create New Table")
            st.info("Enter a table name and add at least one column to create a new table definition.")
            
            with st.form("create_new_table_form", clear_on_submit=False):
                new_table_name = st.text_input("Table Name*", placeholder="e.g., CUSTOMERS, ORDERS")
                
                st.markdown("#### First Column")
                col1, col2 = st.columns(2)
                
                with col1:
                    first_column_name = st.text_input("Column Name*", placeholder="e.g., ID, NAME")
                    first_data_type = st.selectbox("Data Type*", DATA_TYPES)
                    first_nullable = st.checkbox("Nullable", value=True)
                
                with col2:
                    first_default_value = st.selectbox("Default Value", DEFAULT_VALUES, index=0)
                    first_description = st.text_area("Description", placeholder="Describe this column...")
                
                col_submit, col_cancel = st.columns(2)
                
                with col_submit:
                    submit_new_table = st.form_submit_button("Create Table", type="primary", use_container_width=True)
                
                with col_cancel:
                    cancel_new_table = st.form_submit_button("Cancel", use_container_width=True)
            
            # Handle form submission outside the form context
            if submit_new_table:
                if not new_table_name or not first_column_name:
                    st.error("❌ Table name and first column name are required")
                else:
                    try:
                        # Process default value
                        processed_default = None if first_default_value == "(None)" else first_default_value
                        
                        # Insert first column
                        insert_query = f"""
                            INSERT INTO {DB_SILVER}.target_schemas (
                                table_name, column_name, data_type, nullable,
                                default_value, description, active
                            )
                            VALUES (
                                '{new_table_name.upper()}',
                                '{first_column_name.upper()}',
                                '{first_data_type}',
                                {first_nullable},
                                {f"'{processed_default}'" if processed_default else 'NULL'},
                                {f"'{first_description}'" if first_description else 'NULL'},
                                TRUE
                            )
                        """
                        execute_query(insert_query)
                        
                        # Automatically add standard metadata columns
                        standard_columns = [
                            ("SOURCE_FILE_NAME", "VARCHAR(500)", "TRUE", "NULL", "Original source file name from Bronze layer"),
                            ("INGESTION_TIMESTAMP", "TIMESTAMP_NTZ", "FALSE", "CURRENT_TIMESTAMP()", "Timestamp when record was ingested"),
                            ("CREATED_AT", "TIMESTAMP_NTZ", "FALSE", "CURRENT_TIMESTAMP()", "Record creation timestamp in Silver layer"),
                            ("UPDATED_AT", "TIMESTAMP_NTZ", "FALSE", "CURRENT_TIMESTAMP()", "Record last update timestamp")
                        ]
                        
                        for col_name, data_type, nullable, default_val, description in standard_columns:
                            std_col_query = f"""
                                INSERT INTO {DB_SILVER}.target_schemas (
                                    table_name, column_name, data_type, nullable,
                                    default_value, description, active
                                )
                                VALUES (
                                    '{new_table_name.upper()}',
                                    '{col_name}',
                                    '{data_type}',
                                    {nullable},
                                    {f"'{default_val}'" if default_val != "NULL" else 'NULL'},
                                    '{description}',
                                    TRUE
                                )
                            """
                            execute_query(std_col_query)
                        
                        # Automatically create the physical table
                        with st.spinner(f"Creating {new_table_name.upper()} in database..."):
                            result = execute_procedure(f"CALL {DB_SILVER}.create_silver_table('{new_table_name.upper()}')")
                            if "Successfully" in result:
                                st.success(f"✅ Created table with standard metadata columns! {result}")
                            else:
                                st.warning(f"⚠️ Created table definition, but physical table creation had issues: {result}")
                        
                        st.session_state['selected_table'] = new_table_name.upper()
                        st.rerun()
                    except Exception as e:
                        st.error(f"❌ Error creating table: {str(e)}")
            
            if cancel_new_table:
                if not summary_df.empty:
                    st.session_state['selected_table'] = summary_df["TABLE_NAME"].iloc[0]
                else:
                    st.session_state.pop('selected_table', None)
                st.rerun()
        
        # Show selected table details
        elif selected_table and selected_table != '__NEW__':
            schema_df = execute_query(f"""
                SELECT schema_id, column_name, data_type, nullable, 
                       default_value, description
                FROM {DB_SILVER}.target_schemas
                WHERE table_name = '{selected_table}'
                  AND active = TRUE
                ORDER BY schema_id
            """)
            
            # Table name and delete button on same row
            col_title, col_delete = st.columns([4, 1])
            with col_title:
                st.markdown(f"### 📋 {selected_table}")
            with col_delete:
                if st.button("🗑️ Delete", type="secondary", key=f"delete_btn_{selected_table}"):
                    st.session_state[f'confirm_delete_{selected_table}'] = True
                    st.rerun()
            
            # Show columns using st.data_editor
            if not schema_df.empty:
                st.markdown("**Columns**")
                
                # Prepare dataframe for editing
                edit_df = schema_df.copy()
                
                # Drop the Nullable column as it's handled by default values
                edit_df = edit_df.drop(columns=['NULLABLE'])
                
                edit_df = edit_df.rename(columns={
                    'SCHEMA_ID': 'ID',
                    'COLUMN_NAME': 'Column Name',
                    'DATA_TYPE': 'Data Type',
                    'DEFAULT_VALUE': 'Default',
                    'DESCRIPTION': 'Description'
                })
                
                # Configure column settings - allow row deletion
                edited_df = st.data_editor(
                    edit_df,
                column_config={
                        "ID": st.column_config.NumberColumn("ID", disabled=True, width="small"),
                        "Column Name": st.column_config.TextColumn("Column Name", required=True, width="medium"),
                        "Data Type": st.column_config.SelectboxColumn("Data Type", options=DATA_TYPES, required=True, width="medium"),
                        "Default": st.column_config.SelectboxColumn("Default", options=DEFAULT_VALUES, width="medium"),
                        "Description": st.column_config.TextColumn("Description", width="large"),
                    },
                    hide_index=True,
                    num_rows="dynamic",  # Allow adding/deleting rows
                    use_container_width=True,
                    key=f"editor_{selected_table}"
                )
                
                st.markdown("**Actions:**")
                st.info("💡 Double-click to edit. Add rows for new columns. Delete rows to remove columns. Click 'Save Changes' to apply.")
                
                # Save button
                if st.button("💾 Save Changes", type="primary", use_container_width=True):
                    changes_made = False
                    deletions_made = False
                    additions_made = False
                    
                    # Check for deleted rows (rows in original but not in edited)
                    original_ids = set(edit_df['ID'].tolist())
                    edited_ids = set(edited_df['ID'].tolist())
                    deleted_ids = original_ids - edited_ids
                    
                    if deleted_ids:
                        for schema_id in deleted_ids:
                            delete_query = f"""
                                UPDATE {DB_SILVER}.target_schemas
                                SET active = FALSE,
                                    updated_timestamp = CURRENT_TIMESTAMP()
                                WHERE schema_id = {schema_id}
                            """
                            execute_query(delete_query)
                            deletions_made = True
                    
                    # Check for new rows (rows in edited but not in original)
                    new_ids = edited_ids - original_ids
                    
                    # Check for edited and new rows
                    for idx, row in edited_df.iterrows():
                        row_id = row['ID']
                        
                        # Check if this is a new row (ID not in original or ID is NaN)
                        if pd.isna(row_id) or row_id not in original_ids:
                            # This is a new row - insert it
                            if pd.notna(row.get('Column Name')) and row.get('Column Name'):
                                processed_default = None if row.get('Default') == "(None)" else row.get('Default')
                                
                                insert_query = f"""
                                    INSERT INTO {DB_SILVER}.target_schemas (
                                        table_name, column_name, data_type, nullable,
                                        default_value, description, active
                                    )
                                    VALUES (
                                        '{selected_table}',
                                        '{str(row["Column Name"]).upper()}',
                                        '{row.get("Data Type", "VARCHAR")}',
                                        TRUE,
                                        {f"'{processed_default}'" if processed_default else 'NULL'},
                                        {f"'{row.get('Description', '')}'" if row.get('Description') else 'NULL'},
                                        TRUE
                                    )
                                """
                                execute_query(insert_query)
                                additions_made = True
                        else:
                            # Find matching original row by ID
                            original_row = edit_df[edit_df['ID'] == row_id]
                            if not original_row.empty:
                                original_row = original_row.iloc[0]
                                # Compare only the editable columns individually
                                editable_cols = ['Column Name', 'Data Type', 'Default', 'Description']
                                
                                # Check if any column has changed
                                has_changes = False
                                for col in editable_cols:
                                    orig_val = original_row[col]
                                    new_val = row[col]
                                    # Handle NaN comparisons
                                    if pd.isna(orig_val) and pd.isna(new_val):
                                        continue
                                    if orig_val != new_val:
                                        has_changes = True
                                        break
                                
                                if has_changes:
                                    new_default = row['Default'] if row['Default'] != "(None)" else None
                                    
                                    update_query = f"""
                                        UPDATE {DB_SILVER}.target_schemas
                                        SET column_name = '{row["Column Name"].upper()}',
                                            data_type = '{row["Data Type"]}',
                                            nullable = TRUE,
                                            default_value = {f"'{new_default}'" if new_default else 'NULL'},
                                            description = {f"'{row['Description']}'" if row['Description'] else 'NULL'},
                                            updated_timestamp = CURRENT_TIMESTAMP()
                                        WHERE schema_id = {row_id}
                                    """
                                    execute_query(update_query)
                                    changes_made = True
                    
                    if changes_made or deletions_made or additions_made:
                        # Automatically sync the physical table with metadata
                        with st.spinner(f"Syncing {selected_table} with database..."):
                            result = execute_procedure(f"CALL {DB_SILVER}.sync_table_with_metadata('{selected_table}')")
                            if "Successfully" in result or "Recreated" in result:
                                st.success(f"✅ Changes saved and table synced! {result}")
                            else:
                                st.warning(f"⚠️ Changes saved to metadata, but table sync had issues: {result}")
                        st.rerun()
                    else:
                        st.info("No changes detected")
        
        else:
            st.info("👈 Select a table from the list or click '➕ New Table' to get started.")

# ============================================
# PAGE: FIELD MAPPER
# ============================================

if page == "🗺️ Field Mapper":
    st.markdown("### 🗺️ Field Mapper")
    st.markdown("Create Bronze → Silver field mappings")
    
    # Show RAW_DATA_TABLE row count
    try:
        raw_data_count_df = execute_query(f"SELECT COUNT(*) as row_count FROM {DB_BRONZE}.RAW_DATA_TABLE", show_error=False)
        if not raw_data_count_df.empty:
            row_count = raw_data_count_df['ROW_COUNT'].iloc[0]
            if row_count > 0:
                st.info(f"📊 **Source Data Available:** {row_count:,} rows in {DB_BRONZE}.RAW_DATA_TABLE")
            else:
                st.warning(f"⚠️ No data in {DB_BRONZE}.RAW_DATA_TABLE. Upload files via Bronze Ingestion Pipeline first.")
    except Exception as e:
        st.warning(f"⚠️ Unable to check source data: {str(e)}")
    
    # Show notification banner if mappings were just generated
    if st.session_state.get('mappings_just_generated', False):
        st.success("✅ Mappings generated successfully! Click the **📋 View Mappings** tab below to review and approve them.")
        st.session_state.mappings_just_generated = False
    
    tab1, tab2, tab3, tab4, tab5, tab6, tab7, tab8 = st.tabs([
        "📋 View Mappings",
        "📝 Manual Mapping",
        "🤖 ML Auto-Mapping",
        "🧠 LLM Mapping",
        "📚 Known Mappings",
        "💬 Prompt Templates",
        "🧪 Test Mappings",
        "📊 File Coverage"
    ])
    
    with tab1:
        st.subheader("Existing Field Mappings")
        
        # Get list of target tables for filtering
        target_tables_df = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name")
        target_tables = ["(All Tables)"] + (target_tables_df['TABLE_NAME'].tolist() if not target_tables_df.empty else [])
        
        # Filter and Sort controls
        col1, col2, col3 = st.columns([2, 2, 1])
        with col1:
            selected_filter_table = st.selectbox("Filter by Target Table:", options=target_tables, key="filter_table_mappings")
        with col2:
            sort_options = {
                "Target Table & Column": "target_table, target_column",
                "Source Field": "source_field",
                "Confidence (High to Low)": "confidence_score DESC",
                "Created (Newest First)": "created_timestamp DESC",
                "Created (Oldest First)": "created_timestamp ASC",
                "Mapping Method": "mapping_method"
            }
            selected_sort = st.selectbox("Sort by:", options=list(sort_options.keys()), key="sort_mappings")
        with col3:
            st.markdown("<br>", unsafe_allow_html=True)  # Spacer for alignment
        
        # Build query with optional table filter, TPA filter, and sorting
        sort_clause = sort_options[selected_sort]
        
        # Build WHERE clause
        where_clauses = []
        if selected_filter_table != "(All Tables)":
            where_clauses.append(f"target_table = '{selected_filter_table}'")
        if st.session_state.selected_tpa:
            where_clauses.append(f"tpa = '{st.session_state.selected_tpa}'")
        
        where_clause = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
        
        mappings_query = f"""
            SELECT mapping_id, source_table, source_field, target_table, target_column,
                   mapping_method, confidence_score, approved, approved_by, approved_timestamp,
                   transformation_logic, description, created_timestamp, tpa
                FROM {DB_SILVER}.field_mappings
                {where_clause}
            ORDER BY {sort_clause}
        """
        
        mappings_df = execute_query(mappings_query)
        
        if not mappings_df.empty:
            # Identify duplicates (same source_table + source_field + target_table + target_column combination)
            # This identifies true duplicates where the exact same mapping exists multiple times
            mappings_df['IS_DUPLICATE'] = mappings_df.duplicated(subset=['SOURCE_TABLE', 'SOURCE_FIELD', 'TARGET_TABLE', 'TARGET_COLUMN'], keep=False)
            
            # Store duplicate count before modifying dataframe
            duplicate_count = mappings_df['IS_DUPLICATE'].sum()
            
            # Add visual status indicators
            def get_status_indicator(row):
                if row['IS_DUPLICATE']:
                    return '🔴 DUPLICATE'
                elif not row['APPROVED']:
                    return '⚠️ PENDING'
                else:
                    return '✅ APPROVED'
            
            mappings_df['STATUS'] = mappings_df.apply(get_status_indicator, axis=1)
            
            # Reorder columns: STATUS, APPROVED, SOURCE_FIELD, TARGET_COLUMN first
            cols = ['STATUS', 'APPROVED', 'SOURCE_FIELD', 'TARGET_COLUMN', 'MAPPING_ID', 'SOURCE_TABLE', 'TARGET_TABLE',
                    'MAPPING_METHOD', 'CONFIDENCE_SCORE', 'APPROVED_BY', 'APPROVED_TIMESTAMP',
                    'TRANSFORMATION_LOGIC', 'DESCRIPTION', 'CREATED_TIMESTAMP']
            display_df = mappings_df[cols]
            
            # Show warnings
            if duplicate_count > 0:
                st.warning(f"⚠️ {duplicate_count} duplicate mappings detected (marked with 🔴 DUPLICATE). The exact same mapping exists multiple times.")
            
            unapproved_count = (~display_df['APPROVED']).sum()
            if unapproved_count > 0:
                st.warning(f"⚠️ {unapproved_count} mapping(s) pending approval (marked with ⚠️ PENDING)")
            
            st.info("💡 Select rows and delete them using the table controls. Click 'Save Changes' to apply deletions.")
            
            # Display editable dataframe with delete capability
            edited_df = st.data_editor(
                display_df,
                use_container_width=True,
                num_rows="dynamic",
                column_config={
                    "STATUS": st.column_config.TextColumn("Status", width="medium", disabled=True, help="⚠️ PENDING = Not approved, ✅ APPROVED = Ready to use, 🔴 DUPLICATE = Duplicate mapping"),
                    "MAPPING_ID": st.column_config.NumberColumn("ID", format="%d", disabled=True),
                    "SOURCE_TABLE": st.column_config.TextColumn("Source Table", disabled=True),
                    "SOURCE_FIELD": st.column_config.TextColumn("Source Field", disabled=True),
                    "TARGET_TABLE": st.column_config.TextColumn("Target Table", disabled=True),
                    "TARGET_COLUMN": st.column_config.TextColumn("Target Column", disabled=True),
                    "MAPPING_METHOD": st.column_config.TextColumn("Method", disabled=True),
                    "CONFIDENCE_SCORE": st.column_config.NumberColumn("Confidence", format="%.2f", disabled=True),
                    "APPROVED": st.column_config.CheckboxColumn("✓ Approved"),
                    "APPROVED_BY": st.column_config.TextColumn("Approved By", disabled=True),
                    "APPROVED_TIMESTAMP": st.column_config.DatetimeColumn("Approved At", disabled=True),
                    "TRANSFORMATION_LOGIC": st.column_config.TextColumn("Transformation"),
                    "DESCRIPTION": st.column_config.TextColumn("Description"),
                    "CREATED_TIMESTAMP": st.column_config.DatetimeColumn("Created", disabled=True)
                },
                hide_index=True,
                key="mappings_editor"
            )
            
            # Save changes button
            if st.button("💾 Save Changes", key="save_mappings_btn", type="primary"):
                changes_made = False
                
                # Detect deleted rows
                deleted_ids = set(display_df['MAPPING_ID']) - set(edited_df['MAPPING_ID'])
                if deleted_ids:
                    for mapping_id in deleted_ids:
                        delete_query = f"DELETE FROM {DB_SILVER}.field_mappings WHERE mapping_id = {mapping_id}"
                        execute_query(delete_query)
                    changes_made = True
                    st.success(f"✅ Deleted {len(deleted_ids)} mapping(s)")
                
                # Detect edited rows (for Approved, Transformation, Description)
                for idx in range(min(len(display_df), len(edited_df))):
                    if idx < len(display_df) and idx < len(edited_df):
                        original_row = display_df.iloc[idx]
                        edited_row = edited_df.iloc[idx]
                        mapping_id = edited_row['MAPPING_ID']
                        
                        # Check if editable fields changed
                        approved_changed = bool(edited_row.get('APPROVED', False)) != bool(original_row.get('APPROVED', False))
                        transformation_changed = str(edited_row.get('TRANSFORMATION_LOGIC', '')) != str(original_row.get('TRANSFORMATION_LOGIC', ''))
                        description_changed = str(edited_row.get('DESCRIPTION', '')) != str(original_row.get('DESCRIPTION', ''))
                        
                        if approved_changed or transformation_changed or description_changed:
                            # Properly escape single quotes in strings
                            import pandas as pd
                            transformation_logic = edited_row.get('TRANSFORMATION_LOGIC', '')
                            description = edited_row.get('DESCRIPTION', '')
                            
                            # Handle NaN/None values and escape single quotes
                            if pd.notna(transformation_logic) and str(transformation_logic).strip() and str(transformation_logic) != 'nan':
                                transformation_logic = str(transformation_logic).replace("'", "''")
                                transformation_logic_sql = f"'{transformation_logic}'"
                            else:
                                transformation_logic_sql = 'NULL'
                            
                            if pd.notna(description) and str(description).strip() and str(description) != 'nan':
                                description = str(description).replace("'", "''")
                                description_sql = f"'{description}'"
                            else:
                                description_sql = 'NULL'
                            
                            # Build update query with approval tracking
                            approved_value = edited_row.get('APPROVED', False)
                            if approved_changed and approved_value:
                                # User is approving this mapping - capture user and timestamp
                                # Get the actual logged-in user from Streamlit
                                try:
                                    current_user = st.user.user_name
                                except:
                                    current_user = 'UNKNOWN'
                                
                                update_query = f"""
                                    UPDATE {DB_SILVER}.field_mappings
                                    SET transformation_logic = {transformation_logic_sql},
                                        description = {description_sql},
                                        approved = TRUE,
                                        approved_by = '{current_user}',
                                        approved_timestamp = CURRENT_TIMESTAMP(),
                                        updated_timestamp = CURRENT_TIMESTAMP()
                                    WHERE mapping_id = {mapping_id}
                                """
                            elif approved_changed and not approved_value:
                                # User is un-approving this mapping - clear approval info
                                update_query = f"""
                                    UPDATE {DB_SILVER}.field_mappings
                                    SET transformation_logic = {transformation_logic_sql},
                                        description = {description_sql},
                                        approved = FALSE,
                                        approved_by = NULL,
                                        approved_timestamp = NULL,
                                        updated_timestamp = CURRENT_TIMESTAMP()
                                    WHERE mapping_id = {mapping_id}
                                """
                            else:
                                # Only transformation or description changed
                                update_query = f"""
                                    UPDATE {DB_SILVER}.field_mappings
                                    SET transformation_logic = {transformation_logic_sql},
                                        description = {description_sql},
                                        updated_timestamp = CURRENT_TIMESTAMP()
                                    WHERE mapping_id = {mapping_id}
                                """
                            
                            try:
                                execute_query(update_query)
                                changes_made = True
                            except Exception as e:
                                st.error(f"Error updating mapping {mapping_id}: {str(e)}")
                                st.code(update_query, language="sql")
                                raise
                
                if changes_made:
                    st.rerun()
                else:
                    st.info("No changes detected")
        else:
            st.info("No mappings created yet.")
    
    with tab2:
        st.subheader("Manual Field Mapping")
        
        # Get available source fields from Bronze RAW_DATA table
        st.info("💡 Source fields are extracted from the RAW_DATA column in BRONZE.RAW_DATA_TABLE")
        
        source_fields_df = execute_query(f"""
            SELECT DISTINCT key AS field_name
            FROM {DB_BRONZE}.RAW_DATA_TABLE,
            LATERAL FLATTEN(input => RAW_DATA)
            WHERE RAW_DATA IS NOT NULL
            ORDER BY key
            LIMIT 100
        """, show_error=False)
        
        source_fields = source_fields_df['FIELD_NAME'].tolist() if not source_fields_df.empty else []
        
        # Show data status
        if not source_fields:
            data_count_df = execute_query(f"SELECT COUNT(*) as cnt FROM {DB_BRONZE}.RAW_DATA_TABLE", show_error=False)
            data_count = data_count_df['CNT'].iloc[0] if not data_count_df.empty else 0
            
            if data_count == 0:
                st.warning(f"⚠️ No data in {DB_BRONZE}.RAW_DATA_TABLE. Upload files via Bronze Streamlit app first.")
            else:
                st.warning(f"⚠️ Found {data_count} records but no fields could be extracted. Records may have NULL RAW_DATA.")
        
        # Get available target tables
        target_tables_df = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name")
        target_tables = target_tables_df['TABLE_NAME'].tolist() if not target_tables_df.empty else []
        
        if not target_tables:
            st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
        
        with st.form("manual_mapping_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("**Source (Bronze)**")
                if source_fields:
                    source_field = st.selectbox("Source Field*", options=[""] + source_fields, key="manual_source_field")
                else:
                    st.warning("No source fields found in RAW_DATA_TABLE")
                    source_field = st.text_input("Source Field (manual entry)*")
                
                source_table = st.text_input("Source Table", value="RAW_DATA_TABLE", disabled=True)
            
            with col2:
                st.markdown("**Target (Silver)**")
                # Target table dropdown
                if target_tables:
                    target_table = st.selectbox("Target Table*", options=[""] + target_tables, key="manual_target_table")
                else:
                    target_table = st.text_input("Target Table* (manual entry)", key="manual_target_table_text")
                
                # Target column - manual entry since we can't dynamically load columns in a form
                target_column = st.text_input("Target Column* (manual entry)", key="manual_target_column_text", 
                                             help="Enter the target column name. You can view available columns in the Target Table Designer.")
            
            transformation = st.text_input(
                "Transformation Logic (optional)",
                help="SQL expression, e.g., UPPER(field), field::NUMBER"
            )
            description = st.text_area("Description")
            
            submitted = st.form_submit_button("Create Mapping")
            
            if submitted:
                if not source_field or not target_table or not target_column:
                    st.error("Source field, target table, and target column are required")
                else:
                    # Escape single quotes in string values
                    transformation_sql = f"'{transformation.replace(chr(39), chr(39)*2)}'" if transformation else 'NULL'
                    description_sql = f"'{description.replace(chr(39), chr(39)*2)}'" if description else 'NULL'
                    
                    insert_query = f"""
                        INSERT INTO {DB_SILVER}.field_mappings (
                            source_field, source_table, target_table, target_column,
                            mapping_method, confidence_score, transformation_logic,
                            description, approved
                        )
                        VALUES (
                            '{source_field.upper().replace(chr(39), chr(39)*2)}',
                            '{source_table.upper().replace(chr(39), chr(39)*2)}',
                            '{target_table.upper().replace(chr(39), chr(39)*2)}',
                            '{target_column.upper().replace(chr(39), chr(39)*2)}',
                            'MANUAL',
                            1.0,
                            {transformation_sql},
                            {description_sql},
                            TRUE
                        )
                    """
                    
                    execute_query(insert_query)
                    st.success(f"Created mapping: {source_field} → {target_table}.{target_column}")
                    st.rerun()
    
    with tab3:
        st.subheader("ML-Based Auto-Mapping")
        st.markdown("Use pattern matching algorithms to suggest field mappings")
        
        # Get available target tables
        target_tables_df_ml = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name")
        target_tables_ml = target_tables_df_ml['TABLE_NAME'].tolist() if not target_tables_df_ml.empty else []
        
        if not target_tables_ml:
            st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
        else:
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("**Source (Bronze)**")
                source_table_ml = st.text_input("Source Table", value="RAW_DATA_TABLE", key="ml_source", disabled=True)
            
            with col2:
                st.markdown("**Target (Silver)**")
                target_table_ml = st.selectbox("Target Table*", options=target_tables_ml, key="ml_target_table")
            
            col3, col4 = st.columns(2)
            with col3:
                top_n = st.number_input("Top N matches per field:", min_value=1, max_value=10, value=3)
            
            with col4:
                min_confidence = st.slider("Minimum confidence:", 0.0, 1.0, 0.6, 0.05)
            
            if st.button("Generate ML Mappings", key="generate_ml_btn"):
                with st.spinner(f"Analyzing fields and generating mappings for {target_table_ml}..."):
                    result = execute_procedure(
                        f"CALL {DB_SILVER}.auto_map_fields_ml('DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE', '{target_table_ml}', {top_n}, {min_confidence})"
                    )
                    st.info(result)
                    
                    if "Successfully" in result:
                        st.success(f"✅ ML mappings generated for {target_table_ml}!")
                        # Set flag to show notification banner
                        st.session_state.mappings_just_generated = True
                        st.rerun()
    
    with tab4:
        st.subheader("LLM-Assisted Mapping")
        st.markdown("Use Snowflake Cortex AI for semantic field mapping")
        
        # Get available target tables
        target_tables_df_llm = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name")
        target_tables_llm = target_tables_df_llm['TABLE_NAME'].tolist() if not target_tables_df_llm.empty else []
        
        # Get available prompt templates
        prompt_templates_df = execute_query(f"SELECT template_id FROM {DB_SILVER}.llm_prompt_templates WHERE active = TRUE ORDER BY template_id")
        available_prompts = prompt_templates_df['TEMPLATE_ID'].tolist() if not prompt_templates_df.empty else ["DEFAULT_FIELD_MAPPING"]
        
        if not target_tables_llm:
            st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
        else:
            models_df = execute_query(f"CALL {DB_SILVER}.get_available_cortex_models()")
            available_models = models_df.iloc[:, 0].tolist() if not models_df.empty else ["snowflake-arctic", "claude-3-5-sonnet", "llama3.1-70b"]
            
            # Ensure snowflake-arctic is in the list if not already
            if not any('arctic' in model.lower() for model in available_models):
                available_models.insert(0, "snowflake-arctic")
            
            # Find the index of snowflake-arctic for default selection
            default_model_index = 0
            for i, model in enumerate(available_models):
                if 'arctic' in model.lower():
                    default_model_index = i
                    break
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("**Source (Bronze)**")
                source_table_llm = st.text_input("Source Table", value="RAW_DATA_TABLE", key="llm_source", disabled=True)
                model_name = st.selectbox("LLM Model:", available_models, index=default_model_index, key="llm_model_select")
            
            with col2:
                st.markdown("**Target (Silver)**")
                target_table_llm = st.selectbox("Target Table*", options=target_tables_llm, key="llm_target_table")
                prompt_id = st.selectbox("Prompt Template:", options=available_prompts, key="llm_prompt")
            
            if st.button("Generate LLM Mappings", key="generate_llm_btn"):
                with st.spinner(f"Calling {model_name} for semantic mapping to {target_table_llm}..."):
                    result = execute_procedure(
                        f"CALL {DB_SILVER}.auto_map_fields_llm('DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE', '{target_table_llm}', '{model_name}', '{prompt_id}')"
                    )
                    st.info(result)
                    
                    if "Successfully" in result:
                        st.success(f"✅ LLM mappings generated for {target_table_llm}!")
                        # Set flag to show notification banner
                        st.session_state.mappings_just_generated = True
                        st.rerun()
    
    with tab5:
        st.subheader("Known Mappings Reference")
        st.markdown("Define known field mappings to help train the ML algorithm")
        
        # View existing known mappings
        known_mappings_df = execute_query(f"""
            SELECT mapping_id, source_field, target_field, description, active, created_timestamp
            FROM {DB_SILVER}.known_field_mappings
            ORDER BY created_timestamp DESC
        """, show_error=False)
        
        if not known_mappings_df.empty:
            st.markdown("### Existing Known Mappings")
            
            # Make the dataframe editable
            edited_df = st.data_editor(
                known_mappings_df,
                column_config={
                    "MAPPING_ID": st.column_config.NumberColumn("ID", disabled=True, width="small"),
                    "SOURCE_FIELD": st.column_config.TextColumn("Source Field", width="medium"),
                    "TARGET_FIELD": st.column_config.TextColumn("Target Field", width="medium"),
                    "DESCRIPTION": st.column_config.TextColumn("Description", width="large"),
                    "ACTIVE": st.column_config.CheckboxColumn("Active", width="small"),
                    "CREATED_TIMESTAMP": st.column_config.DatetimeColumn("Created", disabled=True, width="medium")
                },
                hide_index=True,
                num_rows="dynamic",
                use_container_width=True,
                key="known_mappings_editor"
            )
            
            # Save changes button
            if st.button("💾 Save Changes", key="save_known_mappings"):
                # Detect changes and update
                changes_made = False
                
                # Handle deleted rows
                original_ids = set(known_mappings_df['MAPPING_ID'].tolist())
                edited_ids = set(edited_df['MAPPING_ID'].tolist()) if 'MAPPING_ID' in edited_df.columns else set()
                deleted_ids = original_ids - edited_ids
                
                for mapping_id in deleted_ids:
                    execute_query(f"""
                        UPDATE {DB_SILVER}.known_field_mappings
                        SET active = FALSE
                        WHERE mapping_id = {mapping_id}
                    """)
                    changes_made = True
                
                # Handle edited rows
                for idx, row in edited_df.iterrows():
                    if 'MAPPING_ID' in row and pd.notna(row['MAPPING_ID']):
                        mapping_id = int(row['MAPPING_ID'])
                        if mapping_id in original_ids:
                            # Find original row
                            orig_row = known_mappings_df[known_mappings_df['MAPPING_ID'] == mapping_id].iloc[0]
                            
                            # Check if any editable fields changed
                            if (str(row.get('SOURCE_FIELD', '')) != str(orig_row.get('SOURCE_FIELD', '')) or
                                str(row.get('TARGET_FIELD', '')) != str(orig_row.get('TARGET_FIELD', '')) or
                                str(row.get('DESCRIPTION', '')) != str(orig_row.get('DESCRIPTION', '')) or
                                bool(row.get('ACTIVE', True)) != bool(orig_row.get('ACTIVE', True))):
                                
                                # Escape single quotes
                                source_field = str(row.get("SOURCE_FIELD", "")).upper().replace("'", "''")
                                target_field = str(row.get("TARGET_FIELD", "")).upper().replace("'", "''")
                                description = str(row.get('DESCRIPTION', '')).replace("'", "''") if pd.notna(row.get('DESCRIPTION')) else None
                                description_sql = f"'{description}'" if description else 'NULL'
                                
                                execute_query(f"""
                                    UPDATE {DB_SILVER}.known_field_mappings
                                    SET source_field = '{source_field}',
                                        target_field = '{target_field}',
                                        description = {description_sql},
                                        active = {bool(row.get('ACTIVE', True))}
                                    WHERE mapping_id = {mapping_id}
                                """)
                                changes_made = True
                
                # Handle new rows (rows without mapping_id or with NaN mapping_id)
                for idx, row in edited_df.iterrows():
                    if 'MAPPING_ID' not in row or pd.isna(row['MAPPING_ID']):
                        if pd.notna(row.get('SOURCE_FIELD')) and pd.notna(row.get('TARGET_FIELD')):
                            # Escape single quotes
                            source_field = str(row.get("SOURCE_FIELD", "")).upper().replace("'", "''")
                            target_field = str(row.get("TARGET_FIELD", "")).upper().replace("'", "''")
                            description = str(row.get('DESCRIPTION', '')).replace("'", "''") if pd.notna(row.get('DESCRIPTION')) else None
                            description_sql = f"'{description}'" if description else 'NULL'
                            
                            execute_query(f"""
                                INSERT INTO {DB_SILVER}.known_field_mappings
                                (source_field, target_field, description, active)
                                VALUES (
                                    '{source_field}',
                                    '{target_field}',
                                    {description_sql},
                                    TRUE
                                )
                            """)
                            changes_made = True
                
                if changes_made:
                    st.success("Known mappings updated successfully!")
                    st.rerun()
                else:
                    st.info("No changes detected")
        else:
            st.info("No known mappings defined yet. Add some below to help train the ML algorithm.")
        
        # Add new known mapping form
        st.markdown("---")
        st.markdown("### ➕ Add New Known Mapping")
        
        # Get available source fields from Bronze RAW_DATA table
        source_fields_known_df = execute_query(f"""
            SELECT DISTINCT key AS field_name
            FROM {DB_BRONZE}.RAW_DATA_TABLE,
            LATERAL FLATTEN(input => RAW_DATA)
            WHERE RAW_DATA IS NOT NULL
            ORDER BY key
            LIMIT 100
        """, show_error=False)
        
        source_fields_list = source_fields_known_df['FIELD_NAME'].tolist() if not source_fields_known_df.empty else []
        
        # Get all target column names from all defined tables
        target_fields_known_df = execute_query(f"""
            SELECT DISTINCT column_name
            FROM {DB_SILVER}.target_schemas
            WHERE active = TRUE
            ORDER BY column_name
        """)
        
        target_fields_list = target_fields_known_df['COLUMN_NAME'].tolist() if not target_fields_known_df.empty else []
        
        with st.form("add_known_mapping_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                if source_fields_list:
                    new_source = st.selectbox(
                        "Source Field*",
                        options=[""] + source_fields_list,
                        key="source_select_known",
                        help="Select from discovered fields or type to enter manually"
                    )
                else:
                    st.info("💡 No source fields found in RAW_DATA_TABLE")
                    new_source = st.text_input(
                        "Source Field*",
                        placeholder="Enter source field name",
                        key="source_manual_known"
                    )
            
            with col2:
                if target_fields_list:
                    new_target = st.selectbox(
                        "Target Field*",
                        options=[""] + target_fields_list,
                        key="target_select_known",
                        help="Select from defined columns or type to enter manually"
                    )
                else:
                    st.warning("⚠️ No target fields found. Define tables in Target Table Designer first.")
                    new_target = st.text_input(
                        "Target Field*",
                        placeholder="Enter target field name",
                        key="target_manual_known"
                    )
            
            new_description = st.text_area("Description", help="Describe the mapping relationship", key="description_known")
            
            submitted = st.form_submit_button("Add Known Mapping", type="primary")
            
            if submitted:
                if not new_source or not new_target:
                    st.error("Both source and target fields are required")
                else:
                    # Escape single quotes
                    source_escaped = new_source.upper().replace("'", "''")
                    target_escaped = new_target.upper().replace("'", "''")
                    description_sql = f"'{new_description.replace(chr(39), chr(39)*2)}'" if new_description else 'NULL'
                    
                    execute_query(f"""
                        INSERT INTO {DB_SILVER}.known_field_mappings
                        (source_field, target_field, description, active)
                        VALUES (
                            '{source_escaped}',
                            '{target_escaped}',
                            {description_sql},
                            TRUE
                        )
                    """)
                    st.success(f"Added known mapping: {new_source} → {new_target}")
                    st.rerun()
    
    with tab6:
        st.subheader("LLM Prompt Templates")
        st.markdown("Manage prompt templates for LLM-assisted field mapping")
        
        # View existing prompt templates
        prompts_df = execute_query(f"""
            SELECT template_id, template_name, template_text, description, active, created_timestamp
            FROM {DB_SILVER}.llm_prompt_templates
            ORDER BY template_id
        """)
        
        if not prompts_df.empty:
            st.markdown("### Existing Prompt Templates")
            
            # Select a prompt to edit
            prompt_options = prompts_df['TEMPLATE_ID'].tolist()
            selected_prompt_id = st.selectbox(
                "Select Prompt Template to Edit:",
                options=prompt_options,
                key="select_prompt_to_edit"
            )
            
            if selected_prompt_id:
                selected_prompt = prompts_df[prompts_df['TEMPLATE_ID'] == selected_prompt_id].iloc[0]
                
                st.markdown(f"#### Editing: {selected_prompt['TEMPLATE_NAME']}")
                
                with st.form(f"edit_prompt_{selected_prompt_id}"):
                    edit_name = st.text_input(
                        "Template Name*",
                        value=selected_prompt['TEMPLATE_NAME'],
                        key=f"edit_name_{selected_prompt_id}"
                    )
                    
                    edit_text = st.text_area(
                        "Prompt Template Text*",
                        value=selected_prompt['TEMPLATE_TEXT'],
                        height=300,
                        help="Use {source_fields} and {target_columns} as placeholders",
                        key=f"edit_text_{selected_prompt_id}"
                    )
                    
                    edit_description = st.text_area(
                        "Description",
                        value=selected_prompt['DESCRIPTION'] if pd.notna(selected_prompt['DESCRIPTION']) else "",
                        key=f"edit_desc_{selected_prompt_id}"
                    )
                    
                    edit_active = st.checkbox(
                        "Active",
                        value=bool(selected_prompt['ACTIVE']),
                        key=f"edit_active_{selected_prompt_id}"
                    )
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        update_submitted = st.form_submit_button("💾 Update Template", type="primary", use_container_width=True)
                    with col2:
                        delete_submitted = st.form_submit_button("🗑️ Delete Template", use_container_width=True)
                    
                    if update_submitted:
                        if not edit_name or not edit_text:
                            st.error("Template name and text are required")
                        else:
                            # Escape single quotes in the text
                            safe_text = edit_text.replace("'", "''")
                            safe_desc = edit_description.replace("'", "''") if edit_description else ""
                            safe_name = edit_name.replace("'", "''")
                            
                            execute_query(f"""
                                UPDATE {DB_SILVER}.llm_prompt_templates
                                SET template_name = '{safe_name}',
                                    template_text = '{safe_text}',
                                    description = {f"'{safe_desc}'" if edit_description else 'NULL'},
                                    active = {edit_active},
                                    updated_timestamp = CURRENT_TIMESTAMP()
                                WHERE template_id = '{selected_prompt_id}'
                            """)
                            st.success(f"Updated prompt template: {selected_prompt_id}")
                            st.rerun()
                    
                    if delete_submitted:
                        if selected_prompt_id == 'DEFAULT_FIELD_MAPPING':
                            st.error("Cannot delete the default template")
                        else:
                            execute_query(f"""
                                DELETE FROM {DB_SILVER}.llm_prompt_templates
                                WHERE template_id = '{selected_prompt_id}'
                            """)
                            st.success(f"Deleted prompt template: {selected_prompt_id}")
                            st.rerun()
        else:
            st.info("No prompt templates found")
        
        # Add new prompt template
        st.markdown("---")
        st.markdown("### ➕ Add New Prompt Template")
        
        with st.form("add_prompt_template_form"):
            new_template_id = st.text_input(
                "Template ID*",
                placeholder="e.g., CUSTOM_MAPPING_V1",
                help="Unique identifier for this template (uppercase, no spaces)"
            )
            
            new_template_name = st.text_input(
                "Template Name*",
                placeholder="e.g., Custom Field Mapping Prompt"
            )
            
            new_template_text = st.text_area(
                "Prompt Template Text*",
                height=300,
                placeholder="""You are a data mapping expert. Given these source fields: {source_fields}
And these target columns: {target_columns}
Suggest the best field mappings...""",
                help="Use {source_fields} and {target_columns} as placeholders that will be replaced with actual data"
            )
            
            new_template_desc = st.text_area(
                "Description",
                placeholder="Describe when to use this prompt template"
            )
            
            add_submitted = st.form_submit_button("Add Prompt Template", type="primary")
            
            if add_submitted:
                if not new_template_id or not new_template_name or not new_template_text:
                    st.error("Template ID, name, and text are required")
                else:
                    # Escape single quotes
                    safe_id = new_template_id.upper().replace(" ", "_").replace("'", "''")
                    safe_name = new_template_name.replace("'", "''")
                    safe_text = new_template_text.replace("'", "''")
                    safe_desc = new_template_desc.replace("'", "''") if new_template_desc else ""
                    
                    execute_query(f"""
                        INSERT INTO {DB_SILVER}.llm_prompt_templates
                        (template_id, template_name, template_text, description, active)
                        VALUES (
                            '{safe_id}',
                            '{safe_name}',
                            '{safe_text}',
                            {f"'{safe_desc}'" if new_template_desc else 'NULL'},
                            TRUE
                        )
                    """)
                    st.success(f"Added prompt template: {safe_id}")
                    st.rerun()
    
    with tab7:
        st.subheader("🧪 Test Field Mappings")
        st.markdown("Preview mapped data without storing results")
        
        # Get available target tables
        target_tables_test_df = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name")
        target_tables_test = target_tables_test_df['TABLE_NAME'].tolist() if not target_tables_test_df.empty else []
        
        if not target_tables_test:
            st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
        else:
            # Select target table to test
            selected_test_table = st.selectbox(
                "Select Target Table to Test:",
                options=target_tables_test,
                key="test_table_select"
            )
            
            if selected_test_table:
                # Get approved mappings for this table
                mappings_test_df = execute_query(f"""
                    SELECT source_field, source_table, target_column, transformation_logic
                    FROM {DB_SILVER}.field_mappings
                    WHERE target_table = '{selected_test_table}'
                      AND approved = TRUE
                    ORDER BY target_column
                """)
                
                if mappings_test_df.empty:
                    st.info(f"ℹ️ No approved mappings found for {selected_test_table}. Create and approve mappings first.")
                else:
                    st.markdown(f"### Approved Mappings for {selected_test_table}")
                    st.dataframe(
                        mappings_test_df,
                        column_config={
                            "SOURCE_FIELD": "Source Field",
                            "SOURCE_TABLE": "Source Table",
                            "TARGET_COLUMN": "Target Column",
                            "TRANSFORMATION_LOGIC": "Transformation"
                        },
                        use_container_width=True,
                        hide_index=True
                    )
                    
                    # Number of sample rows to preview
                    sample_rows = st.slider("Number of sample rows to preview:", min_value=1, max_value=100, value=10, key="test_sample_rows")
                    
                    if st.button("🧪 Test Mappings", type="primary", key="test_mappings_btn"):
                        with st.spinner(f"Testing mappings for {selected_test_table}..."):
                            try:
                                # Build SELECT statement dynamically based on mappings
                                select_clauses = []
                                for _, mapping in mappings_test_df.iterrows():
                                    source_field = mapping['SOURCE_FIELD']
                                    target_column = mapping['TARGET_COLUMN']
                                    transformation = mapping['TRANSFORMATION_LOGIC']
                                    
                                    if pd.notna(transformation) and transformation.strip():
                                        # Apply transformation
                                        select_clause = f"{transformation} AS {target_column}"
                                    else:
                                        # Direct mapping from RAW_DATA JSON
                                        select_clause = f"RAW_DATA:{source_field}::VARCHAR AS {target_column}"
                                    
                                    select_clauses.append(select_clause)
                                
                                # Build and execute test query
                                test_query = f"""
                                    SELECT 
                                        {', '.join(select_clauses)}
                                    FROM {DB_BRONZE}.RAW_DATA_TABLE
                                    WHERE RAW_DATA IS NOT NULL
                                    LIMIT {sample_rows}
                                """
                                
                                st.markdown("#### 📊 Test Query")
                                with st.expander("View SQL Query", expanded=False):
                                    st.code(test_query, language="sql")
                                
                                # Execute test query
                                test_results_df = execute_query(test_query)
                                
                                if not test_results_df.empty:
                                    st.markdown(f"#### ✅ Test Results ({len(test_results_df)} rows)")
                                    st.success(f"Successfully mapped {len(test_results_df)} rows with {len(mappings_test_df)} columns")
                                    
                                    # Show results
                                    st.dataframe(
                                        test_results_df,
                                        use_container_width=True,
                                        height=400
                                    )
                                    
                                    # Show data quality summary
                                    st.markdown("#### 📈 Data Quality Summary")
                                    col1, col2, col3 = st.columns(3)
                                    
                                    with col1:
                                        st.metric("Total Rows", len(test_results_df))
                                    
                                    with col2:
                                        # Count NULL values
                                        null_counts = test_results_df.isnull().sum()
                                        total_nulls = null_counts.sum()
                                        st.metric("Total NULLs", int(total_nulls))
                                    
                                    with col3:
                                        # Calculate completeness percentage
                                        total_cells = len(test_results_df) * len(test_results_df.columns)
                                        completeness = ((total_cells - total_nulls) / total_cells * 100) if total_cells > 0 else 0
                                        st.metric("Completeness", f"{completeness:.1f}%")
                                    
                                    # Show NULL counts per column
                                    if total_nulls > 0:
                                        st.markdown("##### NULL Values by Column")
                                        null_df = pd.DataFrame({
                                            'Column': null_counts.index,
                                            'NULL Count': null_counts.values,
                                            'NULL %': (null_counts.values / len(test_results_df) * 100).round(1)
                                        })
                                        null_df = null_df[null_df['NULL Count'] > 0].sort_values('NULL Count', ascending=False)
                                        if not null_df.empty:
                                            st.dataframe(null_df, use_container_width=True, hide_index=True)
                                    
                                    # Download option
                                    st.markdown("---")
                                    csv = test_results_df.to_csv(index=False)
                                    st.download_button(
                                        label="📥 Download Test Results as CSV",
                                        data=csv,
                                        file_name=f"{selected_test_table}_test_results.csv",
                                        mime="text/csv",
                                        key="download_test_results"
                                    )
                                else:
                                    st.warning("No data returned. Check if RAW_DATA_TABLE has data and mappings are correct.")
                                
                            except Exception as e:
                                st.error(f"Error testing mappings: {str(e)}")
                                st.markdown("**Troubleshooting Tips:**")
                                st.markdown("- Verify source fields exist in RAW_DATA column")
                                st.markdown("- Check transformation logic syntax")
                                st.markdown("- Ensure RAW_DATA_TABLE has data")
    
    with tab8:
        st.subheader("📊 Per-File Mapping Coverage")
        st.markdown("Analyze mapping coverage for each source file")
        
        # Get available target tables
        target_tables_coverage_df = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name")
        target_tables_coverage = target_tables_coverage_df['TABLE_NAME'].tolist() if not target_tables_coverage_df.empty else []
        
        if not target_tables_coverage:
            st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
        else:
            # Select target table
            selected_coverage_table = st.selectbox(
                "Select Target Table:",
                options=target_tables_coverage,
                key="coverage_table_select"
            )
            
            if selected_coverage_table:
                # Get per-file mapping coverage
                coverage_df = execute_query(f"""
                    SELECT 
                        file_name,
                        target_table,
                        total_source_columns,
                        mapped_columns,
                        unmapped_columns,
                        mapping_coverage_pct,
                        coverage_status
                    FROM {DB_SILVER}.v_file_mapping_coverage
                    WHERE target_table = '{selected_coverage_table}'
                    ORDER BY mapping_coverage_pct DESC, file_name
                """)
                
                if coverage_df.empty:
                    st.info(f"ℹ️ No source files found in Bronze layer. Upload and process files first.")
                else:
                    # Summary metrics
                    st.markdown("### 📈 Coverage Summary")
                    col1, col2, col3, col4 = st.columns(4)
                    
                    with col1:
                        st.metric("Total Files", len(coverage_df))
                    
                    with col2:
                        avg_coverage = coverage_df['MAPPING_COVERAGE_PCT'].mean()
                        st.metric("Avg Coverage", f"{avg_coverage:.1f}%")
                    
                    with col3:
                        good_files = len(coverage_df[coverage_df['MAPPING_COVERAGE_PCT'] >= 80])
                        st.metric("✅ Good (≥80%)", good_files)
                    
                    with col4:
                        poor_files = len(coverage_df[coverage_df['MAPPING_COVERAGE_PCT'] < 50])
                        st.metric("❌ Poor (<50%)", poor_files)
                    
                    # File-level coverage table
                    st.markdown("### 📋 File-Level Coverage Details")
                    st.dataframe(
                        coverage_df,
                        column_config={
                            "FILE_NAME": "Source File",
                            "TARGET_TABLE": "Target Table",
                            "TOTAL_SOURCE_COLUMNS": st.column_config.NumberColumn("Total Columns", format="%d"),
                            "MAPPED_COLUMNS": st.column_config.NumberColumn("Mapped", format="%d"),
                            "UNMAPPED_COLUMNS": st.column_config.NumberColumn("Unmapped", format="%d"),
                            "MAPPING_COVERAGE_PCT": st.column_config.ProgressColumn(
                                "Coverage %",
                                format="%.1f%%",
                                min_value=0,
                                max_value=100
                            ),
                            "COVERAGE_STATUS": "Status"
                        },
                        use_container_width=True,
                        hide_index=True,
                        height=400
                    )
                    
                    # Detailed view for selected file
                    st.markdown("---")
                    st.markdown("### 🔍 Detailed Column Analysis")
                    
                    selected_file = st.selectbox(
                        "Select file to analyze:",
                        options=coverage_df['FILE_NAME'].tolist(),
                        key="detailed_file_select"
                    )
                    
                    if selected_file:
                        # Get detailed column information
                        detail_df = execute_query(f"""
                            SELECT 
                                file_name,
                                target_table,
                                all_source_columns,
                                mapped_column_list,
                                target_column_list
                            FROM {DB_SILVER}.v_file_mapping_coverage
                            WHERE file_name = '{selected_file}'
                              AND target_table = '{selected_coverage_table}'
                        """)
                        
                        if not detail_df.empty:
                            all_cols = detail_df['ALL_SOURCE_COLUMNS'].iloc[0]
                            mapped_cols = detail_df['MAPPED_COLUMN_LIST'].iloc[0] if detail_df['MAPPED_COLUMN_LIST'].iloc[0] else []
                            target_cols = detail_df['TARGET_COLUMN_LIST'].iloc[0] if detail_df['TARGET_COLUMN_LIST'].iloc[0] else []
                            
                            # Create two columns for mapped vs unmapped
                            col1, col2 = st.columns(2)
                            
                            with col1:
                                st.markdown(f"#### ✅ Mapped Columns ({len(mapped_cols)})")
                                if mapped_cols:
                                    for i, (src_col, tgt_col) in enumerate(zip(mapped_cols, target_cols)):
                                        st.markdown(f"{i+1}. `{src_col}` → `{tgt_col}`")
                                else:
                                    st.info("No columns mapped yet")
                            
                            with col2:
                                st.markdown(f"#### ❌ Unmapped Columns ({len(all_cols) - len(mapped_cols)})")
                                unmapped = [col for col in all_cols if col not in mapped_cols]
                                if unmapped:
                                    for i, col in enumerate(unmapped):
                                        st.markdown(f"{i+1}. `{col}`")
                                else:
                                    st.success("All columns are mapped!")
                            
                            # Recommendations
                            if unmapped:
                                st.markdown("---")
                                st.markdown("### 💡 Recommendations")
                                st.info(f"""
                                **Next Steps to Improve Coverage:**
                                1. Review the {len(unmapped)} unmapped columns above
                                2. Use the **🧠 LLM Mapping** tab to auto-generate mappings
                                3. Or use **📝 Manual Mapping** to create custom mappings
                                4. Approve mappings in **📋 View Mappings** tab
                                """)

# ============================================
# PAGE: RULES ENGINE
# ============================================

if page == "⚙️ Rules Engine":
    st.markdown("### ⚙️ Rules Engine")
    st.markdown("Configure transformation rules for data quality and business logic")
    
    tab1, tab2, tab3, tab4 = st.tabs(["📋 View Rules", "➕ Add Rule", "✏️ Edit/Delete Rules", "🧪 Test Rules"])
    
    with tab1:
        st.subheader("Transformation Rules Summary")
        
        summary_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_rules_summary")
        if not summary_df.empty:
            st.dataframe(
                summary_df,
                use_container_width=True,
                column_config={
                    "RULE_TYPE": "Rule Type",
                    "ACTIVE": st.column_config.CheckboxColumn("Active"),
                    "RULE_COUNT": st.column_config.NumberColumn("Count", format="%d"),
                    "AFFECTED_TABLES": st.column_config.NumberColumn("Tables", format="%d"),
                    "AVG_PRIORITY": st.column_config.NumberColumn("Avg Priority", format="%.1f")
                }
            )
        
        st.markdown("---")
        st.subheader("All Transformation Rules")
        
        # Filter controls
        col1, col2, col3 = st.columns([2, 2, 1])
        with col1:
            filter_type = st.selectbox(
                "Filter by Rule Type:",
                options=["(All Types)"] + RULE_TYPES,
                key="filter_rule_type"
            )
        with col2:
            # Get distinct target tables safely
            tables_result = execute_query(f"""
                SELECT DISTINCT target_table 
                FROM {DB_SILVER}.transformation_rules 
                WHERE target_table IS NOT NULL 
                ORDER BY target_table
            """)
            available_filter_tables = tables_result['TARGET_TABLE'].tolist() if not tables_result.empty and 'TARGET_TABLE' in tables_result.columns else []
            
            filter_table = st.selectbox(
                "Filter by Target Table:",
                options=["(All Tables)"] + available_filter_tables,
                key="filter_rule_table"
            )
        with col3:
            filter_active = st.selectbox(
                "Status:",
                options=["All", "Active Only", "Inactive Only"],
                key="filter_rule_active"
            )
        
        # Build query with filters
        where_clauses = []
        if filter_type != "(All Types)":
            where_clauses.append(f"rule_type = '{filter_type}'")
        if filter_table != "(All Tables)":
            where_clauses.append(f"target_table = '{filter_table}'")
        if filter_active == "Active Only":
            where_clauses.append("active = TRUE")
        elif filter_active == "Inactive Only":
            where_clauses.append("active = FALSE")
        
        where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
        
        rules_df = execute_query(f"""
            SELECT rule_id, rule_name, rule_type, target_table, target_column,
                   rule_logic, priority, error_action, active, created_timestamp, description
            FROM {DB_SILVER}.transformation_rules
            WHERE {where_clause}
            ORDER BY priority, created_timestamp DESC
        """)
        
        if not rules_df.empty:
            st.dataframe(
                rules_df,
                use_container_width=True,
                column_config={
                    "RULE_ID": st.column_config.TextColumn("Rule ID", width="small"),
                    "RULE_NAME": st.column_config.TextColumn("Name", width="medium"),
                    "RULE_TYPE": st.column_config.TextColumn("Type", width="small"),
                    "TARGET_TABLE": st.column_config.TextColumn("Table", width="small"),
                    "TARGET_COLUMN": st.column_config.TextColumn("Column", width="small"),
                    "RULE_LOGIC": st.column_config.TextColumn("Logic", width="large"),
                    "PRIORITY": st.column_config.NumberColumn("Priority", format="%d", width="small"),
                    "ERROR_ACTION": st.column_config.TextColumn("Action", width="small"),
                    "ACTIVE": st.column_config.CheckboxColumn("Active", width="small"),
                    "CREATED_TIMESTAMP": st.column_config.DatetimeColumn("Created", width="medium"),
                    "DESCRIPTION": st.column_config.TextColumn("Description", width="large")
                }
            )
            
            st.markdown("---")
            st.markdown("### 📊 Rule Execution History")
            history_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_rule_execution_history LIMIT 20")
            if not history_df.empty:
                st.dataframe(
                    history_df,
                    use_container_width=True,
                    column_config={
                        "RULE_ID": "Rule ID",
                        "RULE_NAME": "Name",
                        "RULE_TYPE": "Type",
                        "EXECUTION_COUNT": st.column_config.NumberColumn("Executions", format="%d"),
                        "PASS_COUNT": st.column_config.NumberColumn("Pass", format="%d"),
                        "FAIL_COUNT": st.column_config.NumberColumn("Fail", format="%d"),
                        "WARNING_COUNT": st.column_config.NumberColumn("Warnings", format="%d"),
                        "AVG_METRIC_VALUE": st.column_config.NumberColumn("Avg Value", format="%.2f"),
                        "LAST_EXECUTION": st.column_config.DatetimeColumn("Last Run")
                    }
                )
            else:
                st.info("💡 No execution history yet. Rules will appear here after they are applied during transformations.")
        else:
            st.info("No rules match the current filters.")
    
    with tab2:
        st.subheader("Add New Transformation Rule")
        
        # Get available target tables and columns
        target_tables_df = execute_query(f"""
            SELECT DISTINCT table_name 
            FROM {DB_SILVER}.target_schemas 
            WHERE active = TRUE 
            ORDER BY table_name
        """)
        available_tables = [""] + (target_tables_df['TABLE_NAME'].tolist() if not target_tables_df.empty else [])
        
        # Rule templates/examples
        with st.expander("📚 Rule Examples & Templates", expanded=False):
            st.markdown("""
            **Data Quality Rules:**
            - `IS NOT NULL` - Ensure field is not null
            - `RLIKE '^[0-9]{10}$'` - Match 10-digit pattern
            - `>= 0` - Ensure non-negative values
            - `BETWEEN 0 AND 120` - Age range validation
            - `IN ('ACTIVE', 'INACTIVE', 'PENDING')` - Valid status codes
            
            **Business Logic Rules:**
            - `COALESCE(column1, column2, 'DEFAULT')` - Fallback values
            - `column1 * column2` - Calculate derived field
            - `CASE WHEN column1 > 100 THEN 'HIGH' ELSE 'LOW' END` - Conditional logic
            - `DATEDIFF(day, start_date, end_date)` - Date calculations
            
            **Standardization Rules:**
            - `UPPER` - Convert to uppercase
            - `TRIM` - Remove whitespace
            - `TO_DATE` - Parse date strings
            - `REGEXP_REPLACE(column, '[^0-9]', '')` - Extract numbers only
            
            **Deduplication Rules:**
            - `column1, column2` - Composite key for dedup
            - Use rule_parameters: `{"strategy": "KEEP_FIRST"}` or `KEEP_LAST` or `QUARANTINE_ALL`
            """)
        
        with st.form("add_rule_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                rule_id = st.text_input(
                    "Rule ID*",
                    help="Unique identifier (e.g., DQ001, BL001, STD001, DD001)",
                    placeholder="DQ001"
                )
                rule_name = st.text_input(
                    "Rule Name*",
                    placeholder="Validate Patient Age"
                )
                rule_type = st.selectbox(
                    "Rule Type*",
                    RULE_TYPES,
                    help="DATA_QUALITY=validation, BUSINESS_LOGIC=calculations, STANDARDIZATION=formatting, DEDUPLICATION=duplicates"
                )
                
                # Target table dropdown
                selected_table = st.selectbox(
                    "Target Table",
                    options=available_tables,
                    key="add_rule_target_table",
                    help="Leave blank for global rules"
                )
                
                # Target column dropdown (populated based on selected table)
                if selected_table:
                    columns_df = execute_query(f"""
                        SELECT column_name 
                        FROM {DB_SILVER}.target_schemas 
                        WHERE table_name = '{selected_table}' AND active = TRUE 
                        ORDER BY schema_id
                    """)
                    available_columns = [""] + (columns_df['COLUMN_NAME'].tolist() if not columns_df.empty else [])
                    target_column = st.selectbox(
                        "Target Column",
                        options=available_columns,
                        key="add_rule_target_column"
                    )
                else:
                    target_column = st.text_input(
                        "Target Column",
                        help="Leave blank for table-level rules",
                        key="add_rule_target_column_text"
                    )
            
            with col2:
                rule_logic = st.text_area(
                    "Rule Logic*",
                    help="SQL expression or condition (see examples above)",
                    placeholder="IS NOT NULL",
                    height=100
                )
                priority = st.number_input(
                    "Priority",
                    min_value=1,
                    max_value=1000,
                    value=100,
                    help="Lower numbers execute first"
                )
                error_action = st.selectbox(
                    "Error Action",
                    ERROR_ACTIONS,
                    help="LOG=record only, REJECT=delete records, QUARANTINE=move to quarantine table"
                )
                active = st.checkbox("Active", value=True)
            
            description = st.text_area(
                "Description",
                placeholder="Describe what this rule does and why it's needed",
                help="Optional but recommended for documentation"
            )
            
            rule_parameters = st.text_input(
                "Rule Parameters (JSON)",
                placeholder='{"strategy": "KEEP_FIRST"}',
                help="Optional JSON parameters for advanced rules (mainly for deduplication)"
            )
            
            submitted = st.form_submit_button("✅ Create Rule", type="primary")
            
            if submitted:
                if not rule_id or not rule_name or not rule_logic:
                    st.error("❌ Rule ID, name, and logic are required")
                else:
                    # Validate JSON parameters if provided
                    params_value = "NULL"
                    if rule_parameters:
                        try:
                            import json
                            json.loads(rule_parameters)
                            params_value = f"PARSE_JSON('{rule_parameters}')"
                        except:
                            st.error("❌ Invalid JSON in rule parameters")
                            st.stop()
                    
                    # Escape single quotes in strings
                    safe_rule_logic = rule_logic.replace("'", "''")
                    safe_rule_name = rule_name.replace("'", "''")
                    safe_description = description.replace("'", "''") if description else ""
                    
                    insert_query = f"""
                        INSERT INTO {DB_SILVER}.transformation_rules (
                            rule_id, rule_name, rule_type, target_table, target_column,
                            rule_logic, rule_parameters, priority, error_action, description, active
                        )
                        VALUES (
                            '{rule_id.upper()}',
                            '{safe_rule_name}',
                            '{rule_type}',
                            {f"'{selected_table.upper()}'" if selected_table else 'NULL'},
                            {f"'{target_column.upper()}'" if target_column else 'NULL'},
                            '{safe_rule_logic}',
                            {params_value},
                            {priority},
                            '{error_action}',
                            {f"'{safe_description}'" if description else 'NULL'},
                            {active}
                        )
                    """
                    
                    try:
                        execute_query(insert_query)
                        st.success(f"✅ Created rule: {rule_id}")
                        st.rerun()
                    except Exception as e:
                        st.error(f"❌ Error creating rule: {str(e)}")
    
    with tab3:
        st.subheader("Edit or Delete Transformation Rules")
        
        # Get all rules
        all_rules_df = execute_query(f"""
            SELECT rule_id, rule_name, rule_type, target_table, target_column,
                   rule_logic, rule_parameters, priority, error_action, description, active
            FROM {DB_SILVER}.transformation_rules
            ORDER BY rule_id
        """)
        
        if not all_rules_df.empty:
            rule_ids = all_rules_df['RULE_ID'].tolist()
            selected_rule_id = st.selectbox(
                "Select Rule to Edit/Delete:",
                options=rule_ids,
                key="edit_rule_select"
            )
            
            if selected_rule_id:
                rule_data = all_rules_df[all_rules_df['RULE_ID'] == selected_rule_id].iloc[0]
                
                st.markdown(f"#### Editing Rule: `{selected_rule_id}`")
                
                # Get available target tables for dropdowns
                target_tables_df = execute_query(f"""
                    SELECT DISTINCT table_name 
                    FROM {DB_SILVER}.target_schemas 
                    WHERE active = TRUE 
                    ORDER BY table_name
                """)
                available_tables = [""] + (target_tables_df['TABLE_NAME'].tolist() if not target_tables_df.empty else [])
                
                with st.form(f"edit_rule_form_{selected_rule_id}"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        edit_rule_name = st.text_input(
                            "Rule Name*",
                            value=rule_data['RULE_NAME'],
                            key=f"edit_name_{selected_rule_id}"
                        )
                        edit_rule_type = st.selectbox(
                            "Rule Type*",
                            RULE_TYPES,
                            index=RULE_TYPES.index(rule_data['RULE_TYPE']) if rule_data['RULE_TYPE'] in RULE_TYPES else 0,
                            key=f"edit_type_{selected_rule_id}"
                        )
                        
                        # Target table dropdown
                        current_table = rule_data['TARGET_TABLE'] if pd.notna(rule_data['TARGET_TABLE']) else ""
                        table_index = available_tables.index(current_table) if current_table in available_tables else 0
                        edit_target_table = st.selectbox(
                            "Target Table",
                            options=available_tables,
                            index=table_index,
                            key=f"edit_table_{selected_rule_id}"
                        )
                        
                        # Target column dropdown
                        if edit_target_table:
                            columns_df = execute_query(f"""
                                SELECT column_name 
                                FROM {DB_SILVER}.target_schemas 
                                WHERE table_name = '{edit_target_table}' AND active = TRUE 
                                ORDER BY schema_id
                            """)
                            available_columns = [""] + (columns_df['COLUMN_NAME'].tolist() if not columns_df.empty else [])
                            current_column = rule_data['TARGET_COLUMN'] if pd.notna(rule_data['TARGET_COLUMN']) else ""
                            column_index = available_columns.index(current_column) if current_column in available_columns else 0
                            edit_target_column = st.selectbox(
                                "Target Column",
                                options=available_columns,
                                index=column_index,
                                key=f"edit_column_{selected_rule_id}"
                            )
                        else:
                            edit_target_column = st.text_input(
                                "Target Column",
                                value=rule_data['TARGET_COLUMN'] if pd.notna(rule_data['TARGET_COLUMN']) else "",
                                key=f"edit_column_text_{selected_rule_id}"
                            )
                    
                    with col2:
                        edit_rule_logic = st.text_area(
                            "Rule Logic*",
                            value=rule_data['RULE_LOGIC'],
                            height=100,
                            key=f"edit_logic_{selected_rule_id}"
                        )
                        edit_priority = st.number_input(
                            "Priority",
                            min_value=1,
                            max_value=1000,
                            value=int(rule_data['PRIORITY']),
                            key=f"edit_priority_{selected_rule_id}"
                        )
                        edit_error_action = st.selectbox(
                            "Error Action",
                            ERROR_ACTIONS,
                            index=ERROR_ACTIONS.index(rule_data['ERROR_ACTION']) if rule_data['ERROR_ACTION'] in ERROR_ACTIONS else 0,
                            key=f"edit_action_{selected_rule_id}"
                        )
                        edit_active = st.checkbox(
                            "Active",
                            value=bool(rule_data['ACTIVE']),
                            key=f"edit_active_{selected_rule_id}"
                        )
                    
                    edit_description = st.text_area(
                        "Description",
                        value=rule_data['DESCRIPTION'] if pd.notna(rule_data['DESCRIPTION']) else "",
                        key=f"edit_desc_{selected_rule_id}"
                    )
                    
                    edit_rule_parameters = st.text_input(
                        "Rule Parameters (JSON)",
                        value=str(rule_data['RULE_PARAMETERS']) if pd.notna(rule_data['RULE_PARAMETERS']) else "",
                        key=f"edit_params_{selected_rule_id}"
                    )
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        update_submitted = st.form_submit_button("💾 Update Rule", type="primary", use_container_width=True)
                    with col2:
                        delete_submitted = st.form_submit_button("🗑️ Delete Rule", use_container_width=True)
                    
                    if update_submitted:
                        if not edit_rule_name or not edit_rule_logic:
                            st.error("❌ Rule name and logic are required")
                        else:
                            # Validate JSON parameters if provided
                            params_value = "NULL"
                            if edit_rule_parameters and edit_rule_parameters != "None":
                                try:
                                    import json
                                    json.loads(edit_rule_parameters)
                                    params_value = f"PARSE_JSON('{edit_rule_parameters}')"
                                except:
                                    st.error("❌ Invalid JSON in rule parameters")
                                    st.stop()
                            
                            # Escape single quotes
                            safe_rule_logic = edit_rule_logic.replace("'", "''")
                            safe_rule_name = edit_rule_name.replace("'", "''")
                            safe_description = edit_description.replace("'", "''") if edit_description else ""
                            
                            update_query = f"""
                                UPDATE {DB_SILVER}.transformation_rules
                                SET rule_name = '{safe_rule_name}',
                                    rule_type = '{edit_rule_type}',
                                    target_table = {f"'{edit_target_table.upper()}'" if edit_target_table else 'NULL'},
                                    target_column = {f"'{edit_target_column.upper()}'" if edit_target_column else 'NULL'},
                                    rule_logic = '{safe_rule_logic}',
                                    rule_parameters = {params_value},
                                    priority = {edit_priority},
                                    error_action = '{edit_error_action}',
                                    description = {f"'{safe_description}'" if edit_description else 'NULL'},
                                    active = {edit_active},
                                    updated_timestamp = CURRENT_TIMESTAMP()
                                WHERE rule_id = '{selected_rule_id}'
                            """
                            
                            try:
                                execute_query(update_query)
                                st.success(f"✅ Updated rule: {selected_rule_id}")
                                st.rerun()
                            except Exception as e:
                                st.error(f"❌ Error updating rule: {str(e)}")
                    
                    if delete_submitted:
                        try:
                            delete_query = f"DELETE FROM {DB_SILVER}.transformation_rules WHERE rule_id = '{selected_rule_id}'"
                            execute_query(delete_query)
                            st.success(f"✅ Deleted rule: {selected_rule_id}")
                            st.rerun()
                        except Exception as e:
                            st.error(f"❌ Error deleting rule: {str(e)}")
        else:
            st.info("No rules defined yet. Create rules in the 'Add Rule' tab.")
    
    with tab4:
        st.subheader("Test Transformation Rules")
        st.markdown("Test how rules will affect your data without actually applying them")
        
        # Get available target tables
        test_tables_df = execute_query(f"""
            SELECT DISTINCT table_name 
            FROM {DB_SILVER}.target_schemas 
            WHERE active = TRUE 
            ORDER BY table_name
        """)
        test_tables = test_tables_df['TABLE_NAME'].tolist() if not test_tables_df.empty else []
        
        if not test_tables:
            st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
        else:
            col1, col2 = st.columns(2)
            
            with col1:
                test_target_table = st.selectbox(
                    "Target Table*",
                    options=test_tables,
                    key="test_rules_table"
                )
            
            with col2:
                test_sample_size = st.number_input(
                    "Sample Size",
                    min_value=10,
                    max_value=1000,
                    value=100,
                    help="Number of records to test",
                    key="test_rules_sample"
                )
            
            # Get rules for this table
            if test_target_table:
                rules_for_table_df = execute_query(f"""
                    SELECT rule_id, rule_name, rule_type, target_column, rule_logic, error_action, active
                    FROM {DB_SILVER}.transformation_rules
                    WHERE (target_table = '{test_target_table}' OR target_table IS NULL)
                      AND active = TRUE
                    ORDER BY priority
                """)
                
                if not rules_for_table_df.empty:
                    st.markdown(f"### 📋 Active Rules for `{test_target_table}`")
                    st.dataframe(
                        rules_for_table_df,
                        use_container_width=True,
                        column_config={
                            "RULE_ID": "ID",
                            "RULE_NAME": "Name",
                            "RULE_TYPE": "Type",
                            "TARGET_COLUMN": "Column",
                            "RULE_LOGIC": "Logic",
                            "ERROR_ACTION": "Action",
                            "ACTIVE": st.column_config.CheckboxColumn("Active")
                        }
                    )
                    
                    st.markdown("---")
                    
                    if st.button("🧪 Run Rule Test", type="primary"):
                        with st.spinner("Testing rules on sample data..."):
                            try:
                                # Get sample data from Bronze
                                test_query = f"""
                                    SELECT * FROM {DB_BRONZE}.RAW_DATA_TABLE
                                    LIMIT {test_sample_size}
                                """
                                sample_data = execute_query(test_query)
                                
                                if not sample_data.empty:
                                    st.success(f"✅ Retrieved {len(sample_data)} sample records")
                                    
                                    # Show rule impact summary
                                    st.markdown("### 📊 Rule Impact Summary")
                                    
                                    impact_data = []
                                    for _, rule in rules_for_table_df.iterrows():
                                        impact_data.append({
                                            "Rule ID": rule['RULE_ID'],
                                            "Rule Name": rule['RULE_NAME'],
                                            "Type": rule['RULE_TYPE'],
                                            "Action": rule['ERROR_ACTION'],
                                            "Status": "✅ Ready to Apply"
                                        })
                                    
                                    impact_df = pd.DataFrame(impact_data)
                                    st.dataframe(impact_df, use_container_width=True)
                                    
                                    st.info("""
                                    💡 **Test Mode**: This is a simulation. To actually apply rules:
                                    1. Go to **Transformation Monitor** tab
                                    2. Run a manual transformation with "Apply Rules" enabled
                                    3. Rules will be applied in priority order
                                    """)
                                    
                                    # Show sample of source data
                                    with st.expander("📄 View Sample Source Data"):
                                        st.dataframe(sample_data.head(10), use_container_width=True)
                                else:
                                    st.warning("No data found in RAW_DATA_TABLE")
                                    
                            except Exception as e:
                                st.error(f"❌ Error testing rules: {str(e)}")
                else:
                    st.info(f"💡 No active rules defined for table `{test_target_table}`. Create rules in the 'Add Rule' tab.")

# ============================================
# PAGE: TRANSFORMATION MONITOR
# ============================================

if page == "📊 Transformation Monitor":
    st.markdown("### 📊 Transformation Monitor")
    st.markdown("Monitor Bronze → Silver transformation batches")
    
    st.subheader("Transformation Status Summary")
    summary_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_transformation_status_summary")
    
    if not summary_df.empty:
        col1, col2, col3, col4 = st.columns(4)
        
        total_batches = summary_df["BATCH_COUNT"].sum()
        total_processed = summary_df["TOTAL_PROCESSED"].sum()
        total_rejected = summary_df["TOTAL_REJECTED"].sum()
        avg_duration = summary_df["AVG_DURATION_SECONDS"].mean()
        
        col1.metric("Total Batches", f"{total_batches:,}")
        col2.metric("Records Processed", f"{total_processed:,}")
        col3.metric("Records Rejected", f"{total_rejected:,}")
        col4.metric("Avg Duration", f"{avg_duration:.1f}s" if not pd.isna(avg_duration) else "N/A")
        
        st.dataframe(summary_df, use_container_width=True)
    else:
        st.info("No transformation batches yet.")
    
    st.subheader("Recent Transformation Batches")
    batches_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_recent_transformation_batches")
    
    if not batches_df.empty:
        st.dataframe(
            batches_df,
            use_container_width=True,
            column_config={
                "BATCH_ID": "Batch ID",
                "SOURCE_TABLE": "Source",
                "TARGET_TABLE": "Target",
                "STATUS": "Status",
                "RECORDS_READ": st.column_config.NumberColumn("Read", format="%d"),
                "RECORDS_PROCESSED": st.column_config.NumberColumn("Processed", format="%d"),
                "RECORDS_REJECTED": st.column_config.NumberColumn("Rejected", format="%d"),
                "RULES_APPLIED": st.column_config.NumberColumn("Rules", format="%d"),
                "DURATION_SECONDS": st.column_config.NumberColumn("Duration (s)", format="%d"),
                "START_TIMESTAMP": st.column_config.DatetimeColumn("Started"),
                "END_TIMESTAMP": st.column_config.DatetimeColumn("Ended"),
                "ERROR_MESSAGE": "Error"
            }
        )
    else:
        st.info("No transformation batches yet.")
    
    st.subheader("Processing Watermarks")
    watermarks_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_watermark_status")
    
    if not watermarks_df.empty:
        st.dataframe(watermarks_df, use_container_width=True)
    else:
        st.info("No watermark data available.")
    
    st.subheader("Manual Transformation")
    
    # Get available target tables
    transform_tables = []
    try:
        tables_df = execute_query(f"SELECT DISTINCT table_name FROM {DB_SILVER}.target_schemas WHERE active = TRUE ORDER BY table_name", show_error=False)
        if not tables_df.empty:
            transform_tables = tables_df['TABLE_NAME'].tolist()
    except:
        pass
    
    with st.form("manual_transform_form"):
        col1, col2, col3 = st.columns(3)
        
        with col1:
            target_table_transform = st.selectbox("Target Table*", options=[""] + transform_tables, key="transform_target_table")
        
        with col2:
            batch_size = st.number_input("Batch Size", min_value=100, max_value=100000, value=10000)
        
        with col3:
            apply_rules = st.checkbox("Apply Rules", value=True)
        
        submitted = st.form_submit_button("Run Transformation")
        
        if submitted:
            if not target_table_transform:
                st.error("Target table is required")
            else:
                with st.spinner(f"Transforming data to {target_table_transform}..."):
                    result = execute_procedure(
                        f"CALL {DB_SILVER}.transform_bronze_to_silver('RAW_DATA_TABLE', '{target_table_transform}', "
                        f"'{BRONZE_SCHEMA}', {batch_size}, {apply_rules}, TRUE)"
                    )
                    st.info(result)
                    st.rerun()

# ============================================
# PAGE: DATA VIEWER
# ============================================

if page == "📋 Data Viewer":
    st.markdown("### 📋 Data Viewer")
    st.markdown("View and explore records in Silver layer tables")
    
    # Get list of available target tables
    target_tables_df = execute_query(f"""
        SELECT DISTINCT table_name 
        FROM {DB_SILVER}.target_schemas 
        WHERE active = TRUE 
        ORDER BY table_name
    """, show_error=False)
    
    if target_tables_df.empty:
        st.warning("⚠️ No target tables defined. Create tables in Target Table Designer first.")
    else:
        target_tables = target_tables_df['TABLE_NAME'].tolist()
        
        # Table selection
        col1, col2 = st.columns([2, 1])
        
        with col1:
            selected_table = st.selectbox("Select Table to View", options=target_tables, key="data_viewer_table")
        
        with col2:
            st.markdown("&nbsp;")  # Spacer
            refresh_btn = st.button("🔄 Refresh Data", use_container_width=True)
        
        if selected_table:
            # Check if physical table exists
            table_exists = execute_query(f"""
                SELECT COUNT(*) as cnt 
                FROM {DATABASE_NAME}.INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_SCHEMA = 'SILVER' 
                AND TABLE_NAME = '{selected_table}'
            """, show_error=False)
            
            if table_exists.empty or table_exists['CNT'][0] == 0:
                st.warning(f"⚠️ Table `{selected_table}` schema is defined but physical table not created yet. Run a transformation first.")
            else:
                # Get table statistics
                st.subheader(f"📊 Table: {selected_table}")
                
                col1, col2, col3, col4 = st.columns(4)
                
                # Total records
                count_df = execute_query(f"SELECT COUNT(*) as cnt FROM {DB_SILVER}.{selected_table}", show_error=False)
                total_records = count_df['CNT'][0] if not count_df.empty else 0
                col1.metric("Total Records", f"{total_records:,}")
                
                # Get column count
                columns_df = execute_query(f"""
                    SELECT COUNT(DISTINCT column_name) as cnt 
                    FROM {DB_SILVER}.target_schemas 
                    WHERE table_name = '{selected_table}' AND active = TRUE
                """, show_error=False)
                column_count = columns_df['CNT'][0] if not columns_df.empty else 0
                col2.metric("Columns", column_count)
                
                # Get distinct count for first column (if exists)
                if total_records > 0:
                    first_col_df = execute_query(f"""
                        SELECT column_name 
                        FROM {DB_SILVER}.target_schemas 
                        WHERE table_name = '{selected_table}' AND active = TRUE 
                        ORDER BY schema_id 
                        LIMIT 1
                    """, show_error=False)
                    
                    if not first_col_df.empty:
                        first_col = first_col_df['COLUMN_NAME'][0]
                        distinct_df = execute_query(f"SELECT COUNT(DISTINCT {first_col}) as cnt FROM {DB_SILVER}.{selected_table}", show_error=False)
                        distinct_count = distinct_df['CNT'][0] if not distinct_df.empty else 0
                        col3.metric(f"Unique {first_col}", f"{distinct_count:,}")
                
                # Last updated (if we have a timestamp column)
                last_update_df = execute_query(f"""
                    SELECT column_name 
                    FROM {DB_SILVER}.target_schemas 
                    WHERE table_name = '{selected_table}' 
                    AND (LOWER(column_name) LIKE '%timestamp%' OR LOWER(column_name) LIKE '%date%' OR LOWER(column_name) LIKE '%time%')
                    AND active = TRUE 
                    ORDER BY schema_id 
                    LIMIT 1
                """, show_error=False)
                
                if not last_update_df.empty:
                    time_col = last_update_df['COLUMN_NAME'][0]
                    max_time_df = execute_query(f"SELECT MAX({time_col}) as max_time FROM {DB_SILVER}.{selected_table}", show_error=False)
                    if not max_time_df.empty and max_time_df['MAX_TIME'][0] is not None:
                        col4.metric("Latest Record", str(max_time_df['MAX_TIME'][0])[:10])
                
                st.markdown("---")
                
                # Filtering and pagination
                st.subheader("🔍 Filter and View Data")
                
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    limit = st.number_input("Records to Display", min_value=10, max_value=10000, value=100, step=10)
                
                with col2:
                    offset = st.number_input("Offset (Skip Records)", min_value=0, max_value=1000000, value=0, step=100)
                
                with col3:
                    order_by_col = st.selectbox("Order By", options=["(Default)"] + [col['COLUMN_NAME'] for _, col in execute_query(f"""
                        SELECT column_name 
                        FROM {DB_SILVER}.target_schemas 
                        WHERE table_name = '{selected_table}' AND active = TRUE 
                        ORDER BY schema_id
                    """, show_error=False).iterrows()])
                
                # Optional WHERE clause
                with st.expander("🔎 Advanced Filter (WHERE clause)"):
                    where_clause = st.text_area(
                        "WHERE condition (optional)",
                        placeholder="Example: CLAIM_NUM LIKE 'AET%' AND GROUP_NAME = 'Metro Transit Authority'",
                        help="Enter a SQL WHERE condition without the 'WHERE' keyword"
                    )
                
                # Build query
                order_clause = f"ORDER BY {order_by_col} DESC" if order_by_col != "(Default)" else ""
                where_sql = f"WHERE {where_clause}" if where_clause else ""
                
                query = f"""
                    SELECT * 
                    FROM {DB_SILVER}.{selected_table}
                    {where_sql}
                    {order_clause}
                    LIMIT {limit}
                    OFFSET {offset}
                """
                
                # Execute and display
                if st.button("📊 Load Data", type="primary", use_container_width=True):
                    with st.spinner("Loading data..."):
                        data_df = execute_query(query, show_error=True)
                        
                        if not data_df.empty:
                            st.success(f"✅ Loaded {len(data_df)} records")
                            
                            # Display data with download option
                            st.dataframe(
                                data_df,
                                use_container_width=True,
                                height=600
                            )
                            
                            # Download button
                            csv = data_df.to_csv(index=False)
                            st.download_button(
                                label="📥 Download as CSV",
                                data=csv,
                                file_name=f"{selected_table}_data.csv",
                                mime="text/csv",
                                use_container_width=True
                            )
                        else:
                            st.info("No records found matching the criteria.")
                
                # Show sample query
                with st.expander("📝 View SQL Query"):
                    st.code(query, language="sql")

# ============================================
# PAGE: DATA QUALITY METRICS
# ============================================

if page == "📈 Data Quality Metrics":
    st.markdown("### 📈 Data Quality Metrics")
    st.markdown("Monitor data quality across Silver tables")
    
    st.subheader("Data Quality Dashboard")
    dashboard_df = execute_query(f"SELECT * FROM {DB_SILVER}.v_data_quality_dashboard")
    
    if not dashboard_df.empty:
        pass_count = len(dashboard_df[dashboard_df["PASS_FAIL"] == "PASS"])
        total_count = len(dashboard_df)
        quality_pct = (pass_count / total_count * 100) if total_count > 0 else 0
        
        col1, col2, col3 = st.columns(3)
        col1.metric("Overall Quality", f"{quality_pct:.1f}%")
        col2.metric("Passing Metrics", f"{pass_count}/{total_count}")
        col3.metric("Tables Monitored", dashboard_df["TABLE_NAME"].nunique())
        
        st.dataframe(
            dashboard_df,
            use_container_width=True,
            column_config={
                "TABLE_NAME": "Table",
                "METRIC_TYPE": "Metric",
                "PASS_FAIL": "Status",
                "MEASUREMENT_COUNT": st.column_config.NumberColumn("Measurements", format="%d"),
                "AVG_VALUE": st.column_config.NumberColumn("Avg Value", format="%.2f"),
                "MIN_VALUE": st.column_config.NumberColumn("Min", format="%.2f"),
                "MAX_VALUE": st.column_config.NumberColumn("Max", format="%.2f"),
                "LAST_MEASUREMENT": st.column_config.DatetimeColumn("Last Measured")
            }
        )
    else:
        st.info("No quality metrics recorded yet.")
    
    st.subheader("Quarantined Records")
    quarantine_df = execute_query(f"""
        SELECT quarantine_id, batch_id, source_table, target_table,
               quarantine_timestamp, resolved
        FROM {DB_SILVER}.quarantine_records
        ORDER BY quarantine_timestamp DESC
        LIMIT 50
    """)
    
    if not quarantine_df.empty:
        st.dataframe(
            quarantine_df,
            use_container_width=True,
            column_config={
                "QUARANTINE_ID": st.column_config.NumberColumn("ID", format="%d"),
                "BATCH_ID": "Batch",
                "SOURCE_TABLE": "Source",
                "TARGET_TABLE": "Target",
                "QUARANTINE_TIMESTAMP": st.column_config.DatetimeColumn("Quarantined"),
                "RESOLVED": st.column_config.CheckboxColumn("Resolved")
            }
        )
    else:
        st.success("No quarantined records!")

# ============================================
# PAGE: TASK MANAGEMENT
# ============================================

if page == "🔧 Task Management":
    st.markdown("### 🔧 Task Management")
    st.markdown("Control and monitor Silver layer tasks")
    
    st.subheader("Silver Task Status")
    
    # Get tasks using SHOW TASKS and convert to DataFrame
    try:
        # Execute SHOW TASKS command
        result = session.sql(f"SHOW TASKS IN SCHEMA {DB_SILVER}").collect()
        
        if result:
            # Convert to DataFrame
            import pandas as pd
            tasks_data = []
            for row in result:
                tasks_data.append({
                    'TASK_NAME': row['name'],
                    'STATE': row['state'],
                    'SCHEDULE': row['schedule'] if row['schedule'] else 'Dependent',
                    'WAREHOUSE': row['warehouse'],
                    'PREDECESSORS': row['predecessors'] if row['predecessors'] else '[]',
                    'CREATED_ON': row['created_on']
                })
            tasks_df = pd.DataFrame(tasks_data)
            
            # Sort by dependency order
            task_order = {
                'BRONZE_COMPLETION_SENSOR': 1,
                'SILVER_TRANSFORMATION_TASK': 2,
                'APPLY_RULES_TASK': 3,
                'DATA_QUALITY_CHECK_TASK': 4,
                'UPDATE_WATERMARKS_TASK': 5
            }
            tasks_df['SORT_ORDER'] = tasks_df['TASK_NAME'].map(lambda x: task_order.get(x, 99))
            tasks_df = tasks_df.sort_values('SORT_ORDER').drop('SORT_ORDER', axis=1)
        else:
            tasks_df = None
    except Exception as e:
        st.error(f"Error loading tasks: {str(e)}")
        tasks_df = None
    
    if tasks_df is not None and not tasks_df.empty:
        # Add visual indicators for task state
        tasks_df['STATUS_ICON'] = tasks_df['STATE'].apply(
            lambda x: '▶️ Running' if x == 'started' else '⏸️ Suspended' if x == 'suspended' else '⏹️ ' + str(x)
        )
        
        # Format predecessors for display
        tasks_df['DEPENDENCIES'] = tasks_df['PREDECESSORS'].apply(
            lambda x: 'Root Task' if x == '[]' else 'Dependent Task'
        )
        
        st.dataframe(
            tasks_df,
            use_container_width=True,
            column_config={
                "TASK_NAME": st.column_config.TextColumn("Task Name", width="large"),
                "STATUS_ICON": st.column_config.TextColumn("Status", width="small"),
                "STATE": st.column_config.TextColumn("State", width="small"),
                "SCHEDULE": st.column_config.TextColumn("Schedule", width="small"),
                "WAREHOUSE": st.column_config.TextColumn("Warehouse", width="small"),
                "DEPENDENCIES": st.column_config.TextColumn("Type", width="small"),
                "CREATED_ON": st.column_config.DatetimeColumn("Created", width="medium")
            },
            hide_index=True
        )
        
        # Show task dependency diagram
        with st.expander("📊 Task Dependency Flow"):
            st.markdown("""
            ```
            1. BRONZE_COMPLETION_SENSOR (Root Task)
               ↓ Every 5 minutes
            2. SILVER_TRANSFORMATION_TASK
               ↓ Transforms Bronze → Silver
            3. APPLY_RULES_TASK
               ↓ Applies DQ/Business/Standardization rules
            4. DATA_QUALITY_CHECK_TASK
               ↓ Validates data quality
            5. UPDATE_WATERMARKS_TASK
               ↓ Updates processing watermarks
            ```
            """)
    else:
        st.warning("⚠️ No Silver tasks found. Tasks may not be deployed yet.")
        st.info("""
        **To create tasks:**
        1. Ensure Silver layer is fully deployed
        2. Tasks should be created automatically during deployment
        3. Contact your administrator if tasks are missing
        """)
    
    st.subheader("Task Controls")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("▶️ Resume All Tasks"):
            result = execute_procedure(f"CALL {DB_SILVER}.resume_all_silver_tasks()")
            st.success(result)
            st.rerun()
    
    with col2:
        if st.button("⏸️ Suspend All Tasks"):
            result = execute_procedure(f"CALL {DB_SILVER}.suspend_all_silver_tasks()")
            st.success(result)
            st.rerun()
    
    with col3:
        if tasks_df is not None and not tasks_df.empty:
            task_names = tasks_df["TASK_NAME"].tolist()
            selected_task = st.selectbox("Execute Task:", [""] + task_names, key="execute_task")
            
            if st.button("▶️ Execute Now", key="execute_task_btn") and selected_task:
                with st.spinner(f"Executing {selected_task}..."):
                    try:
                        execute_query(f"EXECUTE TASK {DB_SILVER}.{selected_task}")
                        st.success(f"✅ Task {selected_task} executed successfully")
                    except Exception as e:
                        st.error(f"❌ Error executing task: {str(e)}")
    
    st.subheader("Task Execution History")
    
    history_df = execute_query(f"""
        SELECT 
            name as task_name,
            state,
            scheduled_time,
            completed_time,
            DATEDIFF(second, scheduled_time, completed_time) as runtime_seconds,
            error_code,
            error_message
        FROM TABLE({DATABASE_NAME}.INFORMATION_SCHEMA.TASK_HISTORY(
            SCHEDULED_TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP()),
            TASK_NAME => '{DB_SILVER}.%'
        ))
        ORDER BY scheduled_time DESC
        LIMIT 100
    """, show_error=False)
    
    if history_df is None or history_df.empty:
        st.info("""
        **Task execution history not available**
        
        Task history can be viewed directly in Snowsight:
        1. Navigate to **Monitoring** → **Task History**
        2. Filter by schema: `SILVER`
        3. View execution details, runtime, and errors
        """)
    else:
        st.dataframe(
            history_df,
            use_container_width=True,
            column_config={
                "TASK_NAME": "Task",
                "STATE": "State",
                "SCHEDULED_TIME": st.column_config.DatetimeColumn("Scheduled"),
                "COMPLETED_TIME": st.column_config.DatetimeColumn("Completed"),
                "RUNTIME_SECONDS": st.column_config.NumberColumn("Runtime (s)", format="%d"),
                "ERROR_CODE": "Error Code",
                "ERROR_MESSAGE": "Error"
            }
        )

# ============================================
# FOOTER
# ============================================

st.markdown("---")
st.markdown(
    f"<div style='text-align: center; color: gray;'>"
    f"{APP_ICON} Silver Layer Data Manager | Powered by Snowflake"
    "</div>",
    unsafe_allow_html=True
)
