#!/bin/bash

# ---------------------------------------------------------------
# Arskell Installer (Haskell Arch)                               |
# ---------------------------------------------------------------
# Author    : Binary-Brawler                                     |
# Github    : github.com/Binary-Brawler                          |
# LinkedIn  : linkedin.com/in/brandon-walker-0b0542116/          |
# Version   : 1.1.0                                              |
# Intent    : Simplistic Linux box for Haskell Development       |
#               - GHCUP w/ Stack/Cabal                           |
#               - Sublime Text/VSCode/NeoVim                     |
# ---------------------------------------------------------------
#                  Functions & Purpose:                          |
# ---------------------------------------------------------------
# greet               - Greeter function 
# check_Net           - Checks internet speed for parallel downloads
# calculate_swap_size - if/else to determine SWAP size
# partition_drive     - Automated partitioning following basic Arch install
# installer           - Install base system and copy postInstall script
# main                - Functional way of running an Imperative script X_x

# Constants
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[0;37m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
RESET='\033[0m'
NEWLINE=$'\n'
GITHUB='https://raw.githubusercontent.com/Binary-Brawler/Arskell'

# Logging
log_warning() { echo -e "[${YELLOW}WARNING${RESET}] $1"; }
log_error() { echo -e "[${RED}ERROR${RESET}] $1"; }
print_info() { echo -e "[${GREEN}INFO${RESET}] $1${NEWLINE}"; }
log_success() { echo -e "[SUCCESS] $1"; }
 
function sleep_and_clear {
    sleep 3
    clear
}

function greet {
    sleep_and_clear
	echo -e "${PURPLE}Arskell (Arch Linux w/ Haskell) Installer${RESET}"
	echo ${NEWLINE}
	echo ${NEWLINE}
    echo "-------------------------------------------------------------------------------------------------"
	echo -e ${YELLOW}
	echo ${NEWLINE}
	echo ${NEWLINE}
    printf " _    _           _        _ _                     _     \n"
    printf "| |  | |         | |      | | |     /\\            | |    \n"
    printf "| |__| | __ _ ___| | _____| | |    /  \\   _ __ ___| |__  \n"
    printf "|  __  |/ _\` / __| |/ / _ \\ | |   / /\\ \\ | '__/ __| '_ \\ \n"
    printf "| |  | | (_| \\__ \\   <  __/ | |  / ____ \\| | | (__| | | |\n"
    printf "|_|  |_\\__,_|___/_|\\_\\___|_|_| /_/    \\_\\_|  \\___|_| |_|"
    echo ${NEWLINE}                                                    
	echo -e "${RESET}"
	echo ${NEWLINE}
	echo ${NEWLINE}
    echo "-------------------------------------------------------------------------------------------------"
}

function check_Net {
    echo "---------------------------------------"
    print_info "Checking Internet Connection..."
    
    if ! command -v speedtest-cli &>/dev/null; then
        print_info "speedtest-cli is not installed. Installing..."
        pacman -Sy >/dev/null
        python3 -m venv speedTest && cd speedTest/bin/ && ./pip3 install speedtest-cli >/dev/null
    fi

    print_info "Calculating Internet Speed..."
    sleep 1
    local speed=$(./speedtest-cli --simple | awk '/^Download:/ {print $2}')
    sleep 1
    echo "------------------------------------"
    print_info "Download Speed: $speed Mbps"
    echo "------------------------------------"
 
    if (( $(echo "$speed > 50" | bc -l) )); then
        print_info "Enabling Parallel Downloads..."
        sed -i '/#ParallelDownloads/s/^#//g' /etc/pacman.conf
        echo "true" > enable_parallel.txt
    else
        print_info "Keeping Parallel Downloads Disabled as speed is too slow."
        echo "false" > enable_parallel.txt
    fi
}

function calculate_swap_size {
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size="2G"

    if [[ ! $ram_gb =~ ^[0-9]+$ ]]; then
        log_error "Error: Could not determine RAM size." >&2
        exit 1
    fi

    if ((ram_gb < 2)); then
        swap_size="${ram_gb}"
    elif ((ram_gb < 4)); then
        swap_size="3G"
    elif ((ram_gb < 16)); then
        swap_size="4G"
    else
        swap_size="8G"
    fi

    echo "$swap_size"
}

function partition_drive {
    local drive="$1"
    local swap_size=$(calculate_swap_size)
    local cmd_list=()

    if [[ -d "/sys/firmware/efi/efivars/" ]]; then
        cmd_list=(
            "g"                          
            "n" "" "" "+512M"            
            "n" "" "" "+$swap_size"      
            "n" "" "" ""                 
            "t" "1" "1"                  
            "t" "2" "19"                 
            "w"                          
        )

    else
        cmd_list=(
            "o" "n" "p" "" "" "+$swap_size"  
            "n" "p" "" "" ""                  
            "t" "1" "82"                      
            "w"                               
        )

    fi

    printf "%s\n" "${cmd_list[@]}" | fdisk "$drive" >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to partition the drive."
        return 1
    fi

    if [[ -d "/sys/firmware/efi/efivars/" ]]; then
        if [[ $drive == *nvme* ]]; then
            mkfs.fat -F32 "${drive}p1" 
            mkswap "${drive}p2"         
            mkfs.ext4 "${drive}p3"     

            mount "${drive}p3" /mnt
            mkdir -p /mnt/boot/EFI
            mount "${drive}p1" /mnt/boot/EFI
            swapon "${drive}p2"
        elif [[ $drive == *sd* ]]; then
            mkfs.fat -F32 "${drive}1" 
            mkswap "${drive}2"        
            mkfs.ext4 "${drive}3"     

            mount "${drive}3" /mnt
            mkdir -p /mnt/boot/EFI
            mount "${drive}1" /mnt/boot/EFI
            swapon "${drive}2"
        else
            echo "Error: Something went wrong with UEFI install..."
            return 1
        fi
    else
        if [[ $drive == *sd* ]]; then
            mkfs.fat -F32 "${drive}1" 
            mkswap "${drive}2"        
            mkfs.ext4 "${drive}3"    

            mount "${drive}3" /mnt
            mkdir -p /mnt/boot/EFI
            mount "${drive}1" /mnt/boot/EFI
            swapon "${drive}2"
        else
            echo "Error: Something happened with BIOS install..."
            return 1
        fi 
    fi
}

function installer {
    echo "--------------------------------"
    print_info "Installing Arch base..."
    pacstrap /mnt base base-devel linux linux-firmware vi vim nano dhcpcd iwd >/dev/null 2>&1
    sleep 1
    genfstab -U /mnt >> /mnt/etc/fstab
    sleep_and_clear
    echo "--------------------------------------"
    print_info "Finishing last minute setup..."
    echo 0 > /proc/sys/kernel/hung_task_timeout_secs
    mv enable_parallel.txt /mnt
    curl -O $GITHUB/Main/postInstall.sh >/dev/null 2>&1
    chmod +x postInstall.sh
    mv postInstall.sh /mnt
    echo  "----------------------------"
    print_info "Time to enter CHROOT"
    print_info "The final script has been installed and moved to your new root directory"
    print_info "Run these commands to finish setup"
    echo "------------------------------------------"
    echo ${NEWLINE}
    echo ${NEWLINE}
    echo -e "[1]${GREEN} arch-chroot /mnt${RESET}"
    echo -e "[2]${GREEN} ./postInstall.sh${RESET}"
    echo ${NEWLINE}
}

function main {
    greet
    sleep 1
    check_Net
    sleep 1
    echo "----------------------------"
    print_info "Gathering drives..."
    lsblk #TODO: Add something more robust
    print_info "Time to select the drive you want too partition..."
    print_info "If you want to manually partition you may, just type exit after mounting /mnt"
    print_info "Otherwise, automated partition will create the standard BIOS/UEFI partitions"
    echo ${NEWLINE}
    echo "--------------------------------------"
    read -p "Manually partition [y/N]: " manual

    if [[ $manual == 'y' || $manual == 'Y' ]]; then
        cfdisk "$drive"
        print_info "Entering BASH shell. Create filesystem and mount /mnt. Type exit once finished."
        bash
    else
        echo "----------------------------------------------"
        read -p "Enter Drive to prepare (e.g., /dev/sda): " drive
        echo "----------------------------"
        print_info "Modifying $drive..."
        sleep 3

        partition_drive "$drive"
    fi

    sleep_and_clear

    installer || log_error "Base system installation failed."

    log_success "hArch Installation completed successfully!"

}

# Start the script...
main