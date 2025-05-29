# Prevent git from prompting for authentication
git config --global credential.helper ""
git config --global credential.interactive never
$env:GIT_TERMINAL_PROMPT = 0
$env:GCM_INTERACTIVE = "never"
