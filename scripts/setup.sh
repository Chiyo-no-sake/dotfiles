#!/bin/bash

chsh -s $(which zsh)

ZSHRC_FILE="$HOME/.zshrc"
DOTFILES_INIT_FILE="$HOME/dotfiles/init.sh"
DOTFILES_ENV_TEMPLATE_FILE="$HOME/dotfiles/.env.template"
DOTFILES_ENV_FILE="$HOME/dotfiles/.env"
SOURCE_COMMAND="source $DOTFILES_INIT_FILE"
COMMENT_LINE="### Paso dotfiles settings ###"

echo "Checking dotfiles configuration for $ZSHRC_FILE..."

# 1. Check if the .dotfiles/init.sh file actually exists
if [ ! -f "$DOTFILES_INIT_FILE" ]; then
    echo "Warning: Dotfiles initialization file not found at '$DOTFILES_INIT_FILE'."
    echo "Skipping adding source command to '$ZSHRC_FILE'."
    exit 0 # Exit without error, as nothing needs to be done.
fi

# 2. Check if the source command is already present in ~/.zshrc
if grep -qF "$SOURCE_COMMAND" "$ZSHRC_FILE"; then
    echo "The command '$SOURCE_COMMAND' is already present in '$ZSHRC_FILE'. Skipping."
else
    # If the file exists and the command is not present, then append
    echo "Adding dotfiles source configuration to '$ZSHRC_FILE'..."
    echo "$COMMENT_LINE" >> "$ZSHRC_FILE"
    echo "$SOURCE_COMMAND" >> "$ZSHRC_FILE"
    echo "Done. Please remember to 'source ~/.zshrc' or open a new terminal."
fi

# create the .env file from template if not already there
if [ ! -f "$DOTFILES_ENV_FILE" ]; then
    cp "$DOTFILES_ENV_TEMPLATE_FILE" "$DOTFILES_ENV_FILE" && echo "created .env file at ${DOTFILES_ENV_FILE}"
fi

## Download appimages for the first time
./appimagesdl.sh

## Install flatpak applications
./flatpak.sh

## Setup asdf
./asdfsetup.sh

## Load the new shell
source ~/dotfiles/init.sh

## Setup open-interpreter
./open-interpreter.sh
