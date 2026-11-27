Output video/sandbox-demo.mp4
Set Shell bash
Set FontSize 19
Set Width 1440
Set Height 900
Set Padding 28
Set Theme "Catppuccin Mocha"
Set TypingSpeed 28ms
Set WaitTimeout 240s
Set WaitPattern /^>$/

Hide
Type "export PS1='\[\e[1;35m\]>\[\e[0m\] ' PI_MODEL=openai/gpt-4.1 && clear" Enter
Sleep 1s
Show

Type "# kagent is installed. What can a sandbox start from?" Enter
Type "kagent sandbox templates" Enter
Wait
Sleep 2.5s

Type "# 1. Create a sandbox and run something in it" Enter
Type "SB=$(kagent sandbox create python --request-id demo-$RANDOM -o json | jq -r .id); echo $SB" Enter
Wait
Sleep 1.5s
Type "kagent sandbox exec $SB -- python --version" Enter
Wait
Sleep 2.5s

Type "# 2. No network unless I grant it. Try GitHub." Enter
Type "kagent sandbox exec $SB -- bash -c 'exec 3<>/dev/tcp/github.com/443 && echo reachable || echo blocked'" Enter
Wait
Sleep 3.5s
Type "kagent sandbox delete $SB" Enter
Wait
Sleep 1.5s
Type "clear" Enter

Type "# 3. Now Pi. It runs on my laptop. Its code runs in the sandbox." Enter
Type "./examples/05-pi/run-live.sh" Enter
Wait
Sleep 6s
Type "kagent sandbox list   # nothing left behind" Enter
Wait
Sleep 3s
Type "clear" Enter

Type "# 4. Is the wall real? Try to break in to the pod that hosts sandboxes." Enter
Type "./examples/06-isolation-test/run.sh" Enter
Wait
Sleep 6s
