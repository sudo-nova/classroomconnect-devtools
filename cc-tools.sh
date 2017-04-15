#!/bin/bash
# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it such
# as in the --default example).
# note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )
function usage(){
    echo "Usage:"
    echo "  cc-tools <commands> <flags>"
    echo ""
    echo "install           Downloads and sets up filesystem"
    echo "update            Updates the deployment directory with the latest"
    echo "                  changes from the Github repository."
    exit 0
}
function update(){
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
    
    # delete current repo
    printf "${YELLOW}Warning! This will delete your current repositor and save no changes.\n"
    printf "Proceed? (Y/N):${NC}"
    read status
    if ["$status" == "Y"] || ["$status" == "y"];
    then
        # the easier, safer way of git pulling.
        # It's harder to accidentally push to origin when this method
        # is used.
        rm -rf "classroom-connect"
        git clone "https://github.com/CalderWhite/classroom-connect.git"
        cd classroom-connect
        if [ -f ./.gitignore ];then
            git rm .gitignore
        fi
        # move files over from dev
        cp ../../developement/classroom-connect/client_secret.json .
        cp ../../developement/classroom-connect/firebase_secret.json .
        cp ../../developement/classroom-connect/django_secret.json .
        printf "${GREEN}Committing sensitive files...${NC}\n"
        # add each file, to avoid commiting other files inside the directory
        git add ./client_secret.json
        git add ./firebase_secret.json
        git add ./django_secret.json
        git commit -m "Added sensitive files" --author="UpdateBot <calderwhite1@gmail.com>"
        printf "${GREEN}Changing code to deploying version.${NC}\n"
        # changes a 1 to a 2...
        # read file
        value=$(<app/classroom.py)
        # set all replace variables
        str_to_rep="redirect_uri=j\[\"web\"\]\[\"redirect_uris\"\]\[1\]" 
        rep_str="redirect_uri=j[\"web\"][\"redirect_uris\"][2]"
        w_str="${value/$str_to_rep/$rep_str}"
        # truncate then write to file
        : > app/classroom.py
        echo -e "$w_str" >> app/classroom.py
        # git commit those changes
        git add ./app/classroom.py
        git commit -m "Changed from developement to deployment version." --author="UpdateBot <calderwhite1@gmail.com>"
        # now heroku
        printf "${GREEN}(Re) Initializing heroku remote repository...${NC}\n"
        # assumes heroku is already logged in...
        #heroku login
        heroku git:remote -a classroomconnect
        if [ $1 == true ]; then
            printf "${GREEN}Pushing to heroku...${NC}"
            git push heroku master --force
        fi
    fi
    printf "${GREEN}Finished.${NC}\n"
}
function install(){
    printf "Path to firebase_secret.json:"
    read firebase
    printf "Path to client_secret.json:"
    read client
    printf "Path to django_secret.json:"
    read django
    mkdir classroom-connect
    cd classroom-connect
    mkdir developement
    mkdir deployment
    cd developement
    git clone https://github.com/CalderWhite/classroom-connect.git
    cd ..
    cd deployment
    git clone https://github.com/CalderWhite/classroom-connect.git
    echo "Copying sensitive files into repositories."
    cd ..
    cp "${firebase}" developement/classroom-connect
    cp "${client}" developement/classroom-connect
    cp "${django}" developement/classroom-connect
}

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    install)
    echo "install"
        install
    shift # past argument
    ;;
    update)
    if test $# -gt 1; then
        if [ "${3}" == "--nopush" ] || [ "${3}" == "-n" ]; then
            cd "${2}"
            update true
        elif [ "${2}" == "--help" ] || [ "${2}" == "-h" ]; then
            echo "Usage:"
            echo "  cc-tools update <deploy dir> <flags>"
            echo "Gets the latest changes from the public github repository,"
            echo "Copies and commits sensitive files from the developement directory"
            echo "and pushes to heroku."
        else
            cd "${2}"
            update false
        fi
    else
        echo "No deployment directory specified."
        echo "Usage"
        echo "  cc-tools update <deploy dir> <flags>"
        exit 1
    fi
    shift # past argument
    ;;
    -h | --help)
    usage
    ;;
    *)
    usage
    ;;
esac
shift # past argument or value
done
# actual commands
