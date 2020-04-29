# azure-flask-deploy-script
This script will pull your server code from GitHub and deploy it on an Azure VM.

### [Full Article](https://medium.com/@tashadsaqif/deploying-a-flask-rest-api-to-azure-9c129b2bafee)

## Usage
`usage: deploy usage: deploy [-b branch] [-c token] [-l label] [-t test_folder] [-m module_name] [-v variable_name] [-s subdirectory] [-e environment] [-p port] git_user repo_name`

Example: `sudo bash deploy tash-had flask_demo`

### Required Arguments
`owner` the GitHub username or organization name of the repo owner.

`repo_name` the repo to deploy. should be owned by `owner`. **If the repo is private, the `-c` argument must be provided**. 

### Optional Arguments

`-b` **branch:** the branch you wish to deploy. Defaults to master. 

`-c` **credential:** an access token with Read access to `repo_name`. This is only required if your repo is private.

`-l` **label:** a label for this deployment. Defaults to "`repo_name`-`env`" (ie. "my_app-development"). This flag is useful if you want to have multiple instances of the same build environment on a single server (otherwise the default value would overwrite previous deployment).

`-t` **test folder:** the name of the test folder. Defaults to "tests".

`-m` **module name:** the name of the root Flask module file. Defaults to "app.py". 

`-v` **variable name:** the WSGI callable variable that should be in your root flask module (see `-m`). For example, if in your root file (`app.py`), if you have `a = Flask(__name__)`, then your variable name is `a`. Defaults to `app`.  

`-s` **subdirectory:** the folder in your repo that has the server code. 

`-e` **environment:** the deployment environment (ie. 'development'). This value is used to set the `APP_CONFIG` environment variable. Defaults to "development".

`-p` **port:** the port to deploy on. Defaults to "5000".
