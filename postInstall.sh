#!/bin/bash

# ---------------------------------------------------------------
# Arskell - Post install - Downloadeded after initial script     |
# ---------------------------------------------------------------
# Author    : Binary-Brawler                                     |
# Github    : github.com/Binary-Brawler                          |
# Social    : https://bwalker.xyz
# LinkedIn  : linkedin.com/in/brandon-walker-0b0542116/          |
# Version   : 1.1.2                                              |
# ---------------------------------------------------------------
#                   Functions & Purpose:                         |
# ---------------------------------------------------------------
#
# p_Download  - Check parallel downloads and enable/disable 
# Installer   - Installs base useful packages 
# desktop_Env - Installs lightweight MATE w/ simple config setup
# dev_Setup   - Installs code env i.e. IDE & languages 
# vid_Driver  - Checks video driver and installs drivers (nvidia works locally ;)
# user_Info   - Creates user and sets ROOT PASS
# booter      - Not fully "Yet" automated bootloader
# complete    - Working hArch linux 

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
log_success() {
    local num_quotes=${#programming_quotes[@]}
    local random_index=$((RANDOM % num_quotes))
    local random_quote="${programming_quotes[$random_index]}"
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
    echo "Motivational Quote: $random_quote"
}

# Array of motivational quotes
programming_quotes=(
    "The only way to do great work is to love what you do. - Steve Jobs"
    "First, solve the problem. Then, write the code. - John Johnson"
    "The best way to predict the future is to invent it. - Alan Kay"
    "Code is like humor. When you have to explain it, it’s bad. - Cory House"
    "Programming isn't about what you know; it's about what you can figure out. - Chris Pine"
    "Simplicity is the soul of efficiency. - Austin Freeman"
    "Don’t worry if it doesn’t work right. If everything did, you’d be out of a job. - Mosher’s Law of Software Engineering"
)

# Repeats turned into functions ;) 
sleep_and_clear() {
    sleep 3
    clear
}

# Are we enabling parallel downloads again...
function p_Download {
    echo "--------------------------------"
    # Inside your arch-chroot script
    enable_parallel=$(cat /enable_parallel.txt)

    if [ "$enable_parallel" = "true" ]; then
        # Enable parallel downloads
        sed -i '/#ParallelDownloads/s/^#//g' /etc/pacman.conf
        print_info "Parallel Downloads Enabled."
        rm /enable_parallel.txt
    else
        print_info "Parallel Downloads Disabled."
        rm /enable_parallel.txt
    fi
}

# Basic Packages
function installer {
    echo "-------------------------------------------------------"
    print_info "What would you like your system name set too..."
    read -p "Enter Hostname: " hostname
    echo $hostname > /etc/hostname
    sleep_and_clear
    echo  "------------------------------------"
    print_info "Installing useful packages..." 
    pacman -S dkms linux-headers mlocate git cmake make neofetch nix net-tools dnsutils fish btop flameshot remmina firefox element-desktop cherrytree terminator chromium --noconfirm >/dev/null 2>&1
    hwclock --systohc
}

function desktop_Env {
    echo "------------------------"
    print_info "Setting up DE..."
    pacman -S  mate mate-extra lightdm lightdm-gtk-greeter xorg xorg-server xorg-apps xorg-xinit --noconfirm >/dev/null 2>&1
    systemctl enable lightdm >/dev/null 2>&1
    sleep 3
    curl -O $GITHUB/Main/conf/linux-vs-windows.jpg >/dev/null 2>&1
    mv /linux-vs-windows.jpg /usr/share/backgrounds/mate/desktop/linux-vs-windows.jpg
    curl -O $GITHUB/Main/conf/MateConfig >/dev/null 2>&1
}

function dev_Setup {
    echo "----------------------------------------------------------"
    echo "Setting up a coding environment... This may take a while"
    echo "----------------------------------------------------------"

    user=$(getent passwd | awk -F: '$6 ~ /^\/home/ {print $1}')

    curl -O $GITHUB/Main/conf/vimrc_bundle_conf >/dev/null 2>&1
    mv vimrc_bundle_conf /home/$user/.vimrc
    chown $user /home/$user/.vimrc

    pacman -S wireshark-qt jdk-openjdk python-pip rustup go nodejs npm python3 code neovim gimp audacity vlc virtualbox docker pycharm-community-edition intellij-idea-community-edition --noconfirm >/dev/null 2>&1

    curl -O $GITHUB/Main/conf/fish.config >/dev/null 2>&1
    mkdir -p /home/$user/.config/fish
    mv /fish.config /home/$user/.config/fish/config.fish
    chown $user -R /home/$user/.config/
    mkdir -p /home/$user/AUR
    chown -R $user /home/$user/AUR
}

# Nvidia function to handle nvidia driver installation... WIP
# vidDriver will handle for now...
handle_nvidia() {
    NVD='NVIDIA'
    card=$(lspci -vmm | grep VGA -A6)
    if [[ $card == *"$NVD"* ]]; then
        print_info "Nvidia graphics detected. Applying configuration..."
        # Add Nvidia-specific configurations here
        # This will replace vidDriver() NVD case
        # but nobody uses this so it works locally ;)
    fi
}

function vid_Driver {
    echo "----------------------------------"
    print_info "Gathering Graphics info..."
    sleep 2
    str=$(lspci -vmm | grep VGA -A6)
    user=$(getent passwd | awk -F: '$6 ~ /^\/home/ {print $1}')
    
    # Define driver packages
    AMD='AMD'
    NVD='NVIDIA'
    Turing='nvidia-open'
    Maxwell='nvidia'
    Kepler='nvidia-470xx-dkms'
    Fermi='nvidia-390xx-dkms'
    Tesla='nvidia-340xx-dkms'
    
    case $str in
        *"$AMD"*)
            print_info "Installing AMD Drivers..."
            echo "------------------------------------"
            pacman -S xf86-video-ati xf86-video-amdgpu mesa --noconfirm >/dev/null
            ;;
        *"$NVD"*)
            # Check Nvidia GPU architecture
            if echo "$str" | grep -q "NV160\|TU"; then
                driver=$Turing
            elif echo "$str" | grep -q "NV110\|GM"; then
                driver=$Maxwell
            elif echo "$str" | grep -q "NVE0\|GK"; then
                driver=$Kepler
            elif echo "$str" | grep -q "NVC0\|GF"; then
                driver=$Fermi
            elif echo "$str" | grep -q "NV50\|G8"; then
                driver=$Tesla
            else
                print_info "Unable to determine specific Nvidia architecture. Installing the default driver..."
                print_info "Check dmesg for any driver issues..."
                driver=$Maxwell # Fallback to a common driver
            fi
            
            print_info "Installing Nvidia Drivers: $driver..."
            echo "-------------------------------------"
            if [[ $driver == "nvidia-open" || $driver == "nvidia" ]]; then
                # Install for Turing and Maxwell
                pacman -S "$driver" nvidia-settings nvidia-utils glxinfo nvtop --noconfirm >/dev/null
            else
                git clone "https://aur.archlinux.org/$driver.git" /tmp/$driver
                cd /tmp/$driver
                su $user
                makepkg -si --noconfirm
                cd -
                #rm -rf /tmp/$driver
            fi

            curl -O $GITHUB/Main/conf/nvidia.hook 2>/dev/null
            curl -O $GITHUB/Main/conf/20-nvidia.conf 2>/dev/null
            mkdir -p /etc/pacman.d/hooks/ /etc/X11/xorg.conf.d/
            mv /nvidia.hook /etc/pacman.d/hooks/
            mv /20-nvidia.conf /etc/X11/xorg.conf.d/
            echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nvidia-nouveau.conf
            echo "-------------------------------------------------------------"
            print_info "Attempting to force composition..."
            print_info "[!] Usually fixes screen tearing w/ Nvidia drivers..."
            #bash -c "nvidia-settings --assign CurrentMetaMode=\"$(nvidia-settings -q CurrentMetaMode -t | sed 's/"/\\"/g; s/}/, ForceCompositionPipeline = On}/')\""
            ;;
        *)
            print_info "Unable to determine Graphics info.. Installing default drivers"
            echo "----------------------------------------------------------------------"
            pacman -S xf86-video-fbdev --noconfirm
    esac
}

