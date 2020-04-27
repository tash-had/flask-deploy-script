# azure-flask-deploy-script
This script will pull your server code from GitHub and deploy it on an Azure VM.

## Usage
`usage: sudo bash deploy.sh git_user git_repo git_branch git_access_token project_name test_folder app_file parent_folder vm_user env port`

### Arguments
`git_user` your GitHub username or organization name

`git_repo` the repo to deploy (should be owned by `git_user`)

`git_branch` is the branch you wish to deploy

`git_access_token` an access token with Read access to `git_repo`. **This is only required if your repo is private. If it's a public repo, set this to ":"**

`project_name` A name for this deployment (ie. my-app-dev, my-app-prod)

`test_folder` The name of the test folder

`app_file` The name of the Flask root file (ie. app.py)

`parent_folder` The folder in your repo that has the server code. **If your server code is in the root of the repo, set this to "."**

`vm_user` The username of the VM administrator

`env` the deployment environmnt (ie. 'development'). This value is used to set the `APP_CONFIG` environment variable.

`port` the port to deploy on (ie. 5000)