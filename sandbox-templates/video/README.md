# Demo video

[`sandbox-demo.mp4`](sandbox-demo.mp4) is a 109-second terminal recording that
goes from "kagent is installed" to Pi running code in a sandbox. Nothing in it
is simulated: the recorder types each command into a real shell and waits for
it to finish.

1. **No templates yet.** `kagent sandbox templates` returns an empty list.
2. **Set up kagent.** Show the guest image values and the SandboxTemplate, then
   run `scripts/03-sandbox-template.sh`. The wait for the Helm upgrade and the
   golden snapshot, about a minute, is cut from the recording.
3. **Check it by hand.** Create a sandbox, run Python, and show that GitHub is
   unreachable.
4. **Set up Pi.** `pi mcp add` registers kagent's MCP endpoint, and
   `pi mcp list` shows it connected.
5. **Use it from Pi.** Pi's own interface, with its bash, edit, and write tools
   off. It creates a sandbox, writes the data and a script into it, runs the
   script, deletes the sandbox, and answers.
6. **Nothing left behind.** `kagent sandbox list` is empty.

## Record it again

Install [VHS](https://github.com/charmbracelet/vhs) with `brew install vhs`.
Then, from `sandbox-templates/`:

```bash
kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &

# So that the opening scene shows an empty list:
kubectl delete sandboxtemplate --all -n kagent

vhs video/demo.tape
```

The tape starts Pi with `--model openai/gpt-4.1`. Change it there to use
another model. It waits for `RUNTIME_STATE_DELETED` to appear on screen before
it ends the Pi scene, so a run where the model never deletes the sandbox times
out after four minutes.
