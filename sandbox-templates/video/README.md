# Demo video

[`sandbox-demo.mp4`](sandbox-demo.mp4) is a 91-second terminal recording of the
demos running against a cluster where kagent is already installed and the
`python` template exists. Nothing in it is simulated: the recorder types each
command into a real shell and waits for it to finish.

1. List the sandbox templates.
2. Create a sandbox, run Python in it, and show that GitHub is unreachable.
3. Pi answers "what drove churn?" with its local execution tools off. Each
   tool call prints as Pi makes it.
4. The isolation test: two pods fail to reach the Worker pod, the control connects.

To record it again, install [VHS](https://github.com/charmbracelet/vhs)
(`brew install vhs`), start the port-forward, and run this from `sandbox-templates/`:

```bash
kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &
vhs video/demo.tape
```

The tape sets `PI_MODEL=openai/gpt-4.1`. Change it there to use another model.
