#! /bin/bash

# Usage instructions at https://github.com/tash-had/azure-flask-deploy-script

# git config
GIT_REPO_OWNER=""
GIT_REPO_NAME=""
GIT_BRANCH="master"
GIT_ACCESS_TOKEN=":"
GIT_CLONE_URL=""

# project config
PROJECT_LABEL=""
PROJECT_TEST_FOLDER="tests"
PROJECT_APP_MODULE_FILE="app.py"
PROJECT_APP_VARIABLE="app"
PROJECT_PARENT_FOLDER="."

# vm config
VM_USERNAME=""
VM_HOME_DIR=""
VM_PROJECT_PATH=""
VM_NGINX_PATH='/etc/nginx'
VM_PY_PATH="/usr/bin/python3.6"

# deployment config
DEPLOYMENT_ENV="development"
DEPLOYMENT_PORT="5000"

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

function setup_venv() {
    printf "***************************************************\n\t\tSetting up Venv \n***************************************************\n"
    # Install virtualenv
    echo ======= Installing virtualenv =======
    pip3 install virtualenv

    # Create virtual environment and activate it
    echo ======== Creating virtual env =======
    virtualenv -p $VM_PY_PATH $VM_HOME_DIR/venv

    echo ======== Activating virtual env =======
    source $VM_HOME_DIR/venv/bin/activate
}

function clone_app_repository() {
    printf "***************************************************\n\t\tFetching Code \n***************************************************\n"
    # Clone and access project directory
    if [[ -d $VM_PROJECT_PATH ]]; then
        echo ======== Removing existing project files at $VM_PROJECT_PATH ========
        sudo rm -rf $VM_PROJECT_PATH
    fi
    
    cd $VM_HOME_DIR
    
    if [ $PROJECT_PARENT_FOLDER == "." ]; then
        echo ======== Cloning repo ========
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL
    else
        echo ======== Cloning repo and keeping only files "in" $PROJECT_PARENT_FOLDER ========
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL && git filter-branch --subdirectory-filter $PROJECT_PARENT_FOLDER
    fi
}

function setup_dependencies() {
    printf "***************************************************\n\t\tInstalling dependencies \n***************************************************\n"

    requirements_file="$VM_PROJECT_PATH/requirements.txt"

    if [ -f "$requirements_file" ]; then
        echo ======= requirements.txt found ========
        echo ======= Installing required packages ========
        pip3 install -r $requirements_file
    else
        echo ======= No requirements.txt found ========
        echo ======= Installing Flask and gunicorn with pip3 ========
        pip3 install Flask
        pip3 install gunicorn
    fi
}

# Create and Export required environment variable
function setup_env() {
    printf "***************************************************\n\t\tSetting up environment \n***************************************************\n"
    
    echo ======= Writing environment variables to "$VM_PROJECT_PATH/.env" ========
    sudo cat > $VM_PROJECT_PATH/.env << EOF
    export APP_CONFIG=${DEPLOYMENT_ENV}
    export FLASK_APP=${PROJECT_APP_MODULE_FILE}
EOF
    echo ======= Exporting the environment variables from "$VM_PROJECT_PATH/.env" ========
    source $VM_PROJECT_PATH/.env
}

# Install and configure nginx
function setup_nginx() {
    printf "***************************************************\n\t\tSetting up nginx \n***************************************************\n"
    echo ======= Installing nginx =======
    sudo apt-get install -y nginx

    # Configure nginx routing
    echo ======= Removing default config =======
    sudo rm -rf $VM_NGINX_PATH/sites-available/default
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/default

    echo ======= Removing previous config =======
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL

    echo ======= Creating new config file =======
    sudo touch $VM_NGINX_PATH/sites-available/$PROJECT_LABEL

    echo ======= Create a symbolic link of the config file to sites-enabled =======
    sudo ln -s $VM_NGINX_PATH/sites-available/$PROJECT_LABEL $VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL

    echo ======= Writing nginx configurations to config file =======
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
    echo ====== Restarting nginx ========
    sudo /etc/init.d/nginx restart

    echo ====== Checking nginx status ========
    sudo /etc/init.d/nginx status
}

