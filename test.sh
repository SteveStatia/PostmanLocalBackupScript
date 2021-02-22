BACKUP_COLLECTIONS=true
BACKUP_ENVIRONMENTS=false

PARENT_DIR="Postman"
WORKSPACE_DIR="$PARENT_DIR/Backups/Workspaces"

GET_WORKSPACES_URL="https://api.getpostman.com/workspaces"
GET_COLLECTIONS_URL="https://api.getpostman.com/collections"
GET_ENVIRONMENTS_URL="https://api.getpostman.com/environments"

GITHUB_USERNAME=""
GITHUB_PASS=""

APIKEY=""
API_HEADER="?apikey=$APIKEY"


#Command line arguments for downloading enviroments/colelctions
for i in "$@"
do
    case $i in
        -e)
        BACKUP_ENVIRONMENTS=true
        shift
        ;;

        -c)
        BACKUP_COLLECTIONS=true
        shift
        ;;
    esac    
done

git clone https://"$GITHUB_USERNAME":"$GITHUB_PASS"@github.com/$GITHUB_USERNAME/Postman

#Start of script
echo "Starting workspace backup..."

#Checks to see if the directory exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p $WORKSPACE_DIR 
fi

#Get the workspaces available to the api key
curl $GET_WORKSPACES_URL$API_HEADER > $PARENT_DIR/Workspaces.json
if [ "$(jq '.workspaces[]' Postman/Workspaces.json)" != "null" ]; then

    jq -r '.workspaces[].id' $PARENT_DIR/Workspaces.json > $PARENT_DIR/WorkspaceIds.txt

    while read WORKSPACE_ID; do
        #Get the workspace from the WorkSpaceIds.txt and saved to a json for parsing
        curl -s $GET_WORKSPACES_URL/$WORKSPACE_ID$API_HEADER > $PARENT_DIR/CurrentWorkspace.json

        #Creating name vairables for folder naming
        WORKSPACE_NAME=$(jq -r '.workspace.name' Postman/CurrentWorkspace.json)
        CURRENT_WORKSPACE_DIR=$WORKSPACE_DIR/"$WORKSPACE_NAME"
        if [ ! -d "$CURRENT_WORKSPACE_DIR" ]; then
            mkdir "$CURRENT_WORKSPACE_DIR"
        fi

        #Handle the workspaces' collections
        if [ "$(jq '.workspace.collections' Postman/CurrentWorkspace.json)" != "null" ]; then
            if [ ! -d "$CURRENT_WORKSPACE_DIR"/Collections ]; then
                mkdir "$CURRENT_WORKSPACE_DIR"/Collections
            fi

            #Create the file that holds the workspaces' collections ids
            jq -r '.workspace.collections[].uid' $PARENT_DIR/CurrentWorkspace.json > $PARENT_DIR/CollectionUIDList.txt
            
            #Set the directory to the current workspaces collection
            CURRENT_WORKSAPCE_COLLECTION_DIR=""$CURRENT_WORKSPACE_DIR"/Collections"

            #Start of second loop to download all of the collections from the current workspace
            while read COLLECTION_UID; do
                curl -s $GET_COLLECTIONS_URL/$COLLECTION_UID$API_HEADER > "$CURRENT_WORKSAPCE_COLLECTION_DIR"/"$COLLECTION_UID".json 

                #Renaming the collections from their UID to their Postman Collection names 
                COLLECTIONNAME=$(jq -r '.collection.info.name' "$CURRENT_WORKSAPCE_COLLECTION_DIR"/"$COLLECTION_UID".json)
                mv "$CURRENT_WORKSAPCE_COLLECTION_DIR"/"$COLLECTION_UID".json "$CURRENT_WORKSAPCE_COLLECTION_DIR"/"$COLLECTIONNAME".json

            done < $PARENT_DIR/CollectionUIDList.txt
        fi
        
        #If the script is run with -e the environments will be downloaded as well
        if [ $BACKUP_ENVIRONMENTS = true ]; then
            #Handle the workspaces' environments
            if [ "$(jq '.workspace.environments' Postman/CurrentWorkspace.json)" != "null" ]; then
                if [ ! -d "$CURRENT_WORKSPACE_DIR"/Environments ]; then
                    mkdir "$CURRENT_WORKSPACE_DIR"/Environments
                fi

                #Create the file that holds the workspaces' environment ids
                jq -r '.workspace.environments[].uid' $PARENT_DIR/CurrentWorkspace.json > $PARENT_DIR/EnivronmentUIDList.txt
                
                #Set the directory to the current workspaces environment
                CURRENT_WORKSPACE_ENVIRONMENT_DIR=""$CURRENT_WORKSPACE_DIR"/Environments"

                while read ENVIRONMENT_ID; do
                    curl -s $GET_ENVIRONMENTS_URL/$ENVIRONMENT_ID$API_HEADER > "$CURRENT_WORKSPACE_ENVIRONMENT_DIR"/"$ENVIRONMENT_ID".json

                    ENVIRONMENT_NAME=$(jq -r '.environment.name' "$CURRENT_WORKSPACE_ENVIRONMENT_DIR"/"$ENVIRONMENT_ID".json)
                    mv "$CURRENT_WORKSPACE_ENVIRONMENT_DIR"/"$ENVIRONMENT_ID".json "$CURRENT_WORKSPACE_ENVIRONMENT_DIR"/"$ENVIRONMENT_NAME".json

                done < $PARENT_DIR/EnivronmentUIDList.txt
            fi
        fi

    done < $PARENT_DIR/WorkspaceIds.txt

    #Remove all the temp files
    rm $PARENT_DIR/CurrentWorkspace.json
    rm $PARENT_DIR/WorkspaceIds.txt
    rm $PARENT_DIR/CollectionUIDList.txt
    rm $PARENT_DIR/EnivronmentUIDList.txt
fi


#------------------------------------------------------------------------------------------------------------#
#GIT SECTION, Uncomment to push to git after local backup

# cd Postman
# git init
# git add .
# TIME=$(date +"%r")
# git commit -m "Nightly backup $TIME"
# PUSH_COMMAND="https://"$GITHUB_USERNAME":"$GITHUB_PASS"@github.com/$GITHUB_USERNAME/Postman"
# git push $PUSH_COMMAND
# cd ..
# rm -rf Postman/
