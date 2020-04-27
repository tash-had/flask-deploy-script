# azure-flask-deploy-script
This script will pull your server code from GitHub and deploy it on an Azure VM.

## Usage
`usage: deploy usage: deploy [-b branch] [-c token] [-l label] [-t test_folder] [-r root_file] [-s subdirectory] [-e environment] [-p port] git_user repo_name vm_user`

Example: `sudo bash deploy tash-had flask_demo demo_vm`

### Required Arguments
`git_user` a GitHub user or organization name

`repo_name` the repo to deploy. should be owned by `git_user`. **If the repo is private, the `-c` argument must be provided**. 

`vm_user` the administrator username given to the VM

### Optional Arguments

`-b` **branch:** the branch you wish to deploy. Defaults to master. 

`-c` **credential:** an access token with Read access to `git_repo`. This is only required if your repo is private.

`-l` **label:** a label for this deployment. Defaults to "`repo_name`-`env`". This flag is useful if you want to have multiple instances of the same build environment on a single server (otherwise the default value would overwrite previous deployment). 

`-t` **test folder:** the name of the test folder. Defaults to "tests".

`-r` **root file:** the name of the Flask root file. Defaults to "app.py". 

`-s` **subdirectory:** the folder in your repo that has the server code. 

`-e` **environment:** the deployment environmnt (ie. 'development'). This value is used to set the `APP_CONFIG` environment variable.

`-p` **port:** the port to deploy on. defaults to 5000.