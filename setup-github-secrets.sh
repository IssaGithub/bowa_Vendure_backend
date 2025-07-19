#!/bin/bash

# GitHub Secrets Setup Script for Bowa Vendure Backend Deployment
# This script creates all required secrets for the GitHub Actions deployment workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}GitHub Secrets Setup for Bowa Vendure Backend${NC}"
echo "=============================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    echo ""
    echo "Installation commands:"
    echo "  Ubuntu/Debian: sudo apt install gh"
    echo "  macOS: brew install gh"
    echo "  Windows: winget install GitHub.cli"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI not authenticated. Please login first:${NC}"
    echo "gh auth login"
    exit 1
fi

# Get repository information
REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
echo -e "${GREEN}Repository: $REPO${NC}"
echo ""

# Function to check if secret exists
check_secret_exists() {
    local secret_name=$1
    if gh secret list | grep -q "^$secret_name"; then
        return 0  # Secret exists
    else
        return 1  # Secret doesn't exist
    fi
}

# Function to generate random string
generate_random_string() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to create secret
create_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    echo -e "${YELLOW}Creating secret: $secret_name${NC}"
    echo "Description: $description"
    
    if echo "$secret_value" | gh secret set "$secret_name"; then
        echo -e "${GREEN}✓ Secret $secret_name created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create secret $secret_name${NC}"
        return 1
    fi
    echo ""
}

# Function to prompt for input with default
prompt_for_input() {
    local prompt_text=$1
    local default_value=$2
    local secret_mode=${3:-false}
    
    if [ "$secret_mode" = true ]; then
        echo -n "$prompt_text: "
        read -s user_input
        echo ""
    else
        if [ -n "$default_value" ]; then
            read -p "$prompt_text [$default_value]: " user_input
            user_input=${user_input:-$default_value}
        else
            read -p "$prompt_text: " user_input
        fi
    fi
    
    echo "$user_input"
}

echo -e "${BLUE}Checking existing secrets...${NC}"

# List of required secrets with descriptions
declare -A secrets_info=(
    ["VPS_HOST"]="Your VPS IP address or hostname"
    ["VPS_USER"]="SSH username for VPS connection"
    ["VPS_SSH_KEY"]="Private SSH key for VPS authentication"
    ["SUPERADMIN_USERNAME"]="Vendure superadmin username"
    ["SUPERADMIN_PASSWORD"]="Vendure superadmin password"
    ["COOKIE_SECRET"]="Secret key for session cookies (auto-generated)"
)

# Optional secrets
declare -A optional_secrets=(
    ["DOMAIN"]="Your domain name (e.g., yourdomain.com)"
    ["FRONTEND_DOMAIN"]="Frontend domain name (usually same as DOMAIN)"
    ["DB_TYPE"]="Database type (sqlite, postgres, mysql)"
    ["DB_HOST"]="Database host (for external databases)"
    ["DB_PORT"]="Database port"
    ["DB_NAME"]="Database name"
    ["DB_USERNAME"]="Database username"
    ["DB_PASSWORD"]="Database password"
)

# Check existing secrets
echo "Existing secrets:"
for secret_name in "${!secrets_info[@]}"; do
    if check_secret_exists "$secret_name"; then
        echo -e "  ${GREEN}✓ $secret_name${NC}"
    else
        echo -e "  ${RED}✗ $secret_name${NC}"
    fi
done

for secret_name in "${!optional_secrets[@]}"; do
    if check_secret_exists "$secret_name"; then
        echo -e "  ${GREEN}✓ $secret_name (optional)${NC}"
    fi
done

echo ""

# Create missing secrets
echo -e "${BLUE}Creating missing secrets...${NC}"
echo ""

# VPS_HOST
if ! check_secret_exists "VPS_HOST"; then
    vps_host=$(prompt_for_input "Enter your VPS IP address or hostname")
    create_secret "VPS_HOST" "$vps_host" "${secrets_info[VPS_HOST]}"
fi

# VPS_USER
if ! check_secret_exists "VPS_USER"; then
    vps_user=$(prompt_for_input "Enter SSH username for VPS" "root")
    create_secret "VPS_USER" "$vps_user" "${secrets_info[VPS_USER]}"
fi

# VPS_SSH_KEY
if ! check_secret_exists "VPS_SSH_KEY"; then
    echo -e "${YELLOW}VPS_SSH_KEY setup:${NC}"
    echo "You need to provide the private SSH key content."
    echo "Options:"
    echo "1. Paste the private key content directly"
    echo "2. Provide path to private key file"
    echo ""
    
    read -p "Choose option (1/2): " key_option
    
    if [ "$key_option" = "1" ]; then
        echo "Paste your private SSH key (press Ctrl+D when done):"
        ssh_key=$(cat)
    elif [ "$key_option" = "2" ]; then
        key_path=$(prompt_for_input "Enter path to private key file" "~/.ssh/id_rsa")
        key_path="${key_path/#\~/$HOME}"  # Expand tilde
        if [ -f "$key_path" ]; then
            ssh_key=$(cat "$key_path")
        else
            echo -e "${RED}Error: Key file not found at $key_path${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Invalid option${NC}"
        exit 1
    fi
    
    create_secret "VPS_SSH_KEY" "$ssh_key" "${secrets_info[VPS_SSH_KEY]}"
