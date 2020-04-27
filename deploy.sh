#! /bin/bash

# Usage instructions at https://github.com/tash-had/azure-flask-deploy-script

# git config
GIT_USERNAME=''
GIT_REPO_NAME=''
GIT_BRANCH='master'
GIT_ACCESS_TOKEN=':'
GIT_CLONE_URL=''

# project config
PROJECT_LABEL=''
PROJECT_TEST_FOLDER='tests'
PROJECT_APP_FILE='app.py'
PROJECT_PARENT_FOLDER='.'

# vm config
VM_USERNAME=''
VM_HOME_DIR=''
VM_PROJECT_PATH=''
VM_NGINX_PATH='/etc/nginx'
VM_PY_PATH='/usr/bin/python3.6'

# deployment config
DEPLOYMENT_ENV='development'
DEPLOYMENT_PORT='5000'

function setup_host() {
    printf "***************************************************\n\t\tSetup Host \n***************************************************\n"
    # Update packages
    echo ======= Updating packages ========
    sudo apt-get update

    # Export language locale settings
    echo ======= Exporting language locale settings =======
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8

    # Install pip3
    echo ======= Installing pip3 =======
    sudo apt-get install -y python3-pip
}

function init_venv() {
    printf "***************************************************\n\t\tSetting up Venv \n***************************************************\n"
    # Install virtualenv
    echo ======= Installing virtualenv =======
    pip3 install virtualenv

    # Create virtual environment and activate it
    echo ======== Creating and activating virtual env =======
    virtualenv -p $VM_PY_PATH venv
    source $VM_HOME_DIR/venv/bin/activate
}

function clone_app_repository() {
    printf "***************************************************\n\t\tFetching Code \n***************************************************\n"
    # Clone and access project directory
    echo ======== Cloning and accessing project directory ========
    if [[ -d $VM_PROJECT_PATH ]]; then
        sudo rm -rf $VM_PROJECT_PATH
    fi
    
    cd $VM_HOME_DIR

    if [ $PROJECT_PARENT_FOLDER == "." ]; then
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL
    else
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL && git filter-branch --subdirectory-filter $PROJECT_PARENT_FOLDER
    fi
}

function setup_app() {
    printf "***************************************************\n    Installing App dependencies \n***************************************************\n"
    # Install required packages
    echo ======= Installing required packages ========
    requirements_file="$VM_PROJECT_PATH/requirements.txt"
    if [ -f "$requirements_file" ]; then
        pip3 install -r $requirements_file
    fi
}

# Create and Export required environment variable
function setup_env() {
    echo ======= Exporting the necessary environment variables ========
    sudo cat > $VM_PROJECT_PATH/.env << EOF
    export APP_CONFIG=${DEPLOYMENT_ENV}
    export FLASK_APP=${PROJECT_APP_FILE}
EOF
    echo ======= Exporting the necessary environment variables ========
    source $VM_PROJECT_PATH/.env
}

# Install and configure nginx
function setup_nginx() {
    printf "***************************************************\n\t\tSetting up nginx \n***************************************************\n"
    echo ======= Installing nginx =======
    sudo apt-get install -y nginx

    # Configure nginx routing
    echo ======= Configuring nginx =======
    echo ======= Removing default config =======
    sudo rm -rf $VM_NGINX_PATH/sites-available/default
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/default
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL
    sudo touch $VM_NGINX_PATH/sites-available/$PROJECT_LABEL

    echo ======= Create a symbolic link of the file to sites-enabled =======
    sudo ln -s $VM_NGINX_PATH/sites-available/$PROJECT_LABEL $VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL

    echo ======= Replace config file =======
    sudo cat >$VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL <<EOL
   server {
            location / {
                proxy_pass http://localhost:${DEPLOYMENT_PORT};
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
            }
    }
EOL

    # Ensure nginx server is running
    echo ====== Checking nginx server status ========
    sudo /etc/init.d/nginx restart
    sudo /etc/init.d/nginx status
}

