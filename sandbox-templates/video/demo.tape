# Run from sandbox-templates/ with:  vhs video/demo.tape
# Each scene opens with a full-screen card, then keeps the card's text as a
# header while the commands run.
Output video/sandbox-demo.mp4
Set Shell bash
Set FontSize 19
Set Width 1440
Set Height 900
Set Padding 28
Set Theme "Catppuccin Mocha"
Set TypingSpeed 30ms
Set WaitTimeout 600s
Set WaitPattern /^>$/

Hide
Type "export PS1='\[\e[1;35m\]>\[\e[0m\] ' && source video/cards.sh && clear" Enter
Sleep 1s
Type "python3 video/anim.py intro" Enter
Sleep 300ms
Show
Sleep 9s
Hide
Wait

# ---------------------------------------------------------------- Step 1
Type "card 5 'Step 1 of 8 · Where we start' 'kagent is already installed on this cluster.' 'There are no sandbox templates yet, so nobody can create a sandbox.'" Enter
Sleep 400ms
Show
Sleep 4s
Hide
Wait
Show
Sleep 2s
Type "kagent sandbox templates" Enter
Wait
Sleep 4s

# ---------------------------------------------------------------- Step 2
Hide
Type "card 5 'Step 2 of 8 · Turn on sandboxes' 'kagent runs a small helper inside every sandbox. It needs an image, and the chart ships none.' 'These values also cap the CPU, memory and lifetime of every sandbox.'" Enter
Sleep 400ms
Show
Sleep 4s
Hide
Wait
Show
Sleep 2s
Type "cat manifests/sandbox-values.yaml" Enter
Wait
Sleep 6s

# ---------------------------------------------------------------- Step 3
Hide
Type "card 5 'Step 3 of 8 · Create the template' 'The template is the recipe for the box: which image goes inside, pinned by digest.' 'It lists no egress policy, so a sandbox made from it has no network at all.'" Enter
Sleep 400ms
Show
Sleep 4s
Hide
Wait
Show
Sleep 2s
Type "cat manifests/sandboxtemplate-python.yaml" Enter
Wait
Sleep 6s
Type "./scripts/03-sandbox-template.sh" Enter
Sleep 4s
Hide
Wait
Show
Sleep 6s

# ---------------------------------------------------------------- Step 4
Hide
Type "card 5 'Step 4 of 8 · Check it by hand' 'Before an agent touches it: create a sandbox, run Python in it,' 'then try to reach GitHub from inside.'" Enter
Sleep 400ms
Show
Sleep 4s
Hide
Wait
Show
Sleep 2s
Type "SB=$(kagent sandbox create python --request-id demo-$RANDOM -o json | jq -r .id); echo $SB" Enter
Wait
Sleep 2s
Type "kagent sandbox exec $SB -- python --version" Enter
Wait
Sleep 3s
Type "kagent sandbox exec $SB -- bash -c 'exec 3<>/dev/tcp/github.com/443 && echo reachable || echo blocked'" Enter
Wait
Sleep 5s
Hide
Type "kagent sandbox delete $SB >/dev/null" Enter
Wait

# ---------------------------------------------------------------- Step 5
Type "card 5 'Step 5 of 8 · Connect Pi' 'kagent serves an MCP endpoint on port 8083. Nothing extra to deploy.' 'Register it with Pi, then check that Pi can see the sandbox tools.'" Enter
Sleep 400ms
Show
Sleep 4s
Hide
Wait
Show
Sleep 2s
Type "pi mcp add kagent --url http://localhost:8083/mcp --exposure direct" Enter
Wait
Sleep 3s
Type "pi mcp list | cut -c1-110" Enter
Wait
Sleep 6s

# ---------------------------------------------------------------- Step 6
Hide
Type "card 7 'Step 6 of 8 · Ask Pi a question' 'Pi runs on this laptop with its bash, edit and write tools turned off.' 'It cannot run code here. Watch it create a sandbox, run the analysis there, and delete it.'" Enter
Sleep 400ms
Show
Sleep 6s
Hide
Wait
Show
Sleep 2s
Type "cd demo && pi --model openai/gpt-4.1 --exclude-tools bash,edit,write,subagent" Enter
Sleep 6s
Type "What drove churn last quarter? The data is in churn.csv. Break churn rate down by plan, and by support tickets (5 or more vs fewer). Run it in a kagent sandbox (python template, kagent namespace), not on this machine. Standard library only. Create files with a shell heredoc through start_sandbox_process. Delete the sandbox when done."
Sleep 3s
Enter
Wait+Screen@240s /RUNTIME_STATE_DELETED/
Sleep 16s
Type "/quit" Enter
Sleep 2s

# ---------------------------------------------------------------- Step 7
Hide
Type "cd .. && card 6 'Step 7 of 8 · Watch Agent Substrate work' 'Six sandboxes, one after another. The counts are live from Agent Substrate.' 'No pod is scheduled and no image is pulled. Each one is restored from the template snapshot.'" Enter
Sleep 400ms
Show
Sleep 5s
Hide
Wait
Show
Sleep 2s
Type "python3 video/anim.py load 6" Enter
Wait
Sleep 3s

# ---------------------------------------------------------------- Step 8
Hide
Type "card 5 'Step 8 of 8 · Nothing left behind' 'Pi deleted its sandbox when it finished.' 'Anything it forgot would expire on its own.'" Enter
Sleep 400ms
Show
Sleep 4s
Hide
Wait
Show
Sleep 2s
Type "kagent sandbox list" Enter
Wait
Sleep 5s

Hide
Type "CARD_HEADER=0 card 7 'The agent ran code. None of it ran on my laptop.' 'One Helm value, one template, one MCP URL.' '' 'github.com/sebbycorp/agentsubstrate-kagent-demos'" Enter
Sleep 400ms
Show
Sleep 6s
