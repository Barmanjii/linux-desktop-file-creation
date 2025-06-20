#!/bin/bash

DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$DESKTOP_DIR"

sanitize_filename() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_'
}

update_desktop_database() {
  if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR"
    echo "✅ Desktop database updated."
  else
    echo "⚠️  'update-desktop-database' not found; you may need to update manually."
  fi
}

require_selection_tool() {
  if command -v fzf &> /dev/null; then
    return 0
  fi

  echo "⚠️  'fzf' is not installed, which is required for interactive selection."

  read -p "Would you like to install 'fzf' now? (y/N): " install_choice
  if [[ "$install_choice" =~ ^[Yy]$ ]]; then
    echo "🔍 Detecting your package manager..."
    if command -v apt &> /dev/null; then
      sudo apt update && sudo apt install -y fzf
    elif command -v pacman &> /dev/null; then
      sudo pacman -Sy fzf
    elif command -v nix &> /dev/null; then
      nix profile install nixpkgs#fzf
    elif command -v brew &> /dev/null; then
      brew install fzf
    else
      echo "❌ Could not detect a supported package manager. Please install 'fzf' manually."
      exit 1
    fi

    if ! command -v fzf &> /dev/null; then
      echo "❌ 'fzf' installation failed. Please install it manually."
      exit 1
    else
      echo "✅ fzf installed successfully."
    fi
  else
    echo "❌ Cannot proceed without 'fzf'. Exiting."
    exit 1
  fi
}

choose_desktop_file() {
  desktop_files=("$DESKTOP_DIR"/*.desktop)
  [ ${#desktop_files[@]} -eq 0 ] && echo "" && return

  if command -v fzf &> /dev/null; then
    printf "%s\n" "${desktop_files[@]}" | fzf --prompt="Select .desktop file: "
  else
    echo "Available .desktop files:"
    select file in "${desktop_files[@]}"; do
      echo "$file"
      break
    done
  fi
}

create_desktop() {
  echo "🆕 Creating a new .desktop file."

  read -p "Enter Application Name (e.g., Postman): " app_name
  read -p "Enter executable path (e.g., /home/username/.nix-profile/bin/Postman): " exec_path
  read -p "Enter icon name or full path (e.g., postman): " icon_name
  read -p "Enter categories (e.g., Development;Utility;): " categories

  [ -z "$categories" ] && categories="Utility;"

  read -p "Do you want to add supported MIME types? (y/N): " add_mime
  mime_line=""
  if [[ "$add_mime" =~ ^[Yy]$ ]]; then
    read -p "Enter MIME types separated by semicolons (e.g., video/mp4;video/x-matroska;): " mime_types
    mime_line="MimeType=$mime_types"
  fi

  desktop_file_name="$(sanitize_filename "$app_name").desktop"
  desktop_file_path="$DESKTOP_DIR/$desktop_file_name"

  cat > "$desktop_file_path" <<EOL
[Desktop Entry]
Name=$app_name
Exec=$exec_path
Icon=$icon_name
Type=Application
Categories=$categories
Terminal=false
$mime_line
EOL

  echo "✅ .desktop file created at: $desktop_file_path"
  update_desktop_database
}

update_desktop() {
  echo "✏️  Updating an existing .desktop file."
  require_selection_tool
  desktop_file_path=$(choose_desktop_file)

  if [ -z "$desktop_file_path" ] || [ ! -f "$desktop_file_path" ]; then
    echo "❌ No valid .desktop file selected. Aborting."
    return
  fi

  current_name=$(grep -Po '^Name=\K.*' "$desktop_file_path")
  current_exec=$(grep -Po '^Exec=\K.*' "$desktop_file_path")
  current_icon=$(grep -Po '^Icon=\K.*' "$desktop_file_path")
  current_categories=$(grep -Po '^Categories=\K.*' "$desktop_file_path")
  current_mime=$(grep -Po '^MimeType=\K.*' "$desktop_file_path")

  echo "Press Enter to keep the current value in [brackets]."

  read -p "Application Name [$current_name]: " new_name
  read -p "Executable Path [$current_exec]: " new_exec
  read -p "Icon [$current_icon]: " new_icon
  read -p "Categories [$current_categories]: " new_categories

  mime_line=""
  if [ -n "$current_mime" ]; then
    read -p "MIME types [$current_mime] (leave empty to keep, '-' or 'none' to remove): " new_mime
    if [[ "$new_mime" == "-" || "$new_mime" == "none" ]]; then
      mime_line=""
    elif [ -n "$new_mime" ]; then
      mime_line="MimeType=$new_mime"
    else
      mime_line="MimeType=$current_mime"
    fi
  else
    read -p "Do you want to add MIME types? (y/N): " want_mime
    if [[ "$want_mime" =~ ^[Yy]$ ]]; then
      read -p "Enter MIME types separated by semicolons: " new_mime
      [ -n "$new_mime" ] && mime_line="MimeType=$new_mime"
    fi
  fi

  app_name="${new_name:-$current_name}"
  exec_path="${new_exec:-$current_exec}"
  icon_name="${new_icon:-$current_icon}"
  categories="${new_categories:-$current_categories}"
  [ -z "$categories" ] && categories="Utility;"

  cat > "$desktop_file_path" <<EOL
[Desktop Entry]
Name=$app_name
Exec=$exec_path
Icon=$icon_name
Type=Application
Categories=$categories
Terminal=false
$mime_line
EOL

  echo "✅ Updated: $desktop_file_path"
  update_desktop_database
}

delete_desktop() {
  echo "🗑️  Deleting a .desktop file."
  require_selection_tool
  desktop_file_path=$(choose_desktop_file)

  if [ -z "$desktop_file_path" ] || [ ! -f "$desktop_file_path" ]; then
    echo "❌ No valid .desktop file selected. Aborting."
    return
  fi

  read -p "Are you sure you want to delete $desktop_file_path? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm "$desktop_file_path"
    echo "🗑️  Deleted: $desktop_file_path"
    update_desktop_database
  else
    echo "❎ Deletion cancelled."
  fi
}

# Main menu
echo "==== .desktop File Manager ===="
echo "1) Create new .desktop file"
echo "2) Update existing .desktop file"
echo "3) Delete .desktop file"
read -p "Enter your choice (1/2/3): " choice

case "$choice" in
  1) create_desktop ;;
  2) update_desktop ;;
  3) delete_desktop ;;
  *) echo "❌ Invalid choice"; exit 1 ;;
esac

echo "✅ Done!"