function user_Info {
    echo "--------------------------------"
    print_info "Set Root password..."
    passwd
    sleep_and_clear
    echo "-------------------------------"
    read -p "Enter Username: " username
    useradd -mg users -G wheel,power,storage -s /bin/fish $username
    echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/wheel_group
    chmod 440 /etc/sudoers.d/wheel_group
    print_info "Password for user: $username"
    passwd $username
}

function booter {
    echo "-----------------------------"
    print_info "Setting Bootloader..."
    drives=$(lsblk -f)
    echo -e "$drives${NEWLINE}"
    echo -e "[${YELLOW}SYNTAX${RESET}] If BIOS, attach bootloader to disk: ex- /dev/sda"
    echo -e "[${YELLOW}SYNTAX${RESET}] If UEFI, attach bootloader to partition: ex- /dev/nvme0n1p1"
    echo "-----------------------------------------------------------------------------------------------------"
    read -p "Enter Drive/Partition to install Bootloader [Example: /dev/nvme0n1p1]: " drive
    sleep_and_clear
    if [[ -d "/sys/firmware/efi" ]]; then
        echo "-------------------------------------"
        print_info "Installing UEFI Bootloader..."
        pacman -S efibootmgr grub dosfstools mtools os-prober --noconfirm >/dev/null
        grub-install --target=x86_64-efi --bootloader-id=HARCH_UEFI --efi-directory=/boot/EFI --recheck
        grub-mkconfig -o /boot/grub/grub.cfg
        mkinitcpio -p linux
    else
        echo "-------------------------------------"
        print_info "Installing BIOS Bootloader..."
        pacman -S grub --noconfirm >/dev/null
        grub-install --target=i386-pc $drive --recheck
        grub-mkconfig -o /boot/grub/grub.cfg
        mkinitcpio -p linux
    fi
}

function complete {
    sleep_and_clear
    echo "-------------------------------------------------------------------------------------------------"
    neofetch
    echo "-------------------------------------------------------------------------------------------------"
    log_success "hArch has been successfully installed on your system"
    print_info "--------------------------------------------------------------------"
    print_info "Hack the Universe $username w/ Haskell ;)"
    log_warning "A reboot should now take place"
    print_info "Run the following commands to reboot properly:"
    log_warning "1: exit"
    log_warning "2: umount -a"
    log_warning "3: reboot"
    exit
}

function one_Func_To_Rule_Them_All {
    sleep_and_clear
    p_Download
    sleep_and_clear

    installer
    sleep_and_clear

    user_Info
    sleep_and_clear

    vid_Driver
    sleep_and_clear

    booter
    sleep_and_clear

    desktop_Env
    sleep_and_clear

    dev_Setup
    sleep_and_clear

    complete
}

one_Func_To_Rule_Them_All
