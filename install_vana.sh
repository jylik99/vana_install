#!/bin/bash

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to display success
success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

# Function to display error
error() {
    echo -e "${RED}[✗] $1${NC}"
    exit 1
}

# Function to display warning
warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Function to check command execution status
check_error() {
    if [ $? -ne 0 ]; then
        error "$1"
    fi
}

# View logs function
show_logs() {
    clear
    log "Starting logs view... Press Ctrl+C to return to menu"
    sleep 2
    sudo journalctl -u vana.service -f
}

# Function to install base dependencies
install_base_dependencies() {
    clear
    log "Starting base dependencies installation..."
    
    # System update
    log "1/8 Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    check_error "Error updating system"
    success "System successfully updated"
    
    # Git
    log "2/8 Installing Git..."
    sudo apt-get install git -y
    check_error "Error installing Git"
    success "Git successfully installed"
    
    # Unzip
    log "3/8 Installing Unzip..."
    sudo apt install unzip -y
    check_error "Error installing Unzip"
    success "Unzip successfully installed"
    
    # Nano
    log "4/8 Installing Nano..."
    sudo apt install nano -y
    check_error "Error installing Nano"
    success "Nano successfully installed"
    
    # Python dependencies
    log "5/8 Installing Python dependencies..."
    sudo apt install software-properties-common -y
    check_error "Error installing software-properties-common"
    
    log "Adding Python repository..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    check_error "Error adding Python repository"
    
    sudo apt update
    sudo apt install python3.11 -y
    check_error "Error installing Python 3.11"
    
    # Check Python version
    python_version=$(python3.11 --version)
    if [[ $python_version == *"3.11"* ]]; then
        success "Python $python_version successfully installed"
    else
        error "Error installing Python 3.11"
    fi
    
    # Poetry
    log "6/8 Installing Poetry..."
    sudo apt install python3-pip python3-venv curl -y
    curl -sSL https://install.python-poetry.org | python3 -
    export PATH="$HOME/.local/bin:$PATH"
    source ~/.bashrc
    if command -v poetry &> /dev/null; then
        success "Poetry successfully installed: $(poetry --version)"
    else
        error "Error installing Poetry"
    fi
    
    # Node.js and npm
    log "7/8 Installing Node.js and npm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    source ~/.bashrc
    fnm use --install-if-missing 22
    check_error "Error installing Node.js"
    
    if command -v node &> /dev/null; then
        success "Node.js successfully installed: $(node -v)"
    else
        error "Error installing Node.js"
    fi
    
    # Yarn
    log "8/8 Installing Yarn..."
    apt-get install nodejs -y
    npm install -g yarn
    if command -v yarn &> /dev/null; then
        success "Yarn successfully installed: $(yarn --version)"
    else
        error "Error installing Yarn"
    fi
    
    log "All base dependencies successfully installed!"
    read -p "Press Enter to return to main menu..."
}

