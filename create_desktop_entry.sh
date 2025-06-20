#!/bin/bash

echo "Creating a .desktop file for a Nix-installed app."

# Ask for inputs
read -p "Enter Application Name (e.g., VLC Media Player): " app_name
read -p "Enter executable path (full path to binary, e.g., /home/your-username/.nix-profile/bin/vlc): " exec_path
read -p "Enter icon name or full path (e.g., vlc): " icon_name
read -p "Enter categories (e.g., AudioVideo;Player;Video;): " categories

# Default categories if empty
if [ -z "$categories" ]; then
  categories="Utility;"
fi

# Sanitize app_name for filename (lowercase, no spaces)
desktop_file_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_').desktop

# Desktop file location
desktop_file_path="$HOME/.local/share/applications/$desktop_file_name"

# Create .desktop directory if not exists
mkdir -p "$HOME/.local/share/applications"

# Write the .desktop file
cat >"$desktop_file_path" <<EOL
[Desktop Entry]
Name=$app_name
Exec=$exec_path
Icon=$icon_name
Type=Application
Categories=$categories
Terminal=false
EOL

echo ".desktop file created at $desktop_file_path"

# Update desktop database (optional, depends on DE)
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$HOME/.local/share/applications"
  echo "Desktop database updated."
else
  echo "Command 'update-desktop-database' not found; you may need to update your desktop database manually."
fi

echo "Done!"
