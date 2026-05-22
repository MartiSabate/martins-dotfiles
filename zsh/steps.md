(ask the user to run the script with sudo privileges)
(in some steps it asks to modify /etc/zsh/zshrc or ~/.zshrc (from step 5), before starting the script ask the user if configure zsh for the local user or all the users)
(before making any step, verify that it is not already done/installed)



1. Install zsh: `sudo apt install zsh`

2. Set zsh as default shell `chsh -s /usr/bin/zsh`

3. Logout and login to test the shell `echo $SHELL`

4. Install oh my zsh: `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`

5. Add `ZSH_THEME="robbyrussell"` to the last line of /etc/zsh/zshrc (add it to ~/.zshrc for local user). Ask the user which file modify

6. Add `ZSH_THEME="agnoster" # (this is one of the fancy ones)
# see https://github.com/ohmyzsh/ohmyzsh/wiki/Themes#agnoster` in /etc/zsh/zshrc or ~/.zshrc (ask user as in step 5)

7. Install powerline: `sudo apt-get install fonts-powerline`

8. Install powerlevel10k: `git clone --depth=1 https://github.com/romkatv/powerlevel10k.git 
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k`

9. edit the ZSH_THEME in /etc/zsh/zshrc or ~/.zshrc (ask user as in step 5) to `ZSH_THEME="powerlevel10k/powerlevel10k"
`

10. Open a new session and run `p10k configure`

11. Download zsh-autosuggestions: `git clone https://github.com/zsh-users/zsh-autosuggestions.git 
$ZSH_CUSTOM/plugins/zsh-autosuggestions `

12. Download zsh-syntax-higlighting: `git clone https://github.com/zsh-users/zsh-syntax-highlighting.git 
$ZSH_CUSTOM/plugins/zsh-syntax-highlighting`

13. Edit /etc/zsh/zshrc or ~/.zshrc (ask user as in step 5) and find plugins=(git) replace plugins=(git) with: `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)`