# Add a launch script
function create_launch_script () {
    printf "***************************************************\n\t\tCreating a Launch script \n***************************************************\n"
    
    echo ====== Fetching all processes deployed on port $DEPLOYMENT_PORT ========
    gunicorn_pid=`ps ax | grep gunicorn | grep $DEPLOYMENT_PORT | awk '{split($0,a," "); print a[1]}' | head -n 1`

    echo ====== Getting module name ========
    module_name=${PROJECT_APP_MODULE_FILE%.*} 
    module_name=${module_name##*/}

    echo ====== Writing launch script ========
    sudo cat > $VM_PROJECT_PATH/launch.sh <<EOF
    #!/bin/bash
    echo ====== Starting launch script ========
    cd $VM_PROJECT_PATH

    echo ====== Processing environment variables ========
    source $VM_PROJECT_PATH/.env

    echo ====== Activating virtual environment ========
    source $VM_HOME_DIR/venv/bin/activate

    if [ ! -z $gunicorn_pid ]; then
        echo ====== Killing previously deployed instances on port $DEPLOYMENT_PORT ========
        sudo kill $gunicorn_pid
    else
        echo ====== Found no previously deployed instances on port $DEPLOYMENT_PORT ========
    fi

    echo ====== Starting new instance to run on port $DEPLOYMENT_PORT ========
    sudo $VM_HOME_DIR/venv/bin/gunicorn -b 0.0.0.0:$DEPLOYMENT_PORT --env APP_CONFIG=${DEPLOYMENT_ENV} --daemon ${module_name}:$PROJECT_APP_VARIABLE
    printf "\n\n"
    echo ====== PROBLEMS? RUN \"$VM_HOME_DIR/venv/bin/gunicorn -b 0.0.0.0:$DEPLOYMENT_PORT ${module_name}:$PROJECT_APP_VARIABLE\" FOR MORE LOGS ========
    printf "***************************************************\n\t\tDeployment Completed. \n***************************************************\n"
EOF

    echo ====== Giving user rights to execute launch script ========
    sudo chmod 744 $VM_PROJECT_PATH/launch.sh
    
    echo ====== Listing all file metadata about launch script =======
    ls -la $VM_PROJECT_PATH/launch.sh
}

# Serve the web app through gunicorn
function launch_app() {
    sudo bash $VM_PROJECT_PATH/launch.sh
}

# Run tests
function run_tests() {
    printf "***************************************************\n\t\tRunning tests \n***************************************************\n"

    test_folder="$VM_PROJECT_PATH/$PROJECT_TEST_FOLDER"
    if [[ -d $test_folder ]]; then
        echo ====== Installing nose ========
        pip install nose
        cd $test_folder
        echo ====== Starting unit tests ========
        nosetests test*
    else
        echo ====== No "test" folder found ========
    fi   
}

function check_last_step() {
    if [ $1 -ne 0 ]; then
        printf "Exiting early because the previous step has failed.\n"
        printf "***************************************************\n\t\tDeployment Failed. \n***************************************************\n"
        exit 2
    fi
}

function print_usage() {
  printf "usage: deploy usage: deploy [-b branch] [-c token] [-l label] [-t test_folder] [-m module_name] [-v variable_name] [-s subdirectory] [-e environment] [-p port] owner repo_name"
}

function set_dependent_config() {
    printf "***************************************************\n\t\tConfiguring script variables\n***************************************************\n"
    
    # set values of variables that depend on the arguments given to the script
    
    echo ====== Configuring git variables ========
    GIT_REPO_OWNER=$1
    GIT_REPO_NAME=$2
    GIT_CLONE_URL="https://$GIT_REPO_OWNER:$GIT_ACCESS_TOKEN@github.com/$GIT_REPO_OWNER/$GIT_REPO_NAME.git"
    
    PROJECT_LABEL="$GIT_REPO_NAME-$DEPLOYMENT_ENV"
    echo ====== Set PROJECT_LABEL as $PROJECT_LABEL ========
    
    VM_USERNAME=`whoami`
    VM_HOME_DIR="/home/$VM_USERNAME"

    VM_PROJECT_PATH="$VM_HOME_DIR/$PROJECT_LABEL"
    echo ====== Set project path as $VM_PROJECT_PATH ========
}

# RUNTIME

# Process flags
while getopts 'b:c:l:t:r:m:v:s:e:p:' flag; do
  case "${flag}" in
    b) GIT_BRANCH="${OPTARG}" ;;
    c) GIT_ACCESS_TOKEN="${OPTARG}" ;;
    l) PROJECT_LABEL="${OPTARG}" ;;
    t) PROJECT_TEST_FOLDER="${OPTARG}" ;;
    m) PROJECT_APP_MODULE_FILE="${OPTARG}" ;;
    v) PROJECT_APP_VARIABLE="${OPTARG}" ;;
    s) PROJECT_PARENT_FOLDER="${OPTARG}" ;;
    e) DEPLOYMENT_ENV="${OPTARG}" ;;
    p) DEPLOYMENT_PORT="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done
shift $(($OPTIND - 1))

set_dependent_config $*

setup_host
check_last_step $?

setup_venv
check_last_step $?

clone_app_repository
check_last_step $?

setup_env
check_last_step $?

setup_dependencies
check_last_step $?

run_tests
check_last_step $?

setup_nginx
check_last_step $?

create_launch_script
check_last_step $?

launch_app