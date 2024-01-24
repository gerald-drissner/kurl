#!/bin/bash

# Script Name: kurl.sh
# Version: 1.0.0
# Purpose: This script interacts with the YOURLS API to create, delete, and manage short URLs.
# Author: Gerald Drißner
# Github: https://github.com/gerald-drissner
# Last Update: 2024-01-21
# License: MIT License
#
# Copyright (c) 2024 Gerald Drißner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRAdrissner.meCT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# INSTALLATION:
# 1. Download the script and save it to your local machine.
# 2. Make the script executable by running the command 'sudo chmod +x kurl.sh'.
# 3. Move the script to a directory in your PATH with the command 'sudo mv kurl.sh /usr/local/bin'.
#    Now, you can run the script from anywhere in the terminal by typing 'kurl.sh'.

# About

VERSION="1.0"
APP_NAME="kurl.sh"
GITHUB_LINK="https://github.com/gerald-drissner"
CONTACT_EMAIL="yourls@drissner.me"

# Colors
RED="\e[1;31m"
GRAY="\e[1;90m"
GREEN="\e[1;32m"
ORANGE="\e[1;33m"
YELLOW="\e[38;5;222m"
BLUE="\e[1;34m"
MAGENTA="\e[1;35m"
CYAN="\e[1;36m"
WHITE="\e[1;37m"
RESET="\e[0m"
BOLD_WHITE_ON_BLACK="\e[1;97;100m"
BOLD_BRIGHT_WHITE="\e[1;97m"

# Formatting
BOLD="\e[1m"
ITALIC="\e[3m"
BOLDITALIC="\e[1;3m"


# Set the path to the configuration file
CONFIG_FILE="$HOME/.config/yourls-cli/config.cfg"

# Function to check the connection to the YOURLS API
check_connection() {
    # Use the YOURLS API to check if the host and key are valid
    response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=db-stats&format=json")

    # If the response is empty, there is no connection
    if [ -z "$response" ]; then
        return 1
    fi

    # Extract the 'message' field from the response
    message=$(echo "$response" | jq -r .message)

    # If the message is not 'success', there is a connection error
    if [ "$message" != "success" ]; then
        return 1
    fi

    # Connection is successful
    return 0
}

CONNECTION_OK=$(check_connection)

# Function to handle connection errors
handle_connection_error() {
    echo -e "${RED}There was a connection error.${RESET} Would you like to re-enter the configuration data? (y/n)"
    read answer
    if [ "$answer" = "y" ]; then
        if [ -f "$CONFIG_FILE" ]; then  # Check if the configuration file exists
            rm "$CONFIG_FILE"  # Remove the configuration file
        fi
        echo -e "${GRAY}Let's try again...${RESET}"
        echo
        prompt_for_credentials  # Prompt the user to enter the configuration data again
        echo
    fi
}