fi

# SUPERADMIN_USERNAME
if ! check_secret_exists "SUPERADMIN_USERNAME"; then
    admin_username=$(prompt_for_input "Enter Vendure superadmin username" "admin")
    create_secret "SUPERADMIN_USERNAME" "$admin_username" "${secrets_info[SUPERADMIN_USERNAME]}"
fi

# SUPERADMIN_PASSWORD
if ! check_secret_exists "SUPERADMIN_PASSWORD"; then
    echo -e "${YELLOW}Superadmin password options:${NC}"
    echo "1. Enter custom password"
    echo "2. Generate secure random password"
    read -p "Choose option (1/2): " pwd_option
    
    if [ "$pwd_option" = "1" ]; then
        admin_password=$(prompt_for_input "Enter superadmin password" "" true)
    else
        admin_password=$(generate_random_string 16)
        echo -e "${GREEN}Generated password: $admin_password${NC}"
        echo -e "${YELLOW}Please save this password securely!${NC}"
    fi
    
    create_secret "SUPERADMIN_PASSWORD" "$admin_password" "${secrets_info[SUPERADMIN_PASSWORD]}"
fi

# COOKIE_SECRET
if ! check_secret_exists "COOKIE_SECRET"; then
    cookie_secret=$(generate_random_string 64)
    create_secret "COOKIE_SECRET" "$cookie_secret" "${secrets_info[COOKIE_SECRET]}"
fi

# Optional secrets
echo -e "${BLUE}Optional secrets setup:${NC}"
read -p "Do you want to setup optional secrets (database, domain)? (y/N): " setup_optional

if [[ $setup_optional =~ ^[Yy]$ ]]; then
    # DOMAIN
    if ! check_secret_exists "DOMAIN"; then
        domain=$(prompt_for_input "Enter your domain name (e.g., yourdomain.com)")
        if [ -n "$domain" ]; then
            create_secret "DOMAIN" "$domain" "${optional_secrets[DOMAIN]}"
        fi
    fi
    
    # FRONTEND_DOMAIN
    if ! check_secret_exists "FRONTEND_DOMAIN"; then
        frontend_domain=$(prompt_for_input "Enter frontend domain" "$domain")
        if [ -n "$frontend_domain" ]; then
            create_secret "FRONTEND_DOMAIN" "$frontend_domain" "${optional_secrets[FRONTEND_DOMAIN]}"
        fi
    fi
    
    # Database configuration
    read -p "Do you want to setup external database secrets? (y/N): " setup_db
    if [[ $setup_db =~ ^[Yy]$ ]]; then
        if ! check_secret_exists "DB_TYPE"; then
            db_type=$(prompt_for_input "Enter database type" "postgres")
            create_secret "DB_TYPE" "$db_type" "${optional_secrets[DB_TYPE]}"
        fi
        
        if ! check_secret_exists "DB_HOST"; then
            db_host=$(prompt_for_input "Enter database host" "localhost")
            create_secret "DB_HOST" "$db_host" "${optional_secrets[DB_HOST]}"
        fi
        
        if ! check_secret_exists "DB_PORT"; then
            db_port=$(prompt_for_input "Enter database port" "5432")
            create_secret "DB_PORT" "$db_port" "${optional_secrets[DB_PORT]}"
        fi
        
        if ! check_secret_exists "DB_NAME"; then
            db_name=$(prompt_for_input "Enter database name" "bowa_vendure")
            create_secret "DB_NAME" "$db_name" "${optional_secrets[DB_NAME]}"
        fi
        
        if ! check_secret_exists "DB_USERNAME"; then
            db_username=$(prompt_for_input "Enter database username")
            create_secret "DB_USERNAME" "$db_username" "${optional_secrets[DB_USERNAME]}"
        fi
        
        if ! check_secret_exists "DB_PASSWORD"; then
            db_password=$(prompt_for_input "Enter database password" "" true)
            create_secret "DB_PASSWORD" "$db_password" "${optional_secrets[DB_PASSWORD]}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}✅ GitHub secrets setup completed!${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "Repository: $REPO"
echo "Secrets created/verified:"

# List all secrets again
for secret_name in "${!secrets_info[@]}"; do
    if check_secret_exists "$secret_name"; then
        echo -e "  ${GREEN}✓ $secret_name${NC}"
    fi
done

for secret_name in "${!optional_secrets[@]}"; do
    if check_secret_exists "$secret_name"; then
        echo -e "  ${GREEN}✓ $secret_name${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify your VPS SSH connection"
echo "2. Setup SSL certificates on your VPS"
echo "3. Run the GitHub Actions deployment workflow"
echo ""
echo -e "${GREEN}You can now deploy your Bowa Vendure Backend! 🚀${NC}" 