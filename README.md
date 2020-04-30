# azure-flask-deploy-script
This script will pull your server code from GitHub and deploy it on an Azure VM.

### [Full Article](https://medium.com/@tashadsaqif/deploying-a-flask-rest-api-to-azure-9c129b2bafee)

## Usage
`usage: deploy [-b branch] [-c token] [-t test_folder] [-m module_name] [-v variable_name] [-s subdirectory] [-e environment] [-p port] [-k kill_port|all] owner repo_name`

Selected Examples: 
- `sudo bash deploy.sh tash-had my-app`
- `sudo bash deploy.sh -s server tash-had my-app` (deploy the code in the subdirectory "server" within the repo)
- `sudo bash deploy.sh -p 8000 tash-had my-app` (deploy to port 8000)
- `sudo bash deploy.sh -b prod tash-had my-app` (deploy branch "prod")
- `sudo bash deploy.sh -k 3000 tash-had my-app` (kill deployed instance on port 3000)
- `sudo bash deploy.sh -c GITHUB_ACCESS_TOKEN tash-had my-app` (deploy code from private repo "my-app")

### Required Arguments
`owner` the GitHub username or organization name of the repo owner.

`repo_name` the repo to deploy. should be owned by `owner`. **If the repo is private, the `-c` argument must be provided**. 

### Optional Arguments

`-b` **branch:** the branch you wish to deploy. Defaults to master. 

`-c` **credential:** an access token with Read access to `repo_name`. This is only required if your repo is private.

`-t` **test folder:** the name of the test folder. Defaults to "tests".

`-m` **module name:** the name of the root Flask module file. Defaults to "app.py". 

`-v` **variable name:** the WSGI callable variable that should be in your root flask module (see `-m`). For example, if in your root file (`app.py`), if you have `a = Flask(__name__)`, then your variable name is `a`. Defaults to `app`.  

`-s` **subdirectory:** the folder in your repo that has the server code. 

`-e` **environment:** the deployment environment (ie. 'development'). This value is used to set the `APP_CONFIG` environment variable. Defaults to "development".

`-p` **port:** the port to deploy on. Defaults to "5000".

`-k` **kill:** kills the deployment running on the given port and removes associated project files. If you pass "all" as the argument to this flag, it will kill all deployed instances on the server.
