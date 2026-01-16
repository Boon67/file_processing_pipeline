#!/bin/bash

# ============================================================================
# Build Script for Snowflake Pipeline React Application
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Default values
IMAGE_NAME="snowflake-pipeline-app"
IMAGE_TAG="latest"
BUILD_MODE="standalone"
PUSH_TO_SNOWFLAKE=false
SNOWFLAKE_REPO_URL=""

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Docker image for Snowflake Pipeline Application

OPTIONS:
    -h, --help              Show this help message
    -t, --tag TAG           Image tag (default: latest)
    -m, --mode MODE         Build mode: standalone|spcs (default: standalone)
    -p, --push              Push to Snowflake registry (SPCS only)
    -r, --repo URL          Snowflake repository URL
    --no-cache              Build without cache

EXAMPLES:
    # Build for standalone deployment
    $0

    # Build for SPCS
    $0 --mode spcs

    # Build and push to Snowflake registry
    $0 --mode spcs --push --repo myorg-myaccount.registry.snowflakecomputing.com/db_ingest_pipeline/public/pipeline_app_repo

    # Build with specific tag
    $0 --tag v1.0.0

EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"
}

build_image() {
    print_header "Building Docker Image"
    
    print_info "Image: $IMAGE_NAME:$IMAGE_TAG"
    print_info "Mode: $BUILD_MODE"
    
    local BUILD_ARGS=""
    if [ "$NO_CACHE" = true ]; then
        BUILD_ARGS="--no-cache"
    fi
    
    docker build $BUILD_ARGS -t "$IMAGE_NAME:$IMAGE_TAG" .
    
    if [ $? -eq 0 ]; then
        print_success "Image built successfully"
    else
        print_error "Image build failed"
        exit 1
    fi
}

tag_for_snowflake() {
    if [ -z "$SNOWFLAKE_REPO_URL" ]; then
        print_error "Snowflake repository URL not provided"
        print_info "Use --repo option to specify repository URL"
        exit 1
    fi
    
    print_header "Tagging Image for Snowflake Registry"
    
    local SNOWFLAKE_IMAGE="$SNOWFLAKE_REPO_URL/$IMAGE_NAME:$IMAGE_TAG"
    print_info "Tagging as: $SNOWFLAKE_IMAGE"
    
    docker tag "$IMAGE_NAME:$IMAGE_TAG" "$SNOWFLAKE_IMAGE"
    
    if [ $? -eq 0 ]; then
        print_success "Image tagged successfully"
    else
        print_error "Image tagging failed"
        exit 1
    fi
}

push_to_snowflake() {
    if [ -z "$SNOWFLAKE_REPO_URL" ]; then
        print_error "Snowflake repository URL not provided"
        exit 1
    fi
    
    print_header "Pushing Image to Snowflake Registry"
    
    local SNOWFLAKE_IMAGE="$SNOWFLAKE_REPO_URL/$IMAGE_NAME:$IMAGE_TAG"
    print_info "Pushing: $SNOWFLAKE_IMAGE"
    
    # Check if logged in
    print_info "Checking Docker login status..."
    if ! docker login "$SNOWFLAKE_REPO_URL" --username dummy --password dummy &> /dev/null; then
        print_warning "Not logged in to Snowflake registry"
        print_info "Please login:"
        echo ""
        echo "  docker login $SNOWFLAKE_REPO_URL -u <your_snowflake_username>"
        echo ""
        read -p "Press Enter after logging in..."
    fi
    
    docker push "$SNOWFLAKE_IMAGE"
    
    if [ $? -eq 0 ]; then
        print_success "Image pushed successfully"
        print_info "Image: $SNOWFLAKE_IMAGE"
    else
        print_error "Image push failed"
        exit 1
    fi
}

show_next_steps() {
    print_header "Next Steps"
    
    if [ "$BUILD_MODE" = "standalone" ]; then
        cat << EOF

${GREEN}Standalone Deployment:${NC}

1. Run with Docker:
   docker run -d -p 8080:8080 \\
     -e SNOWFLAKE_ACCOUNT=your_account \\
     -e SNOWFLAKE_USER=your_user \\
     -e SNOWFLAKE_PASSWORD=your_password \\
     -e SNOWFLAKE_DATABASE=DB_INGEST_PIPELINE \\
     $IMAGE_NAME:$IMAGE_TAG

2. Or use Docker Compose:
   docker-compose up -d

3. Access application:
   http://localhost:8080

4. Check health:
   curl http://localhost:8080/health

EOF
    else
        cat << EOF

${GREEN}SPCS Deployment:${NC}

1. Verify image in registry:
   SHOW IMAGES IN IMAGE REPOSITORY PIPELINE_APP_REPO;

2. Deploy service:
   Execute spcs/deploy.sql in Snowflake

3. Monitor deployment:
   CALL SYSTEM\$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

4. Get endpoint URL:
   SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE;

5. View logs:
   CALL SYSTEM\$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);

EOF
    fi
}

# ============================================================================
# Parse Arguments
# ============================================================================

NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -m|--mode)
            BUILD_MODE="$2"
            if [ "$BUILD_MODE" != "standalone" ] && [ "$BUILD_MODE" != "spcs" ]; then
                print_error "Invalid mode: $BUILD_MODE (must be standalone or spcs)"
                exit 1
            fi
            shift 2
            ;;
        -p|--push)
            PUSH_TO_SNOWFLAKE=true
            shift
            ;;
        -r|--repo)
            SNOWFLAKE_REPO_URL="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# ============================================================================
# Main
# ============================================================================

print_header "Snowflake Pipeline Application - Build Script"

# Check prerequisites
check_docker

# Build image
build_image

# SPCS-specific steps
if [ "$BUILD_MODE" = "spcs" ]; then
    if [ "$PUSH_TO_SNOWFLAKE" = true ]; then
        tag_for_snowflake
        push_to_snowflake
    else
        print_warning "Image built but not pushed to Snowflake registry"
        print_info "Use --push option to push to registry"
    fi
fi

# Show next steps
show_next_steps

print_success "Build completed successfully!"