# Function to install node
install_node() {
    clear
    log "Starting node installation..."
    
    # Clone repository
    log "1/5 Cloning repository..."
    if [ -d "vana-dlp-chatgpt" ]; then
        warning "Directory vana-dlp-chatgpt already exists"
        read -p "Do you want to remove it and clone again? (y/n): " choice
        if [[ $choice == "y" ]]; then
            rm -rf vana-dlp-chatgpt
        else
            error "Cannot continue without clean repository"
        fi
    fi
    
    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    check_error "Error cloning repository"
    cd vana-dlp-chatgpt
    success "Repository cloned successfully"
    
    # Create .env file
    log "2/5 Creating .env file..."
    cp .env.example .env
    check_error "Error creating .env file"
    success ".env file created"
    
    # Install dependencies
    log "3/5 Installing project dependencies..."
    poetry install
    check_error "Error installing project dependencies"
    success "Project dependencies installed"
    
    # Install CLI
    log "4/5 Installing Vana CLI..."
    pip install vana
    check_error "Error installing Vana CLI"
    success "Vana CLI installed"
    
    # Create wallet
    log "5/5 Creating wallet..."
    vanacli wallet create --wallet.name default --wallet.hotkey default
    check_error "Error creating wallet"
    
    success "Node installation completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to create and deploy DLP
create_and_deploy_dlp() {
    clear
    log "Starting DLP creation and deployment..."

    # Detailed directory check
    log "Checking node installation..."
    if [ ! -d "$HOME/vana-dlp-chatgpt" ]; then
        warning "Node directory not found at $HOME/vana-dlp-chatgpt"
        log "Checking current working directory..."
        pwd
        log "Listing home directory contents:"
        ls -la $HOME
        
        read -p "Would you like to reinstall the node? (y/n): " choice
        if [[ $choice == "y" ]]; then
            install_node
        else
            error "Cannot proceed without node installation"
        fi
    fi

    # Generate keys
    log "1/5 Generating keys..."
    cd $HOME/vana-dlp-chatgpt || error "Cannot access node directory"
    
    log "Current directory:"
    pwd
    log "Directory contents:"
    ls -la
    
    if [ ! -f "keygen.sh" ]; then
        error "keygen.sh not found. Directory contents are not correct"
    fi
    
    chmod +x keygen.sh
    ./keygen.sh
    check_error "Error generating keys"
    success "Keys generated successfully"
    warning "Make sure to save all 4 keys:"
    echo "- public_key.asc and public_key_base64.asc (for UI)"
    echo "- private_key.asc and private_key_base64.asc (for validator)"

    # Stop node service if running
    log "2/5 Stopping vana service..."
    if systemctl is-active --quiet vana.service; then
        sudo systemctl stop vana.service
        success "Service stopped"
    else
        log "No active service found, continuing..."
    fi

    # Setup smart contract deployment
    log "3/5 Setting up smart contract deployment..."
    cd $HOME
    if [ -d "vana-dlp-smart-contracts" ]; then
        rm -rf vana-dlp-smart-contracts
    fi
    git clone https://github.com/Josephtran102/vana-dlp-smart-contracts
    cd vana-dlp-smart-contracts || error "Cannot access smart contracts directory"
    yarn install
    check_error "Error installing smart contract dependencies"
    success "Smart contract dependencies installed"

    # Configure environment
    log "4/5 Configuring environment..."
    cp .env.example .env
    check_error "Error creating .env file"
    
    echo -e "${YELLOW}Please provide the following information:${NC}"
    read -p "Enter your coldkey private key (with 0x prefix): " private_key
    read -p "Enter your coldkey wallet address (with 0x prefix): " owner_address
    read -p "Enter DLP name: " dlp_name
    read -p "Enter DLP token name: " token_name
    read -p "Enter DLP token symbol: " token_symbol

    # Update .env file
    sed -i "s/^DEPLOYER_PRIVATE_KEY=.*/DEPLOYER_PRIVATE_KEY=$private_key/" .env
    sed -i "s/^OWNER_ADDRESS=.*/OWNER_ADDRESS=$owner_address/" .env
    sed -i "s/^DLP_NAME=.*/DLP_NAME=$dlp_name/" .env
    sed -i "s/^DLP_TOKEN_NAME=.*/DLP_TOKEN_NAME=$token_name/" .env
    sed -i "s/^DLP_TOKEN_SYMBOL=.*/DLP_TOKEN_SYMBOL=$token_symbol/" .env
    
    success "Environment configured"

    # Deploy contract
    log "5/5 Deploying smart contract..."
    warning "Please ensure you have test tokens in your Coldkey and Hotkey wallets before proceeding"
    read -p "Do you have test tokens and want to proceed with deployment? (y/n): " proceed
    
    if [[ $proceed == "y" ]]; then
        npx hardhat deploy --network moksha --tags DLPDeploy
        check_error "Error deploying contract"
        success "Contract deployed successfully"
        warning "IMPORTANT: Save the DataLiquidityPoolToken and DataLiquidityPool addresses from the output above!"
    else
        warning "Deployment skipped. Get test tokens and run deployment later."
    fi

    log "DLP creation and deployment process completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to install validator
install_validator() {
    clear
    log "Starting validator installation..."

    # Get OpenAI API Key
    log "1/4 Setting up OpenAI API..."
    read -p "Enter your OpenAI API key: " openai_key
    success "OpenAI API key received"

    # Get public key
    log "2/4 Getting public key..."
    if [ -f "/root/vana-dlp-chatgpt/public_key_base64.asc" ]; then
        public_key=$(cat /root/vana-dlp-chatgpt/public_key_base64.asc)
        success "Public key retrieved"
        warning "Make sure to save this public key to a safe place:"
        echo "$public_key"
        read -p "Press Enter after saving the public key..."
    else
        error "public_key_base64.asc not found. Have you completed the DLP creation step?"
    fi

    # Configure environment
    log "3/4 Configuring environment..."
    cd /root/vana-dlp-chatgpt || error "vana-dlp-chatgpt directory not found"

    # Create new .env content
    echo "# The network to use, currently Vana Moksha testnet" > .env
    echo "OD_CHAIN_NETWORK=moksha" >> .env
    echo "OD_CHAIN_NETWORK_ENDPOINT=https://rpc.moksha.vana.org" >> .env
    echo "" >> .env
    echo "# OpenAI API key for additional data quality check" >> .env
    echo "OPENAI_API_KEY=\"$openai_key\"" >> .env
    echo "" >> .env
    echo "# Your own DLP smart contract address" >> .env
    read -p "Enter your DataLiquidityPool address: " dlp_address
    echo "DLP_MOKSHA_CONTRACT=$dlp_address" >> .env
    echo "" >> .env
    read -p "Enter your DataLiquidityPoolToken address: " dlp_token_address
    echo "DLP_TOKEN_MOKSHA_CONTRACT=$dlp_token_address" >> .env
    echo "" >> .env
    echo "# The private key for the DLP" >> .env
    echo "PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=\"$public_key\"" >> .env

    success "Environment file configured"

    # Verify configuration
    log "4/4 Verifying configuration..."
    echo -e "${YELLOW}Please verify the following information in your .env file:${NC}"
    echo "1. OpenAI API key"
    echo "2. DataLiquidityPool address"
    echo "3. DataLiquidityPoolToken address"
    echo "4. Public key"
    
    read -p "Is everything correct? (y/n): " verify
    if [[ $verify != "y" ]]; then
        warning "Please run the validator setup again to correct the information"
        read -p "Press Enter to return to main menu..."
        return
    fi

    success "Validator installation completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to register and start validator
register_and_start_validator() {
    clear
    log "Starting validator registration and service setup..."

    # Register validator
    log "1/4 Registering validator..."
    cd /root/vana-dlp-chatgpt || error "vana-dlp-chatgpt directory not found"
    
    ./vanacli dlp register_validator --stake_amount 10
    check_error "Error registering validator"
    success "Validator registration completed"

    # Approve validator
    log "2/4 Approving validator..."
    read -p "Enter your Hotkey wallet address: " hotkey_address
    
    ./vanacli dlp approve_validator --validator_address="$hotkey_address"
    check_error "Error approving validator"
    success "Validator approved"

    # Test validator
    log "3/4 Testing validator..."
    poetry run python -m chatgpt.nodes.validator
    
    # Create and start service
    log "4/4 Setting up validator service..."
    
    # Find poetry path
    poetry_path=$(which poetry)
    if [ -z "$poetry_path" ]; then
        error "Poetry not found in PATH"
    fi
    success "Found poetry at: $poetry_path"

    # Create service file
    log "Creating service file..."
    sudo tee /etc/systemd/system/vana.service << EOF
[Unit]
Description=Vana Validator Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/vana-dlp-chatgpt
ExecStart=$poetry_path run python -m chatgpt.nodes.validator
Restart=on-failure
RestartSec=10
Environment=PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin:/root/vana-dlp-chatgpt/myenv/bin
Environment=PYTHONPATH=/root/vana-dlp-chatgpt

[Install]
WantedBy=multi-user.target
EOF
    check_error "Error creating service file"
    success "Service file created"

    # Start service
    log "Starting validator service..."
    sudo systemctl daemon-reload
    sudo systemctl enable vana.service
    sudo systemctl start vana.service
    
    # Check service status
    service_status=$(sudo systemctl status vana.service)
    if [[ $service_status == *"active (running)"* ]]; then
        success "Validator service is running"
    else
        error "Validator service failed to start. Check status with: sudo systemctl status vana.service"
    fi

    success "Validator setup completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to remove node
remove_node() {
    clear
    log "Starting node removal process..."

    # Stop service if running
    log "1/4 Stopping validator service..."
    if systemctl is-active --quiet vana.service; then
        sudo systemctl stop vana.service
        sudo systemctl disable vana.service
        success "Validator service stopped and disabled"
    else
        warning "Validator service was not running"
    fi

    # Remove service file
    log "2/4 Removing service file..."
    if [ -f "/etc/systemd/system/vana.service" ]; then
        sudo rm /etc/systemd/system/vana.service
        sudo systemctl daemon-reload
        success "Service file removed"
    else
        warning "Service file not found"
    fi

    # Remove node directory
    log "3/4 Removing node directories..."
    cd $HOME
    
    if [ -d "vana-dlp-chatgpt" ]; then
        rm -rf vana-dlp-chatgpt
        success "vana-dlp-chatgpt directory removed"
    else
        warning "vana-dlp-chatgpt directory not found"
    fi
    
    if [ -d "vana-dlp-smart-contracts" ]; then
        rm -rf vana-dlp-smart-contracts
        success "vana-dlp-smart-contracts directory removed"
    else
        warning "vana-dlp-smart-contracts directory not found"
    fi

    # Remove .vana directory with configs
    log "4/4 Removing configuration files..."
    if [ -d "$HOME/.vana" ]; then
        rm -rf $HOME/.vana
        success ".vana configuration directory removed"
    else
        warning ".vana configuration directory not found"
    fi

    log "Node removal completed! You can now install a fresh node if needed."
    read -p "Press Enter to return to main menu..."
}
 
install_node() {
    clear
    log "Starting node installation..."
    
    # Clone repository
    log "1/5 Cloning repository..."
    if [ -d "vana-dlp-chatgpt" ]; then
        warning "Directory vana-dlp-chatgpt already exists"
        read -p "Do you want to remove it and clone again? (y/n): " choice
        if [[ $choice == "y" ]]; then
            rm -rf vana-dlp-chatgpt
        else
            error "Cannot continue without clean repository"
        fi
    fi
    
    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    check_error "Error cloning repository"
    cd vana-dlp-chatgpt
    success "Repository cloned successfully"
    
    # Create .env file
    log "2/5 Creating .env file..."
    cp .env.example .env
    check_error "Error creating .env file"
    success ".env file created"
    
    # Install dependencies
    log "3/5 Installing project dependencies..."
    poetry install
    check_error "Error installing project dependencies"
    success "Project dependencies installed"
    
    # Install CLI
    log "4/5 Installing Vana CLI..."
    pip install vana
    check_error "Error installing Vana CLI"
    success "Vana CLI installed"
    
    # Create wallet
    log "5/5 Creating wallet..."
    vanacli wallet create --wallet.name default --wallet.hotkey default
    check_error "Error creating wallet"
    
    success "Node installation completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to create and deploy DLP
create_and_deploy_dlp() {
    clear
    log "Starting DLP creation and deployment..."

    # Generate keys
    log "1/5 Generating keys..."
    cd vana-dlp-chatgpt
    ./keygen.sh
    check_error "Error generating keys"
    success "Keys generated successfully"
    warning "Make sure to save all 4 keys:"
    echo "- public_key.asc and public_key_base64.asc (for UI)"
    echo "- private_key.asc and private_key_base64.asc (for validator)"

    # Stop node service if running
    log "2/5 Stopping vana service..."
    sudo systemctl stop vana.service
    success "Service stopped"

    # Setup smart contract deployment
    log "3/5 Setting up smart contract deployment..."
    cd $HOME
    if [ -d "vana-dlp-smart-contracts" ]; then
        rm -rf vana-dlp-smart-contracts
    fi
    git clone https://github.com/Josephtran102/vana-dlp-smart-contracts
    cd vana-dlp-smart-contracts
    yarn install
    check_error "Error installing smart contract dependencies"
    success "Smart contract dependencies installed"

    # Configure environment
    log "4/5 Configuring environment..."
    cp .env.example .env
    
    echo -e "${YELLOW}Please provide the following information:${NC}"
    read -p "Enter your coldkey private key (with 0x prefix): " private_key
    read -p "Enter your coldkey wallet address (with 0x prefix): " owner_address
    read -p "Enter DLP name: " dlp_name
    read -p "Enter DLP token name: " token_name
    read -p "Enter DLP token symbol: " token_symbol

    # Update .env file
    sed -i "s/^DEPLOYER_PRIVATE_KEY=.*/DEPLOYER_PRIVATE_KEY=$private_key/" .env
    sed -i "s/^OWNER_ADDRESS=.*/OWNER_ADDRESS=$owner_address/" .env
    sed -i "s/^DLP_NAME=.*/DLP_NAME=$dlp_name/" .env
    sed -i "s/^DLP_TOKEN_NAME=.*/DLP_TOKEN_NAME=$token_name/" .env
    sed -i "s/^DLP_TOKEN_SYMBOL=.*/DLP_TOKEN_SYMBOL=$token_symbol/" .env
    
    success "Environment configured"

    # Deploy contract
    log "5/5 Deploying smart contract..."
    warning "Please ensure you have test tokens in your Coldkey and Hotkey wallets before proceeding"
    read -p "Do you have test tokens and want to proceed with deployment? (y/n): " proceed
    
    if [[ $proceed == "y" ]]; then
        npx hardhat deploy --network moksha --tags DLPDeploy
        check_error "Error deploying contract"
        success "Contract deployed successfully"
        warning "IMPORTANT: Save the DataLiquidityPoolToken and DataLiquidityPool addresses from the output above!"
    else
        warning "Deployment skipped. Get test tokens and run deployment later."
    fi

    log "DLP creation and deployment process completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to install validator
install_validator() {
    clear
    log "Starting validator installation..."

    # Get OpenAI API Key
    log "1/4 Setting up OpenAI API..."
    read -p "Enter your OpenAI API key: " openai_key
    success "OpenAI API key received"

    # Get public key
    log "2/4 Getting public key..."
    if [ -f "/root/vana-dlp-chatgpt/public_key_base64.asc" ]; then
        public_key=$(cat /root/vana-dlp-chatgpt/public_key_base64.asc)
        success "Public key retrieved"
        warning "Make sure to save this public key to a safe place:"
        echo "$public_key"
        read -p "Press Enter after saving the public key..."
    else
        error "public_key_base64.asc not found. Have you completed the DLP creation step?"
    fi

    # Configure environment
    log "3/4 Configuring environment..."
    cd /root/vana-dlp-chatgpt || error "vana-dlp-chatgpt directory not found"

    # Create new .env content
    echo "# The network to use, currently Vana Moksha testnet" > .env
    echo "OD_CHAIN_NETWORK=moksha" >> .env
    echo "OD_CHAIN_NETWORK_ENDPOINT=https://rpc.moksha.vana.org" >> .env
    echo "" >> .env
    echo "# OpenAI API key for additional data quality check" >> .env
    echo "OPENAI_API_KEY=\"$openai_key\"" >> .env
    echo "" >> .env
    echo "# Your own DLP smart contract address" >> .env
    read -p "Enter your DataLiquidityPool address: " dlp_address
    echo "DLP_MOKSHA_CONTRACT=$dlp_address" >> .env
    echo "" >> .env
    read -p "Enter your DataLiquidityPoolToken address: " dlp_token_address
    echo "DLP_TOKEN_MOKSHA_CONTRACT=$dlp_token_address" >> .env
    echo "" >> .env
    echo "# The private key for the DLP" >> .env
    echo "PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=\"$public_key\"" >> .env

    success "Environment file configured"

    # Verify configuration
    log "4/4 Verifying configuration..."
    echo -e "${YELLOW}Please verify the following information in your .env file:${NC}"
    echo "1. OpenAI API key"
    echo "2. DataLiquidityPool address"
    echo "3. DataLiquidityPoolToken address"
    echo "4. Public key"
    
    read -p "Is everything correct? (y/n): " verify
    if [[ $verify != "y" ]]; then
        warning "Please run the validator setup again to correct the information"
        read -p "Press Enter to return to main menu..."
        return
    fi

    success "Validator installation completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to register and start validator
register_and_start_validator() {
    clear
    log "Starting validator registration and service setup..."

    # Register validator
    log "1/4 Registering validator..."
    cd /root/vana-dlp-chatgpt || error "vana-dlp-chatgpt directory not found"
    
    ./vanacli dlp register_validator --stake_amount 10
    check_error "Error registering validator"
    success "Validator registration completed"

    # Approve validator
    log "2/4 Approving validator..."
    read -p "Enter your Hotkey wallet address: " hotkey_address
    
    ./vanacli dlp approve_validator --validator_address="$hotkey_address"
    check_error "Error approving validator"
    success "Validator approved"

    # Test validator
    log "3/4 Testing validator..."
    poetry run python -m chatgpt.nodes.validator
    
    # Create and start service
    log "4/4 Setting up validator service..."
    
    # Find poetry path
    poetry_path=$(which poetry)
    if [ -z "$poetry_path" ]; then
        error "Poetry not found in PATH"
    fi
    success "Found poetry at: $poetry_path"

    # Create service file
    log "Creating service file..."
    sudo tee /etc/systemd/system/vana.service << EOF
[Unit]
Description=Vana Validator Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/vana-dlp-chatgpt
ExecStart=$poetry_path run python -m chatgpt.nodes.validator
Restart=on-failure
RestartSec=10
Environment=PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin:/root/vana-dlp-chatgpt/myenv/bin
Environment=PYTHONPATH=/root/vana-dlp-chatgpt

[Install]
WantedBy=multi-user.target
EOF
    check_error "Error creating service file"
    success "Service file created"

    # Start service
    log "Starting validator service..."
    sudo systemctl daemon-reload
    sudo systemctl enable vana.service
    sudo systemctl start vana.service
    
    # Check service status
    service_status=$(sudo systemctl status vana.service)
    if [[ $service_status == *"active (running)"* ]]; then
        success "Validator service is running"
    else
        error "Validator service failed to start. Check status with: sudo systemctl status vana.service"
    fi

    success "Validator setup completed!"
    read -p "Press Enter to return to main menu..."
}

# Function to remove node
remove_node() {
    clear
    log "Starting node removal process..."

    # Stop service if running
    log "1/4 Stopping validator service..."
    if systemctl is-active --quiet vana.service; then
        sudo systemctl stop vana.service
        sudo systemctl disable vana.service
        success "Validator service stopped and disabled"
    else
        warning "Validator service was not running"
    fi

    # Remove service file
    log "2/4 Removing service file..."
    if [ -f "/etc/systemd/system/vana.service" ]; then
        sudo rm /etc/systemd/system/vana.service
        sudo systemctl daemon-reload
        success "Service file removed"
    else
        warning "Service file not found"
    fi

    # Remove node directory
    log "3/4 Removing node directories..."
    cd $HOME
    
    if [ -d "vana-dlp-chatgpt" ]; then
        rm -rf vana-dlp-chatgpt
        success "vana-dlp-chatgpt directory removed"
    else
        warning "vana-dlp-chatgpt directory not found"
    fi
    
    if [ -d "vana-dlp-smart-contracts" ]; then
        rm -rf vana-dlp-smart-contracts
        success "vana-dlp-smart-contracts directory removed"
    else
        warning "vana-dlp-smart-contracts directory not found"
    fi

    # Remove .vana directory with configs
    log "4/4 Removing configuration files..."
    if [ -d "$HOME/.vana" ]; then
        rm -rf $HOME/.vana
        success ".vana configuration directory removed"
    else
        warning ".vana configuration directory not found"
    fi

    log "Node removal completed! You can now install a fresh node if needed."
    read -p "Press Enter to return to main menu..."
}

# Main menu function
show_menu() {
    clear
    echo -e "${BLUE}=== Vana Node Installation ===${NC}"
    echo "1. Install base dependencies"
    echo "2. Install node"
    echo "3. Create and deploy DLP"
    echo "4. Install validator"
    echo "5. Register and start validator"
    echo "6. View validator logs"
    echo "7. Remove node"
    echo "8. Exit"
    echo
    read -p "Select an option (1-8): " choice
    
    case $choice in
        1)
            install_base_dependencies
            show_menu
            ;;
        2)
            install_node
            show_menu
            ;;
        3)
            create_and_deploy_dlp
            show_menu
            ;;
        4)
            install_validator
            show_menu
            ;;
        5)
            register_and_start_validator
            show_menu
            ;;
        6)
            show_logs
            show_menu
            ;;
        7)
            remove_node
            show_menu
            ;;
        8)
            log "Exiting installer"
            exit 0
            ;;
        *)
            warning "Invalid choice. Please select 1-8"
            read -p "Press Enter to continue..."
            show_menu
            ;;
    esac
}

# Start script by showing menu
show_menu