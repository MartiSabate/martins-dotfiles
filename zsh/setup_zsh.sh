#!/usr/bin/env bash
set -euo pipefail

# setup-zsh.sh
# Made by Martí Sabaté Fàbregas
#
# This script bootstraps zsh and Oh My Zsh on Debian/Ubuntu systems.
# It can configure either a local user's ~/.zshrc or a global /etc/zsh/zshrc.
# For local installs, it sets up Oh My Zsh under the target user's home.
# For all-users installs, it installs Oh My Zsh into /etc/oh-my-zsh and
# configures the shared system-wide zshrc.
#
# The script also installs zsh, optional powerline fonts, Powerlevel10k,
# and common Oh My Zsh plugins such as autosuggestions and syntax highlighting.

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf '\nWARNING: %s\n' "$*" >&2
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

run_as_target() {
  sudo -u "$TARGET_USER" -H "$@"
}

confirm() {
  local prompt="$1"
  local reply

  read -r -p "$prompt [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

require_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Please run this script with sudo privileges: sudo bash $0"
  fi
}

detect_target_user() {
  TARGET_USER="${SUDO_USER:-}"

  if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER="$(logname 2>/dev/null || true)"
  fi

  if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -r -p "Enter the local username to configure: " TARGET_USER
  fi

  id "$TARGET_USER" >/dev/null 2>&1 || die "User '$TARGET_USER' does not exist."
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "Home directory for '$TARGET_USER' was not found."
}

choose_zshrc_scope() {
  printf '\nThis script can configure zsh for:\n'
  printf '  1) Local user only: %s/.zshrc\n' "$TARGET_HOME"
  printf '  2) All users: /etc/zsh/zshrc\n'

  while true; do
    read -r -p "Which zshrc should be modified? [1/local, 2/all]: " choice
    case "${choice,,}" in
      1|local|user)
        CONFIG_SCOPE="local"
        ZSHRC_FILE="$TARGET_HOME/.zshrc"
        break
        ;;
      2|all|system|global)
        CONFIG_SCOPE="all-users"
        ZSHRC_FILE="/etc/zsh/zshrc"
        break
        ;;
      *)
        printf 'Please answer 1/local or 2/all.\n'
        ;;
    esac
  done

  log "Selected $CONFIG_SCOPE configuration: $ZSHRC_FILE"
}

ensure_apt_package() {
  local package="$1"

  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
    log "$package is already installed; skipping."
    return
  fi

  log "Installing $package."
  apt-get update
  apt-get install -y "$package"
}

ensure_zsh_installed() {
  ensure_apt_package zsh

  if [[ ! -x /usr/bin/zsh ]]; then
    die "/usr/bin/zsh was not found after installation."
  fi
}

ensure_default_shell() {
  local current_shell
  current_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7)"

  if [[ "$current_shell" == "/usr/bin/zsh" ]]; then
    log "Default shell for $TARGET_USER is already /usr/bin/zsh; skipping."
    return
  fi

  log "Setting /usr/bin/zsh as the default shell for $TARGET_USER."
  chsh -s /usr/bin/zsh "$TARGET_USER"
}

omz_dir() {
  if [[ "$CONFIG_SCOPE" == "all-users" ]]; then
    printf '/etc/oh-my-zsh'
  else
    printf '%s/.oh-my-zsh' "$TARGET_HOME"
  fi
}

ensure_oh_my_zsh() {
  local omz_dir
  omz_dir="$(omz_dir)"

  if [[ -d "$omz_dir" ]]; then
    log "Oh My Zsh is already installed at $omz_dir; skipping."
    return
  fi

  command -v curl >/dev/null 2>&1 || ensure_apt_package curl
  command -v git >/dev/null 2>&1 || ensure_apt_package git

  log "Installing Oh My Zsh into $omz_dir."

  if [[ "$CONFIG_SCOPE" == "local" ]]; then
    run_as_target sh -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
  else
    command -v git >/dev/null 2>&1 || ensure_apt_package git
    mkdir -p "$omz_dir"
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
  fi
}

ensure_zshrc_exists() {
  if [[ -f "$ZSHRC_FILE" ]]; then
    return
  fi

  log "Creating $ZSHRC_FILE."
  mkdir -p "$(dirname "$ZSHRC_FILE")"
  install -m 0644 /dev/null "$ZSHRC_FILE"

  if [[ "$CONFIG_SCOPE" == "local" ]]; then
    chown "$TARGET_USER:$TARGET_USER" "$ZSHRC_FILE"
  fi
}

ensure_oh_my_zsh_source() {
  local zsh_path
  local source_line

  if [[ "$CONFIG_SCOPE" == "local" ]]; then
    zsh_path='export ZSH="$HOME/.oh-my-zsh"'
  else
    zsh_path='export ZSH="/etc/oh-my-zsh"'
  fi

  source_line='source "$ZSH/oh-my-zsh.sh"'

  if grep -Eq '^[[:space:]]*export[[:space:]]+ZSH=' "$ZSHRC_FILE"; then
    sed -i -E "s|^[[:space:]]*export[[:space:]]+ZSH=.*|$zsh_path|" "$ZSHRC_FILE"
  else
    printf '\n%s\n' "$zsh_path" >> "$ZSHRC_FILE"
  fi

  sed -i '\|^[[:space:]]*source[[:space:]]\+"\$ZSH/oh-my-zsh\.sh"[[:space:]]*$|d' "$ZSHRC_FILE"
  printf '%s\n' "$source_line" >> "$ZSHRC_FILE"
}