# Add a launch script
function create_launch_script () {
    printf "***************************************************\n\t\tCreating a Launch script \n***************************************************\n"
    
    gunicorn_pid=`ps ax | grep gunicorn | grep $DEPLOYMENT_PORT | awk '{split($0,a," "); print a[1]}' | head -n 1`

    sudo cat > $VM_PROJECT_PATH/launch.sh <<EOF
    #!/bin/bash
    printf "\nStarting Launch Script...\n"
    cd $VM_PROJECT_PATH
    source $VM_PROJECT_PATH/.env
    source $VM_HOME_DIR/venv/bin/activate
    sudo kill ${gunicorn_pid}
    sudo $VM_HOME_DIR/venv/bin/gunicorn -b 0.0.0.0:$DEPLOYMENT_PORT --env APP_CONFIG=${DEPLOYMENT_ENV} --daemon app:APP
    printf "\n\n***************************************************\n\t\tDeployment Succeeded.\n***************************************************\n\n"
EOF
    sudo chmod 744 $VM_PROJECT_PATH/launch.sh
    echo ====== Ensuring script is executable =======
    ls -la $VM_PROJECT_PATH/launch.sh
}

# Serve the web app through gunicorn
function launch_app() {
    sudo bash $VM_PROJECT_PATH/launch.sh
}

# Run tests
function run_tests() {
    test_folder="$VM_PROJECT_PATH/$PROJECT_TEST_FOLDER"
    if [[ -d $test_folder ]]; then
        pip install nose
        cd $test_folder
        nosetests test*
    fi   
}

function print_status() {
    case $2 in
        0) printf "$1...SUCCESS\n" ;;
        *) printf "$1...FAILED\n"  ;;
    esac
    if [ $2 -ne 0 ]
        then
          printf "Exiting early because '$1' has failed.\n"
          printf "***************************************************\n\t\tDeployment failed.\n***************************************************\n"
          exit 2
    fi
}

function print_usage() {
  printf "usage: deploy [-b branch] [-c token] [-l label] [-t test_folder] [-r root_file] [-s subdirectory] [-e environment] [-p port] git_user repo_name vm_user"
}

function set_dependent_config() {
    # set values of variables that depend on the arguments given to the script
    GIT_USERNAME=$1
    GIT_REPO_NAME=$2
    GIT_CLONE_URL="https://$GIT_USERNAME:$GIT_ACCESS_TOKEN@github.com/$GIT_USERNAME/$GIT_REPO_NAME.git"

    PROJECT_LABEL="$GIT_REPO_NAME-$DEPLOYMENT_ENV"

    VM_USERNAME=$3
    VM_HOME_DIR="/home/$VM_USERNAME"
    VM_PROJECT_PATH="$VM_HOME_DIR/$PROJECT_LABEL"
}

# Runtime

# Process flags
while getopts 'b:c:l:t:r:s:e:p:' flag; do
  case "${flag}" in
    b) GIT_BRANCH="${OPTARG}" ;;
    c) GIT_ACCESS_TOKEN="${OPTARG}" ;;
    l) PROJECT_LABEL="${OPTARG}" ;;
    t) PROJECT_TEST_FOLDER="${OPTARG}" ;;
    r) PROJECT_APP_FILE="${OPTARG}" ;;
    s) PROJECT_PARENT_FOLDER="${OPTARG}" ;;
    e) DEPLOYMENT_ENV="${OPTARG}" ;;
    p) DEPLOYMENT_PORT="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done
shift $(($OPTIND - 1))

set_dependent_config

setup_host
print_status "Update packages and install python" $?

init_venv
print_status "Install and create a Python 3.6 virtual environment" $?

clone_app_repository
print_status "Remove old code and clone server code from repo" $?

setup_env
print_status "Set environment variables" $?

setup_app
print_status "Install pip dependencies" $?

run_tests
print_status "Run unit tests" $?

setup_nginx
print_status "Write nginx config files and restart server" $?

create_launch_script
print_status "Writing launch script" $?

launch_app