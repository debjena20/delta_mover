#!/bin/bash

# Author: Deb Jena

# source and destination paths for the first script
source_path_1="/storage/backup-wl/delta"
delta_backup_path="/home/user/delta_backup"
to_transfer_path="/home/user/to_transfer"

# move files to delta_backup folder
move_files() {
  mkdir -p "$delta_backup_path" || { echo "Failed to create delta_backup folder"; exit 1; }
  rsync -av --remove-source-files --exclude='*/' "$source_path_1/" "$delta_backup_path" || { echo "Failed to move files to delta_backup folder"; exit 1; }
}

# create md5 checksums in to_transfer folder
create_checksums() {
  mkdir -p "$to_transfer_path" || { echo "Failed to create to_transfer folder"; exit 1; }
  cd "$delta_backup_path" || { echo "Failed to change directory to delta_backup folder"; exit 1; }

  for file in *; do
    if [ -f "$file" ]; then
      cp "$file" "$to_transfer_path/$file" || { echo "Failed to copy $file to to_transfer folder"; exit 1; }
      md5sum "$file" > "$to_transfer_path/$file.md5" || { echo "Failed to create md5 file for $file"; exit 1; }
    fi
  done
}

# delete files in delta_backup older than 7 days
delete_old_files() {
  find "$delta_backup_path" -type f -mtime +7 -delete || { echo "Failed to delete old files"; exit 1; }
}

# source and destination paths for the second script
source_path_2="/home/user/to_transfer"
destination_ip="10.1.24.90"
destination_path="/tmp/delta_files"
remote_destination_path="/storage/backup-wl/delta_remote"
log_path="/var/log/md5failures.log"

# move files to the remote server
move_files_remote() {
  rsync -avz --remove-source-files --exclude='*/' "$source_path_2/" "user@$destination_ip:$destination_path" || { echo "Failed to move files to the remote server"; exit 1; }
}

# create MD5 checksums in the remote server
create_checksums_remote() {
  ssh "user@$destination_ip" "sudo sh -c 'cd $destination_path && md5sum *.zip > checksums.txt'" || { echo "Failed to create MD5 checksums in the remote server"; exit 1; }
}

# validate MD5 checksums
validate_checksums() {
  ssh "user@$destination_ip" "sudo sh -c 'cd $destination_path && md5sum -c checksums.txt'" | sudo tee "$log_path" || { echo "Failed to validate MD5 checksums"; exit 1; }
}

# transfer files from /tmp to /storage/backup-wl/delta_remote
transfer_files_remote() {
  ssh "user@$destination_ip" "sudo find $destination_path -maxdepth 1 -type f -name '*.zip' -exec sh -c 'file=\$(basename \"\$1\"); if [ ! -e \"$remote_destination_path/\$file\" ]; then sudo mv \"\$1\" \"$remote_destination_path/\$file\"; fi' sh {} \;" || { echo "Failed to transfer files to the remote destination"; exit 1; }
}

# first part execution
move_files
create_checksums
delete_old_files

# second part execution
move_files_remote
create_checksums_remote
validate_checksums
transfer_files_remote