set_zsh_theme() {
  local theme="$1"
  local comment="${2:-}"
  local escaped_theme
  local replacement

  ensure_zshrc_exists
  escaped_theme="$(printf '%s' "$theme" | sed 's/[&\\]/\\&/g')"
  replacement="ZSH_THEME=\"$escaped_theme\""

  if grep -Eq '^[[:space:]]*ZSH_THEME=' "$ZSHRC_FILE"; then
    sed -i -E "s|^[[:space:]]*ZSH_THEME=.*|$replacement|" "$ZSHRC_FILE"
  else
    printf '\n%s\n' "$replacement" >> "$ZSHRC_FILE"
  fi

  if [[ -n "$comment" ]] && ! grep -Fq "$comment" "$ZSHRC_FILE"; then
    printf '%s\n' "$comment" >> "$ZSHRC_FILE"
  fi

  log "Configured ZSH_THEME=\"$theme\" in $ZSHRC_FILE."
}

ensure_powerline_fonts() {
  ensure_apt_package fonts-powerline
}

ensure_git_clone() {
  local repo="$1"
  local destination="$2"
  local owner="${3:-}"

  command -v git >/dev/null 2>&1 || ensure_apt_package git

  if [[ -d "$destination/.git" ]]; then
    log "$destination is already cloned; skipping."
    return
  fi

  if [[ -e "$destination" ]]; then
    die "$destination already exists but is not a git repository. Please inspect it before continuing."
  fi

  log "Cloning $repo into $destination."
  mkdir -p "$(dirname "$destination")"

  if [[ -n "$owner" ]]; then
    chown -R "$owner:$owner" "$(dirname "$destination")"
    run_as_target git clone --depth=1 "$repo" "$destination"
  else
    git clone --depth=1 "$repo" "$destination"
  fi
}

zsh_custom_dir() {
  printf '%s/custom' "$(omz_dir)"
}

ensure_powerlevel10k() {
  local custom_dir owner
  custom_dir="$(zsh_custom_dir)"

  if [[ "$CONFIG_SCOPE" == "local" ]]; then
    owner="$TARGET_USER"
  else
    owner=""
  fi

  ensure_git_clone \
    "https://github.com/romkatv/powerlevel10k.git" \
    "$custom_dir/themes/powerlevel10k" \
    "$owner"
}

ensure_plugin() {
  local name="$1"
  local repo="$2"
  local custom_dir owner

  custom_dir="$(zsh_custom_dir)"

  if [[ "$CONFIG_SCOPE" == "local" ]]; then
    owner="$TARGET_USER"
  else
    owner=""
  fi

  ensure_git_clone "$repo" "$custom_dir/plugins/$name" "$owner"
}

ensure_plugins_configured() {
  local plugin_line='plugins=(git zsh-autosuggestions zsh-syntax-highlighting)'

  ensure_zshrc_exists

  if grep -Fq "$plugin_line" "$ZSHRC_FILE"; then
    log "Plugin list is already configured in $ZSHRC_FILE; skipping."
    return
  fi

  if grep -Eq '^[[:space:]]*plugins=\(' "$ZSHRC_FILE"; then
    sed -i -E "s|^[[:space:]]*plugins=\(.*\)|$plugin_line|" "$ZSHRC_FILE"
  else
    printf '\n%s\n' "$plugin_line" >> "$ZSHRC_FILE"
  fi

  log "Configured plugins in $ZSHRC_FILE."
}

fix_local_ownership() {
  if [[ "$CONFIG_SCOPE" == "local" ]]; then
    chown "$TARGET_USER:$TARGET_USER" "$ZSHRC_FILE"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.oh-my-zsh" 2>/dev/null || true
  else
    chown root:root "$ZSHRC_FILE"
    chown -R root:root "$(omz_dir)" 2>/dev/null || true
  fi
}

main() {
  require_sudo
  detect_target_user

  printf '\nRun this script with sudo privileges, for example:\n'
  printf '  sudo bash %s\n' "$0"
  printf '\nTarget local user: %s (%s)\n' "$TARGET_USER" "$TARGET_HOME"

  choose_zshrc_scope

  if ! confirm "Continue with zsh setup now?"; then
    die "Aborted by user."
  fi

  ensure_zsh_installed
  ensure_default_shell

  log "After the script finishes, log out and back in, then run: echo \$SHELL"

  ensure_oh_my_zsh
  ensure_zshrc_exists

  set_zsh_theme "robbyrussell"
  set_zsh_theme "agnoster" "# see https://github.com/ohmyzsh/ohmyzsh/wiki/Themes#agnoster"

  ensure_powerline_fonts
  ensure_powerlevel10k
  set_zsh_theme "powerlevel10k/powerlevel10k"

  ensure_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
  ensure_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
  ensure_plugins_configured
  ensure_oh_my_zsh_source
  fix_local_ownership

  log "Setup complete."
  printf 'Open a new session and run:\n'
  printf '  zsh\n'
  printf '  p10k configure\n'
  printf '\nIf you are root and still in bash, start a zsh shell first.\n'
  printf 'If root shell is not yet zsh, run as root:\n'
  printf '  chsh -s /usr/bin/zsh root\n'
  printf '\nThen verify the active shell with:\n'
  printf '  echo $SHELL\n'
}

main "$@"
