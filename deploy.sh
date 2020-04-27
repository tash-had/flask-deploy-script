#! /bin/bash

# git config
GIT_USERNAME=$1
GIT_REPO_NAME=$2
GIT_BRANCH=$3
GIT_ACCESS_TOKEN=$4 # set to : if public
GIT_CLONE_URL="https://$GIT_USERNAME:$GIT_ACCESS_TOKEN@github.com/$GIT_USERNAME/$GIT_REPO_NAME.git"

# project config
PROJECT_NAME=$5
PROJECT_TEST_FOLDER=$6
PROJECT_APP_FILE=$7
PROJECT_PARENT_FOLDER=$8

# vm config
VM_USERNAME=$9
VM_HOME_DIR="/home/$VM_USERNAME"
VM_PROJECT_PATH="$VM_HOME_DIR/$PROJECT_NAME"
VM_NGINX_PATH="/etc/nginx"
VM_PY_PATH="/usr/bin/python3.6"

# deployment config
DEPLOYMENT_ENV=${10}
DEPLOYMENT_PORT=${11}

EXPECTED_ARGS=11

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
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_NAME && cd $PROJECT_NAME
    else
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_NAME && cd $PROJECT_NAME && git filter-branch --subdirectory-filter $PROJECT_PARENT_FOLDER
    fi
}

function setup_app() {
    printf "***************************************************\n    Installing App dependencies \n***************************************************\n"
    # Install required packages
    echo ======= Installing required packages ========
    pip3 install -r $VM_PROJECT_PATH/requirements.txt

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
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/$PROJECT_NAME
    sudo touch $VM_NGINX_PATH/sites-available/$PROJECT_NAME

    echo ======= Create a symbolic link of the file to sites-enabled =======
    sudo ln -s $VM_NGINX_PATH/sites-available/$PROJECT_NAME $VM_NGINX_PATH/sites-enabled/$PROJECT_NAME

    echo ======= Replace config file =======
    sudo cat >$VM_NGINX_PATH/sites-enabled/$PROJECT_NAME <<EOL
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
    pip install nose
    cd $VM_PROJECT_PATH/$PROJECT_TEST_FOLDER
    nosetests test*
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


######################################################################
########################      RUNTIME       ##########################
######################################################################

if [ $# -lt $EXPECTED_ARGS ]; 
   then
       printf "Expected %d args, got %d\n" $EXPECTED_ARGS $#
       printf "Received %s %s %s %s %s %s %s %s %s %s\n" $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11}
       printf "usage: sudo bash deploy git_user git_repo git_branch git_access_token project_name test_folder app_file parent_folder vm_user env port\n"
       print_status "Checking arguments" 1
fi

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