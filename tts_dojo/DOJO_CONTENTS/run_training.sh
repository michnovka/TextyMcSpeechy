#!/bin/bash
clear
# Get voice name from directory name
DOJO_NAME=$(awk -F'/' '{print $(NF)}' <<< "$PWD")
VOICE_NAME=$(awk -F'/' '{print $(NF)}' <<< "$PWD" | sed 's/_dojo$//')
DOJO_DIR="."

#path to expected location of dataset configuration 
DATASET_CONF="target_voice_dataset/dataset.conf"
has_linked_dataset=false

# Prevent execution in DOJO_CONTENTS - used only when making new dojos.  
this_dir=$(pwd)
dir_only=$(basename "$this_dir")
if [ $dir_only = "DOJO_CONTENTS" ]; then
   echo -e "${RED}The DOJO_CONTENTS folder is used as a template for other dojos."
   echo -e "You should not run any scripts inside of DOJO_CONTENTS"
   echo 
   echo -e "Instead, run 'newdojo.sh' <voice name> to create a new dojo"
   echo -e "and train your models in that folder." 
   echo
   echo -e "Exiting${RESET}"
   exit 1
fi

# Set up text coloring.
color_file="scripts/.colors"
if [ -e $color_file ]; then
    source $color_file
else
    echo "$0 - color_file not found"
    echo "     expected location: $settings_file"
    echo 
    echo "exiting"
    exit 1
fi

 
echo "Starting Docker container textymcspeechy-piper"
cd ../.. #docker-conf.yml is in TextyMcSpeechy dir, 2 levels up from <name>_dojo
# pass PUID and PGID to docker-compose.yml (prepend as environment vars) 
# Ensures current user will have rights to files created by docker container in mounted folder
export TMS_USER_ID=$(id -u)
export TMS_GROUP_ID=$(id -g)
echo
TMS_USER_ID="${TMS_USER_ID}" TMS_GROUP_ID="${TMS_GROUP_ID}" docker compose up -d
echo
echo "Press <Enter> to continue"
read
cd tts_dojo/$DOJO_NAME # return to this dojo after starting docker

set -e # Exit immediately if any command returns a nonzero exit code

check_exit_status() {
# Checks the return code of the last executed command
    if [ $? -ne 0 ]; then
        echo "${RED}An error occurred. $0 is stopping.${RESET}"
        exit 1
    fi
}


dir_size_in_gb() {
# Calculates the total size of a directory in GB
    local dir_path="$1"
    if [ -d "$dir_path" ]; then
        local size_in_kb=$(du -sk "$dir_path" | cut -f1)
        local size_in_gb=$(echo "scale=2; $size_in_kb / 1024 / 1024" | bc)
        printf "%7.2f\n" "$size_in_gb"
    else
        echo "Invalid directory"
    fi
}

check_for_linked_dataset(){
# Checks whether current dojo is already associated with a voice dataset
    has_linked_dataset=false   
    if [ -e "$DATASET_CONF" ]; then
        dataset_path=$(dirname $(readlink -f "$DATASET_CONF"))
        # check for .QUALITY file created by previous run
        quality_path="$DOJO_DIR"/"target_voice_dataset/.QUALITY"
        if [ ! -e "$quality_path" ]; then
            echo "        Dataset not linked correctly - File missing: $quality_path"
            echo "        Dataset must be reconfigured."
            return 1
        fi
            
        quality=$(cat $quality_path)
        if [ "$quality" = "L" ]; then
            quality_str="low"
        elif [ "$quality" = "M" ]; then
            quality_str="medium"
        elif [ "$quality" = "H" ]; then
            quality_str="high"
        fi
   
        source $DATASET_CONF # reads variables stored in dataset.conf
        echo "        Found linked dataset."
        has_linked_dataset=true
    fi
}
    
show_linked_dataset(){
        echo
        echo "        This dojo is currently configured to use the following dataset"
        echo
        echo "        voice name            : $NAME"
        echo "        description           : $DESCRIPTION"
        echo "        voice type            : $DEFAULT_VOICE_TYPE"
        echo "        dataset location      : $dataset_path"
        echo 
        echo "        Dojo-specific settings"
        echo
        echo "        quality               : $quality_str"
}

run_link_dataset(){
    bash "scripts/link_dataset.sh"
}

confirm_or_change_dataset(){
    echo
    echo -ne "        Do you wish to use this dataset with these settings (Y/N):  "
    read choice
    choice=${choice^^}
    if [ "$choice" = "N" ]; then
        has_linked_dataset="false"
    fi
}

# MAIN PROGRAM

clear
echo -e "    ${BOLD_PURPLE}TextyMcspeechy TTS Dojo${RESET}"
echo
echo -e "    Checking dojo for linked dataset"
check_for_linked_dataset

if [ "$has_linked_dataset" = "true" ]; then
    show_linked_dataset
    confirm_or_change_dataset
fi

if [ "$has_linked_dataset" = "false" ]; then
    echo
    echo "        Press <Enter> to configure a dataset to use in this dojo."
    run_link_dataset
fi

echo -e "\nDataset linked successfully.  Press <Enter> to begin preprocessing."
read
echo -e "\n      running scripts/preprocess_dataset.sh"
echo

# Execute the preprocessing script
bash ./scripts/preprocess_dataset.sh
check_exit_status  

# Run the training session
bash ./scripts/train.sh
check_exit_status 

# Show exit message after training 
clear
echo
echo "Thank you for using TextyMcSpeechy."
echo
echo
echo -e "Reminder: There are currently ${CYAN}$(dir_size_in_gb $PWD) GB${RESET} of files in ${GREEN}$PWD${RESET}:"
echo -e "${CYAN}$(dir_size_in_gb ./voice_checkpoints) GB in ${GREEN}voice_checkpoints${RESET}"
echo -e "${CYAN}$(dir_size_in_gb ./tts_voices) GB in ${GREEN}tts_voices${RESET}"
echo -e "${CYAN}$(dir_size_in_gb ./archived_checkpoints) GB in ${GREEN}archived_checkpoints${RESET}"
echo -e "${CYAN}$(dir_size_in_gb ./archived_tts_voices) GB in ${GREEN}archived_tts_voices${RESET}"
echo
echo -e "Please remember to delete any files you don't need."
echo 
echo "Shutting down textmcspeechy-piper docker container, please wait..."
docker container stop textymcspeechy-piper >/dev/null     
echo "Done."
echo
exit 0