# Function to check if the required dependencies are installed
# call check_dependencies true if you want to print out also when the required tools are installed.
check_dependencies() {
    verbose=${1:-false}  # If no argument is provided, default to false
    verbose=$(echo "$verbose" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    echo
    for cmd in curl jq; do
        if command -v $cmd &> /dev/null; then
            if [ "$verbose" == "true" ]; then
                echo -e "$cmd: ${GREEN}OK${RESET}"
            fi
        else
            echo -e "${ORANGE}Some dependencies are missing...${RESET}"
            echo
            echo -e "${RED}$cmd is not installed.${RESET} Attempting to install..."
            if [ -f /etc/debian_version ]; then
                sudo apt-get install $cmd  # Install on Debian-based systems
            elif [ -f /etc/redhat-release ]; then
                sudo dnf install $cmd  # Install on Red Hat-based systems
            elif [ -f /etc/arch-release ]; then
                sudo pacman -S $cmd  # Install on Arch Linux
            else
                echo "Unsupported distribution. Please install $cmd manually."
                exit 1
            fi
        fi
    done

    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        if command -v wl-copy &> /dev/null; then
            if [ "$verbose" == "true" ]; then
                echo -e "wl-copy: ${GREEN}OK${RESET}"
            fi
        else
            echo -e "wl-copy: ${RED}MISSING${RESET}"
            echo "Do you want to install it now? (y/n)"
            read INSTALL
            if [ "$INSTALL" == "y" ]; then
                if [ -f /etc/debian_version ]; then
                    sudo apt-get install wl-clipboard  # Install on Debian-based systems
                elif [ -f /etc/fedora-release ]; then
                    sudo dnf install wl-clipboard  # Install on Fedora-based systems
                elif [ -f /etc/arch-release ]; then
                    sudo pacman -S wl-clipboard  # Install on Arch Linux
                else
                    echo "Unsupported distribution. Please install wl-clipboard manually."
                    exit 1
                fi
            else
                echo "wl-copy is required for this script to run. Please install it and try again."
                exit 1
            fi
        fi
    else
        if command -v xclip &> /dev/null || command -v xsel &> /dev/null; then
            if [ "$verbose" == "true" ]; then
                echo -e "xclip/xsel: ${GREEN}OK${RESET}"
            fi
        else
            echo -e "xclip/xsel: ${RED}MISSING${RESET}"
            echo "Do you want to install it now? (y/n)"
            read INSTALL
            if [ "$INSTALL" == "y" ]; then
                if [ -f /etc/debian_version ]; then
                    sudo apt-get install xclip xsel  # Install on Debian-based systems
                elif [ -f /etc/fedora-release ]; then
                    sudo dnf install xclip xsel  # Install on Fedora-based systems
                elif [ -f /etc/arch-release ]; then
                    sudo pacman -S xclip xsel  # Install on Arch Linux
                else
                    echo "Unsupported distribution. Please install xclip/xsel manually."
                    exit 1
                fi
            else
                echo "xclip/xsel is required for this script to run. Please install it and try again."
                exit 1
            fi
        fi
    fi
}
# Function to process a given URL
process_url() {
    local URL=$1
    local CALLBACK=$2
    local keyword

    if [[ $URL =~ ^http[s]?:// ]]; then
        if [[ $URL == *"$YOURLS_HOST"* ]]; then
            keyword=$(basename "$URL")
            $CALLBACK "$keyword"
        else
            response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=shorturl&url=$URL&format=json")
            json=$(echo "$response" | jq -r .)
            status=$(echo "$json" | jq -r .status)
            if [ "$status" == "fail" ]; then
                shorturl=$(echo "$json" | jq -r .shorturl)
                keyword=$(basename "$shorturl")
                $CALLBACK "$keyword"
            else
                echo -e "${RED}No short URL found for $URL${RESET}"
                exit 1
            fi
        fi
    fi
}

# Function to print the output based on the format
print_output() {
    local format=$1

    # Make the API call with the appropriate format
    response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=shorturl&url=$URL&keyword=$KEYWORD&title=$TITLE&format=$format")

    if [ "$format" == "simple" ]; then
        # Parse the JSON response and extract the short URL
        echo
    elif [ "$format" == "xml" ] || [ "$format" == "json" ] || [ "$format" == "jsonp" ]; then
        echo -e "${GRAY}$response${RESET}"
    fi
}

# Function to print the statistics for a given short URL
print_url_statistics() {
    local keyword=$1

    # Send a request to the YOURLS API to get statistics for the short URL
    local response=$(curl -L -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=url-stats&shorturl=$keyword&format=json")
    local json=$(echo "$response" | jq -r .)
    local status=$(echo "$json" | jq -r .message)  # Extract the 'message' field

    if [ "$status" != "success" ]; then
        # Print the error message in red
        echo -e "${RED}Failed to fetch statistics for $keyword${RESET}"
        echo -e "${RED}Response: $response${RESET}" 
    else
        # Extract and print the statistics
        local shorturl=$(echo "$json" | jq -r .link.shorturl)
        local longurl=$(echo "$json" | jq -r .link.url)
        local date=$(echo "$json" | jq -r .link.timestamp)
        local clicks=$(echo "$json" | jq -r .link.clicks)

        # Print the statistics in a formatted manner
        echo
        echo -e "${GRAY}Statistics for:${RESET}\t${BOLD}$shorturl${RESET}"
        echo -e "${GRAY}Long URL:${RESET}\t${BOLD}$longurl${RESET}"
        echo -e "${GRAY}Date created:${RESET}\t${BOLD}$date${RESET}"
        echo -e "${GRAY}Clicks:${RESET}\t\t${BOLD}$clicks${RESET}"
        echo
    fi
}

# Function to delete a short URL
delete_short_url() {
    keyword=$1
    response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=delete&shorturl=$keyword&format=json")
    json=$(echo "$response" | jq -r .)
    status=$(echo "$json" | jq -r .message)
    if [ "$status" != "success: deleted" ]; then
        echo -e "${RED}Failed to delete $shorturl${RESET}"  
    else
        echo
        echo -e "${GREEN}$URL successfully deleted $shorturl${RESET}"  
        echo
    fi
}
# Function to validate URL for option
validate_url_for_option() {
    local url=$1
    if [[ $url =~ ^https?:// ]] || [[ $url =~ ^ftp:// ]] || [[ $url =~ ^file:// ]] || [[ $url =~ ^mailto: ]]; then
        if ! validate_url "$url"; then
            echo
            echo -e "${RED}Invalid URL. Please enter a valid URL starting with http://, https://, ftp://, file://, or mailto:${RESET}"  
            echo
            exit 1
        fi
    fi
}


# Function to validate URL for shortening
validate_url_for_shortening() {
    local url=$1
    if [[ $url =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,} ]]; then
        if ! validate_url "$url"; then
            echo
            echo -e "${RED}Invalid URL. Please enter a valid URL starting with http:// or https://${RESET}"  
            echo
            exit 1
        fi
    fi
}


# Function to process a given URL
process_url() {
    local URL=$1
    local CALLBACK=$2
    local keyword

    if [[ $URL =~ ^http[s]?:// ]]; then
        if [[ $URL == *"$YOURLS_HOST"* ]]; then
            keyword=$(basename "$URL")
            $CALLBACK "$keyword"
        else
            response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=shorturl&url=$URL&format=json")
            json=$(echo "$response" | jq -r .)
            status=$(echo "$json" | jq -r .status)
            if [ "$status" == "fail" ]; then
                shorturl=$(echo "$json" | jq -r .shorturl)
                keyword=$(basename "$shorturl")
                $CALLBACK "$keyword"
            else
                echo -e "${RED}No short URL found for $URL${RESET}"
                exit 1
            fi
        fi
    else
        keyword=$URL
        response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=expand&shorturl=$URL&format=json")
        json=$(echo "$response" | jq -r .)
        errorCode=$(echo "$json" | jq -r .errorCode)
        if [ "$errorCode" == "404" ]; then
            echo
            echo -e "${RED}Short URL not found for keyword: $URL${RESET}"
            echo
            exit 1
        else
            $CALLBACK "$keyword"
        fi
    fi
}


# Function to check a URL and print its statistics
check_url() {
    local URL=$1
    local MESSAGE=$2

    echo
    echo -e "${ORANGE}$MESSAGE $URL...${RESET}"
    if process_url "$URL" print_url_statistics; then
        print_output "$format"
    else
        # Short URL not found, display error message
        echo -e "${RED}Short URL not found for keyword: $URL${RESET}"
        print_output "$format"
        exit 1
    fi
}


# Function to delete a URL from the database
function_delete_from_database() {
    local URL=$1
    local MESSAGE="Deleting"

    if ! process_url "$URL" print_url_statistics; then
        # Short URL not found, display error message
        echo
        echo -e "${RED}Short URL not found for keyword: $URL${RESET}"
        print_output "$format"
        exit 1
    else
        echo
        read -p "Are you sure you want to delete $URL? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            echo "$MESSAGE $URL..."
            if process_url "$URL" delete_short_url; then
                print_output "$format"
            else
                # Failed to delete short URL, display error message
                echo -e "${RED}Failed to delete short URL: $URL${RESET}"
                print_output "$format"
                exit 1
            fi
        fi
    fi
}


# Function to expand a short URL
expand_short_url() {
    local keyword=$1
    # Send a request to the YOURLS API to expand the short URL
    local response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=expand&shorturl=$keyword&format=json")
    local longurl=$(echo "$response" | jq -r .longurl)
    echo -e "${BOLD_WHITE_ON_BLACK}Expanded URL:${RESET}\t${BOLD_BRIGHT_WHITE}$longurl${RESET}"
    print_output "$format"
}


# Function to validate a URL
validate_url() {
    if [[ $1 =~ ^https?:// ]] || [[ $1 =~ ^ftp:// ]] || [[ $1 =~ ^file:// ]] || [[ $1 =~ ^mailto: ]]; then
        return 0  # URL is valid
    else
        return 1  # URL is invalid
    fi
}


# Function to validate URL if needed
validate_url_if_needed() {
    local url=$1
    local option=$2

    if [ ! -z "$option" ]; then
        if [ -z "$url" ]; then
            # No URL provided, display error message
            echo -e "${RED}Please provide a keyword or short URL.${RESET}"  
            exit 1
        elif [[ $url =~ ^https?:// ]]; then
            if ! validate_url "$url"; then
                # Invalid URL, display error message
                echo
                echo -e "${RED}Invalid URL. Please enter a valid URL starting with http:// or https://${RESET}"  
                echo
                exit 1
            fi
        elif [[ "$url" == *"$YOURLS_HOST"* ]]; then
            # Trying to shorten a short URL, display error message
            echo -e "${RED}Sorry, you cannot shorten a short URL${RESET}"  
            exit 1
        else
            url="$YOURLS_HOST/$url"
        fi
    fi
}

# Function to validate URL for option
validate_url_for_option() {
    local url=$1
    if [[ $url =~ ^https?:// ]] || [[ $url =~ ^ftp:// ]] || [[ $url =~ ^file:// ]] || [[ $url =~ ^mailto: ]]; then
        if ! validate_url "$url"; then
            echo
            echo -e "${RED}Invalid URL. Please enter a valid URL starting with http://, https://, ftp://, file://, or mailto:${RESET}"  
            echo
            exit 1
        fi
    fi
}


# Function to validate URL for shortening
validate_url_for_shortening() {
    local url=$1
    if [[ $url =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,} ]]; then
        if ! validate_url "$url"; then
            echo
            echo -e "${RED}Invalid URL. Please enter a valid URL starting with http:// or https://${RESET}"  
            echo
            exit 1
        elif [[ "$url" == *"$YOURLS_HOST"* ]]; then
            echo -e "${RED}URL is a short URL.${RESET}"  
            return 1  # Return status 1 if the URL is a short URL
        fi
    else
        echo
        echo -e "${RED}Invalid URL. Please enter a valid URL starting with http:// or https://${RESET}"  
        echo
        exit 1
    fi
    return 0  # Return status 0 if the URL is not a short URL
}


# Function to check if the keyword exists in the database
check_keyword_exists() {
    local keyword=$1
    # Check if the keyword exists in the database
    response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=url-stats&shorturl=$keyword&format=json")
    json=$(echo "$response" | jq -r .)
    status=$(echo "$json" | jq -r .status)
    message=$(echo "$json" | jq -r .message)
    if [ "$status" == "fail" ]; then
            if [[ "$message" == *"Error: short URL not found"* ]]; then
            echo -e "${RED}Sorry, you cannot shorten a short URL${RESET}"  
            return 1
        else
            echo -e "${RED}You cannot shorten a short URL${RESET}"  
            return 1
        fi
    else
        return 0
    fi
}


# START MAIN SCRIPT
if [[ "$1" != "-i" && "$1" != "--check" ]]; then
    check_dependencies false # We check if all necessary tools are installed
fi



# Check if the configuration file exists, if not, it's the first run
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${GRAY}|${ORANGE}                   SETUP AND CONFIGURATION              ${GRAY}|"
    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${RESET}"
    echo "This is the first start of the script ${APP_NAME}. Please enter your YOURLS credentials."
    echo
    fi


# Function to prompt the user for the YOURLS host and key
prompt_for_credentials() {
    while true; do
        echo -e "${CYAN}Enter the YOURLS host${RESET} starting with http:// or https://"
        read YOURLS_HOST

        # Ensure the host URL does not end with a trailing slash
        last_char="${YOURLS_HOST: -1}"
        if [ "$last_char" == "/" ]; then
            YOURLS_HOST="${YOURLS_HOST: : -1}"
        fi

        # Check if the host URL starts with http:// or https://
        if [[ "$YOURLS_HOST" != http://* ]] && [[ "$YOURLS_HOST" != https://* ]]; then
            echo -e "${RED}The YOURLS host must start with http:// or https://. Please try again.${RESET}"
            echo
            continue
        fi
        echo
        echo -e "${CYAN}Enter the YOURLS signature key${RESET}:"
        echo -e "${GRAY}${ITALIC}You can find your signature ("API key") when you go to ${YOURLS_HOST}/admin/tools.php while logged-in.${RESET}"

        read YOURLS_KEY

        # Use the YOURLS API to check if the host and key are valid
            response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=db-stats&format=json")
            if [ $? -ne 0 ]; then
            handle_connection_error
            continue
        fi
        message=$(echo "$response" | jq -r .message)
        errorCode=$(echo "$response" | jq -r .errorCode)

        if [ "$message" = "Please log in" ] || [ "$errorCode" = "403" ]; then
            echo -e "${RED}Invalid YOURLS host or key. Please try again.${RESET}"
            handle_connection_error
            continue
        fi
         # Ask the user if they want to automatically copy shortened URLs to the clipboard
        while true; do
        echo
            echo -e "${CYAN}Do you want to automatically copy shortened URLs to the clipboard? [y/n]: ${RESET}"
            read AUTO_COPY
            if [ "$AUTO_COPY" = "y" ] || [ "$AUTO_COPY" = "n" ] || [ -z "$AUTO_COPY" ]; then
                break
            else
                echo "Invalid input. Please enter 'y' or 'n'."
            fi
        done

        # If the user just pressed enter, default to 'y'
        if [ -z "$AUTO_COPY" ]; then
            AUTO_COPY="y"
        fi

        # Check if the user wants to autocopy and if the necessary tools are installed
        if [ "$AUTO_COPY" == "y" ]; then
            if [ "$XDG_SESSION_TYPE" == "wayland" ]; then
                if ! command -v wl-copy &> /dev/null; then
                    echo "wl-clipboard is not installed. Do you want to install it now? (y/n)"
                    read INSTALL
                    if [ "$INSTALL" == "y" ]; then
                        if [ -f /etc/debian_version ]; then
                            sudo apt-get install wl-clipboard
                        elif [ -f /etc/fedora-release ]; then
                            sudo dnf install wl-clipboard
                        elif [ -f /etc/arch-release ]; then
                            sudo pacman -S wl-clipboard
                        else
                            echo "Unsupported distribution. Please install wl-clipboard manually."
                            AUTO_COPY="n"
                        fi
                    else
                        AUTO_COPY="n"
                    fi
                fi
            else
                if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
                    echo "Neither xclip nor xsel is installed. Do you want to install xclip now? (y/n)"
                    read INSTALL
                    if [ "$INSTALL" == "y" ]; then
                        if [ -f /etc/debian_version ]; then
                            sudo apt-get install xclip
                        elif [ -f /etc/fedora-release ]; then
                            sudo dnf install xclip
                        elif [ -f /etc/arch-release ]; then
                            sudo pacman -S xclip
                        else
                            echo "Unsupported distribution. Please install xclip manually."
                            AUTO_COPY="n"
                        fi
                    else
                        AUTO_COPY="n"
                    fi
                fi
            fi
        fi

        # Save the values to the config file
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "YOURLS_HOST=\"$YOURLS_HOST\"" > "$CONFIG_FILE"
        echo "YOURLS_KEY=\"$YOURLS_KEY\"" >> "$CONFIG_FILE"
        echo "AUTO_COPY=\"$AUTO_COPY\"" >> "$CONFIG_FILE"

        # If we reach this point, the credentials are valid
        echo
        echo -e "${ORANGE}Configuration is saved to file: $(dirname "$CONFIG_FILE")${RESET}"
        echo
        check_dependencies false

        break
    done
}


# Read configuration from file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"

    # Check the AUTO_COPY value
    if [ "$AUTO_COPY" != "y" ] && [ "$AUTO_COPY" != "n" ]; then
        echo "Invalid AUTO_COPY value in configuration file. Setting to 'n'."
        AUTO_COPY="n"
        sed -i "/^AUTO_COPY=/c\AUTO_COPY=\"$AUTO_COPY\"" $CONFIG_FILE
    fi
fi

# Call the function if the configuration file does not exist or if the connection fails
if [ ! -f "$CONFIG_FILE" ]; then
    prompt_for_credentials
elif ! check_connection; then
    echo -e "${RED}Connection failed. Please reenter your credentials.${RESET}"
    prompt_for_credentials
fi

# echo "Checking connection and credentials..."
if check_connection; then
    :
else
    echo -e "${RED}Connection failed. Please reenter your credentials.${RESET}"
    prompt_for_credentials
fi

yourls_help() {
    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${GRAY}|            ${ORANGE}${BOLD}${ITALIC}kurl${RESET}  -  ${BLUE}SHORT URLS WITH YOURLS${RESET}             ${GRAY}|"
    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${RESET}"
    echo
    echo -e "${CYAN}To SHORTEN a URL:${RESET}"  
    echo -e " ${0##*/} <url>"
    echo -e " ${0##*/} <url> -k <KEYWORD> -t <TITLE>"
    echo
    echo -e "${CYAN}To MANAGE a SHORT URL:${RESET}"  
    echo "  ${0##*/} <shorturl> -s <STATISTICS> -e <EXPAND> -d <DELETE>"
    echo
    echo -e "${CYAN}OPTIONS for shortening a URL:${RESET}"  
    echo -e " ${YELLOW}-k${RESET} | ${YELLOW}--keyword <KEYWORD>${RESET}   Custom keyword"
    echo -e " ${YELLOW}-t${RESET} | ${YELLOW}--title <TITLE>${RESET}       Custom title"
    echo
    echo -e "${CYAN}OPTIONS for managing a SHORT URL:${RESET}"  
    echo -e " ${YELLOW}-s${RESET} | ${YELLOW}--statistics <URL>${RESET}    Get statistics for a URL"
    echo -e " ${YELLOW}-e${RESET} | ${YELLOW}--expand <URL>${RESET}        Expand a short URL"
    echo -e " ${YELLOW}-d${RESET} | ${YELLOW}--delete <URL>${RESET}        Delete a short URL"
    echo
    echo -e "${CYAN}OPTIONS for your YOURLS database:${RESET}"  
    echo -e " ${YELLOW}-g${RESET} | ${YELLOW}--global${RESET}              Get global statistics"
    echo -e " ${YELLOW}-l${RESET} | ${YELLOW}--list${RESET}                List all short URLs"
    echo
    echo -e "${CYAN}SETUP and MAINTAINANCE:${RESET}"  
    echo -e " ${YELLOW}-i${RESET} | ${YELLOW}--check${RESET}               Check dependencies"
    echo -e " ${YELLOW}-f${RESET} | ${YELLOW}--format <FORMAT>${RESET}     Output format (json, xml, simple)"
    echo -e " ${YELLOW}-c${RESET} | ${YELLOW}--change-config${RESET}       Change configuration of YOURLS server"
    echo -e " ${YELLOW}-h${RESET} | ${YELLOW}--help${RESET}                Show this screen"
    echo -e " ${YELLOW}-v${RESET} | ${YELLOW}--version${RESET}             Display script version and author information"
    echo
    echo -e " ${YELLOW}--autocopy-on${RESET}              Enable auto-copy"
    echo -e " ${YELLOW}--autocopy-off${RESET}             Disable auto-copy"
    echo
    exit 1
}

# If no param or param is -h|--help
if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    yourls_help  # Display help information
fi


POSITIONAL=()

# Loop through the command line arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -v|--version)
        echo -e "${GRAY}+--------------------------------------------------------+"
        echo -e "${GRAY}|${ORANGE}               INFORMATION ABOUT THIS SCRIPT            ${GRAY}|"
        echo -e "${GRAY}+--------------------------------------------------------+"
        echo -e "${RESET}"
        echo -e "${ORANGE}${BOLD}${ITALIC}kurl${RESET} is the name of a bash script that uses the Yourls API to shorten links."
        echo "You must install yourls on your server or have access to a yourls server with the so-called signature key."
        echo "It works on all major ${BOLD}Linux{$RESET} distributions."
        echo -e "Kurl stands for ${BOLD}${GRAY}${ITALIC}Kurz-URL${RESET} which means ${BOLD}${GRAY}${ITALIC}short URL${RESET} in German.${RESET}"
        echo
        echo -e "${BOLD}${GRAY}Version:${RESET} ${BOLD}$VERSION${RESET}"
        echo -e "${BOLD}${GRAY}Name:${RESET} ${BOLD}$APP_NAME${RESET}"
        echo -e "${BOLD}${GRAY}Github:${RESET} ${BOLD}$GITHUB_LINK${RESET}"
        echo -e "${BOLD}${GRAY}Contact:${RESET} ${BOLD}$CONTACT_EMAIL${RESET}"
        echo -e "${BOLD}${GRAY}Config file:${RESET} ${BOLD}$CONFIG_FILE${RESET}"
        SCRIPT_LOCATION="cannot be located"
        if command -v realpath &> /dev/null; then
            SCRIPT_LOCATION=$(realpath $0)
        elif command -v readlink &> /dev/null; then
            SCRIPT_LOCATION=$(readlink -f $0)
        fi
        echo -e "${BOLD}${GRAY}Script location:${RESET} ${BOLD}$SCRIPT_LOCATION${RESET}"
        echo
        exit 0
        ;;
        -k|--keyword)
        KEYWORD="$2"
        shift # past argument
        shift # past value
        ;;
        -t|--title)
        TITLE="$2"
        shift # past argument
        shift # past value
        ;;
        -f|--format)
        FORMAT="$2"
        shift # past argument
        shift # past value
        ;;
        -s|--statistics)
        STATISTICS="true"
        shift # past argument
        ;;
        -e|--expand)
        EXPAND="true"
        shift # past argument
        ;;
        -d|--delete)
        DELETE="true"
        shift # past argument
        ;;
        -l|--list)
        LIST=true
        shift # past argument
        ;;
        -g|--global)
        GLOBAL=true
        shift # past argument
        ;;
        -i|--check)

        echo
        echo -e "${GRAY}+--------------------------------------------------------+"
        echo -e "${GRAY}|${ORANGE}                    CHECKING DEPENDENCIES               ${GRAY}|"
        echo -e "${GRAY}+--------------------------------------------------------+"
        echo -e "${RESET}"

        echo -e "${GRAY}The following tools are needed for the script to work properly:${RESET}"
        check_dependencies true
        echo
        exit 0

        ;;
        -c|--change-config)
        echo -e "${GRAY}+--------------------------------------------------------+"
        echo -e "${GRAY}|${ORANGE}                     CHECK CONFIGURATION                 ${GRAY}|"
        echo -e "${GRAY}+--------------------------------------------------------+"
        echo -e "${RESET}"

        # Check the connection
        if $CONNECTION_OK; then
            echo -e "${CYAN}This is what you have saved in your config.cfg:${RESET}"
            echo -e "${GRAY}${ITALIC}File path: $(dirname "$CONFIG_FILE") ${RESET}"
            echo
            cat $CONFIG_FILE
            echo
            echo -e "${ORANGE}Do you really want to re-enter your credentials? [y/n]: ${RESET}"
            read REENTER
            if [ "$REENTER" != "y" ]; then
                exit 0
            fi
        fi
        rm $CONFIG_FILE
        prompt_for_credentials
        exit 0
        ;;
        --autocopy-on)
        AUTO_COPY="y"
        sed -i "/^AUTO_COPY=/c\AUTO_COPY=\"$AUTO_COPY\"" $CONFIG_FILE
        echo
        echo -e "Autocopy to clipboard is ${GREEN}ON${RESET}"
        echo
        exit 0
        ;;
        --autocopy-off)
        AUTO_COPY="n"
        sed -i "/^AUTO_COPY=/c\AUTO_COPY=\"$AUTO_COPY\"" $CONFIG_FILE
        echo
        echo -e "Autocopy to clipboard is ${RED}OFF${RESET}"
        echo
        exit 0
        ;;
        -h|--help)
        yourls_help
        exit 1
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done


# restore positional parameters
set -- "${POSITIONAL[@]}"

# Check if more than one of the options -s, -e, -d was used
if { [ ! -z "$STATISTICS" ] && [ ! -z "$EXPAND" ]; } || { [ ! -z "$STATISTICS" ] && [ ! -z "$DELETE" ]; } || { [ ! -z "$EXPAND" ] && [ ! -z "$DELETE" ]; }; then
echo
echo -e "${RED}Error: Only one of the options -s, -e, -d can be used at a time.${RESET}"
exit 1
fi

# Check if a keyword or short URL was provided
if { [ ! -z "$STATISTICS" ] || [ ! -z "$EXPAND" ] || [ ! -z "$DELETE" ]; } && [ -z "$1" ]; then
  echo
echo -e "${RED}Error: You must provide a keyword or short URL when using the -s, -e, or -d option.${RESET}"
echo
exit 1
fi

## Assuming first parameter is the URL
URL=$1;
shift;

if [ -z "$FORMAT" ]; then
    format="simple"
elif [ "$FORMAT" == "xml" ]; then
    format="xml"
elif [ "$FORMAT" == "json" ]; then
    format="json"
elif [ "$FORMAT" == "jsonp" ]; then
    format="jsonp"
else
    format="simple"
fi

if [ ! -z "$STATISTICS" ]; then
    check_url "$URL" "Checking statistics for"
    exit 0

elif [ ! -z "$EXPAND" ]; then
    check_url "$URL" "Checking long-url for"
    exit 0

elif [ ! -z "$DELETE" ]; then
    # Use the new function to check if the URL exists, print its statistics, and delete it
    function_delete_from_database "$URL"
    exit 0

elif [ "$GLOBAL" = true ]; then
    response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=db-stats&format=json")
    json=$(echo "$response" | jq -r .)

    total_links=$(echo "$json" | jq -r '.["db-stats"].total_links')
    total_clicks=$(echo "$json" | jq -r '.["db-stats"].total_clicks')

    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${GRAY}|${ORANGE}                    GLOBAL STATISTICS                   ${GRAY}|"
    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${RESET}"
    echo -e "SERVER:${RESET}\t${CYAN}${BOLD}$YOURLS_HOST${RESET}"
    echo
    echo -e "Total links:${RESET}\t${CYAN}${BOLD}$total_links${RESET}"
    echo -e "Total clicks:${RESET}\t${CYAN}${BOLD}$total_clicks${RESET}"
    echo

# Fetch and display top 3 most accessed URLs
response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=stats&filter=top&limit=3&format=json")
echo
if [ "$(echo "$response" | jq -r '.links | length')" -gt 0 ]; then
    echo -e "${YELLOW}TOP 3 MOST ACCESSED URLs:${RESET}"
    echo
    echo "$response" | jq -r '.links | to_entries[] | [.value.shorturl, .value.clicks] | @tsv'
else
    echo -e "${ORANGE}No links in the database.${RESET}"
fi
echo
echo "###"
echo

# Fetch and display top 3 least accessed URLs
response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=stats&filter=bottom&limit=3&format=json")
if [ "$(echo "$response" | jq -r '.links | length')" -gt 0 ]; then
    echo -e "${YELLOW}TOP 3 LEAST ACCESSED URLs:${RESET}"
    echo
    echo "$response" | jq -r '.links | to_entries[] | [.value.shorturl, .value.clicks] | @tsv'
else
    echo -e "${ORANGE}No links in the database.${RESET}"
fi
    echo
    exit 0


elif [ "$LIST" = true ]; then

    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${GRAY}|${ORANGE}                      DATABASE LIST                     ${GRAY}|"
    echo -e "${GRAY}+--------------------------------------------------------+"
    echo -e "${RESET}"

    echo -e "Choose the output format:"
echo
echo "1. XML"
echo "2. JSON (default)"
echo "3. Export XML to file"
echo "4. Export JSON to file"
echo "5. Show as table"
echo "6. Most accessed URLs"
echo "7. Least accessed URLs"
echo
read -p "Enter your choice (1 to 7, or press return to exit): " choice

# Exit if the user didn't enter a choice
if [ -z "$choice" ]; then
    echo -e "${ITALIC}Exiting...${RESET}"
    echo
    exit 0
fi

# Set the format and limit based on the user's choice
if [ "$choice" = 1 ] || [ "$choice" = 3 ]; then
    list_format="xml"
    limit="1000000"
elif [ "$choice" = 6 ] || [ "$choice" = 7 ]; then
    list_format="json"
    limit="10"
else
    list_format="json"
    limit="1000000"
fi

# Set the filter based on the user's choice
if [ "$choice" = 6 ]; then
    filter="top"
elif [ "$choice" = 7 ]; then
    filter="bottom"
else
    filter="all"
fi

response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=stats&filter=$filter&limit=$limit&format=$list_format")


# Check if any links were returned
if [ "$(echo "$response" | jq -r '.links | length')" -eq 0 ]; then
    echo -e "${CYAN}No links in the database.${RESET}"
    exit 0
fi


    default_filepath="$HOME/yourls_data.$list_format" # Default file path

    if [ "$choice" = 3 ]; then
        echo "The default file path is: $default_filepath"
        read -p "Enter the file path to save the XML (press enter to use the default path): " filepath
        filepath=${filepath:-$default_filepath} # Use the default path if the user doesn't enter a path
        echo "$response" > "$filepath"
        echo "XML data exported to $filepath"
    elif [ "$choice" = 4 ]; then
        echo "The default file path is: $default_filepath"
        read -p "Enter the file path to save the JSON (press enter to use the default path): " filepath
        filepath=${filepath:-$default_filepath} # Use the default path if the user doesn't enter a path
        echo "$response" > "$filepath"
        echo "JSON data exported to $filepath"
        exit 0
    elif [ "$choice" = 5 ] || [ "$choice" = 6 ] || [ "$choice" = 7 ]; then
        if [ "$list_format" = "json" ]; then
            echo
            if [ "$choice" = 5 ]; then
                echo -e "${CYAN}LIST OF ALL URLs:\n${RESET}"
            elif [ "$choice" = 6 ]; then
                echo -e "${CYAN}TOP 10 MOST ACCESSED URLs\n${RESET}"
            elif [ "$choice" = 7 ]; then
                echo -e "${CYAN}TOP 10 LEAST ACCESSED URLs\n${RESET}"

            fi
            printf "%s%-5s  %-30s  %-30s  %-35s  %-15s  %-20s  %-10s%s\n" "$(tput setaf 4)" "#" "Short-URL" "Long-URL" "Title" "Date" "IP" "Clicks" "$(tput sgr0)"
            echo
            i=0
            tempfile=$(mktemp)
            echo "$response" | jq -r '.links | to_entries[] | [.value.shorturl, .value.url, .value.title, .value.timestamp, .value.ip, .value.clicks] | @tsv' > "$tempfile"
            while IFS=$'\t' read -r shorturl url title timestamp ip clicks
            do
                url=$(echo "$url" | awk '{print substr($0, 1, 30)}') # Truncate url to 30 characters
                title=$(echo "$title" | awk '{print substr($0, 1, 35)}' | sed 's/[^[:print:]\t]//g') # Truncate title to 35 characters and remove non-printable characters
                date=$(echo "$timestamp" | cut -d ' ' -f1) # Extract date from timestamp
                printf "%-5s  %-30s  %-30s  %-35s  %-15s  %-20s  %-10s\n" "$((++i))" "$shorturl" "$url" "$title" "$date" "$ip" "$clicks"
            done < "$tempfile" | more
            rm "$tempfile"
        else
            echo "Table view is not supported for XML format."
        fi
    elif [ "$list_format" = "json" ]; then
        echo "List of URLs: "
        echo "$response" | jq
    else
        echo "List of URLs: $response"
    fi
    echo
    exit 0
    fi


# Validate the URL for shortening
validate_url_for_shortening "$URL"
is_short_url=$?

# Check if the URL is already a short URL
if [ $is_short_url -eq 1 ]; then
    echo -e "${GRAY}It is not possible to shorten a short URL.${RESET}"
    echo
    exit 1
fi

# Send a request to the YOURLS API to shorten the URL
response=$(curl -s "$YOURLS_HOST/yourls-api.php?signature=$YOURLS_KEY&action=shorturl&url=$URL&keyword=$KEYWORD&title=$TITLE&format=json")
json=$(echo "$response" | jq -r .)
status=$(echo "$json" | jq -r .status)
message=$(echo "$json" | jq -r .message)
shorturl=$(echo "$json" | jq -r .shorturl)

# Check the status of the API response
if [ "$status" == "fail" ]; then
    echo
    echo -e "${ORANGE}$message${RESET}"
    if [ -n "$shorturl" ]; then
        echo
        echo -e "${BOLD}${GRAY}Existing short URL:${RESET} ${BOLD}${CYAN}$shorturl${RESET}"
        # Get and display the basic statistics for the existing short URL
        keyword=$(basename "$shorturl")
        print_url_statistics $keyword
        if [ "$AUTO_COPY" == "y" ]; then
        # Copy the short URL to the clipboard
        if [ "$XDG_SESSION_TYPE" == "wayland" ]; then
            echo "$shorturl" | wl-copy
        else
            echo "$shorturl" | xclip -selection clipboard
        fi
        echo "The short URL has been copied to your clipboard."
        echo
        fi
        print_output "$format"
    fi
elif [ "$status" == "success" ]; then
    echo
    echo -e "The URL ${BOLD}${CYAN}$URL${RESET} was ${BOLD}${GREEN}successfully${RESET} shortened."
    echo
    echo -e "${BOLD}${ORANGE}Your SHORT URL:${RESET}${BOLD}${CYAN}$shorturl${RESET}"
    echo
    if [ "$AUTO_COPY" == "y" ]; then
        # Copy the short URL to the clipboard
        if [ "$XDG_SESSION_TYPE" == "wayland" ]; then
            echo "$shorturl" | wl-copy
        else
            echo "$shorturl" | xclip -selection clipboard
        fi
        echo
        echo "The short URL has been copied to your clipboard."
        echo
        print_output "$format"

        exit 0
    fi
fi
