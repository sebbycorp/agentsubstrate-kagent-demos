Output video/sandbox-demo.mp4
Set Shell bash
Set FontSize 19
Set Width 1440
Set Height 900
Set Padding 28
Set Theme "Catppuccin Mocha"
Set TypingSpeed 24ms
Set WaitTimeout 600s
Set WaitPattern /^>$/

Hide
Type "export PS1='\[\e[1;35m\]>\[\e[0m\] ' && clear" Enter
Sleep 1s
Show

Type "# kagent is installed, but there are no sandbox templates yet" Enter
Type "kagent sandbox templates" Enter
Wait
Sleep 2.5s

Type "# Setup, part 1: kagent. A guest image turns sandboxes on." Enter
Type "cat manifests/sandbox-values.yaml" Enter
Wait
Sleep 4s
Type "# The template: which image, and no egress policy, so no network" Enter
Type "cat manifests/sandboxtemplate-python.yaml" Enter
Wait
Sleep 5s
Type "./scripts/03-sandbox-template.sh" Enter
Sleep 4s
Hide
Wait
Show
Sleep 5s
Type "clear" Enter

Type "# Check it by hand: run Python, then try to reach GitHub" Enter
Type "SB=$(kagent sandbox create python --request-id demo-$RANDOM -o json | jq -r .id); echo $SB" Enter
Wait
Sleep 1s
Type "kagent sandbox exec $SB -- python --version" Enter
Wait
Sleep 2s
Type "kagent sandbox exec $SB -- bash -c 'exec 3<>/dev/tcp/github.com/443 && echo reachable || echo blocked'" Enter
Wait
Sleep 3.5s
Type "kagent sandbox delete $SB >/dev/null; clear" Enter
Wait

Type "# Setup, part 2: Pi. kagent serves MCP on port 8083. Register it." Enter
Type "pi mcp add kagent --url http://localhost:8083/mcp --exposure direct" Enter
Wait
Sleep 2s
Type "pi mcp list | cut -c1-110" Enter
Wait
Sleep 4.5s
Type "clear" Enter

Type "# Now use it. Pi runs here, with no bash, edit or write tools." Enter
Type "cd demo && pi --model openai/gpt-4.1 --exclude-tools bash,edit,write,subagent" Enter
Sleep 6s
Type "What drove churn last quarter? The data is in churn.csv. Break churn rate down by plan, and by support tickets (5 or more vs fewer). Run it in a kagent sandbox (python template, kagent namespace), not on this machine. Standard library only. Create files with a shell heredoc through start_sandbox_process. Delete the sandbox when done."
Sleep 1.5s
Enter
Wait+Screen@240s /RUNTIME_STATE_DELETED/
Sleep 14s
Type "/quit" Enter
Sleep 2s
Type "kagent sandbox list   # nothing left behind" Enter
Wait
Sleep 4s
