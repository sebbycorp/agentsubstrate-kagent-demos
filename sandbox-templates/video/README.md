# Demo video

`sandbox-demo.mp4` is a terminal recording, a little over three minutes long,
that goes from "kagent is installed" to Pi running code in a sandbox. The video
file is not checked in (see the root `.gitignore`); record it with the steps
below. Nothing in it is simulated: the recorder types each command into a
real shell and waits for it to finish.

Each scene opens with a full-screen card that says what is about to happen,
then keeps that text as a header while the commands run.

| Scene | What happens |
| --- | --- |
| Intro | An animated diagram of the path: laptop, kagent, sandbox |
| 1. Where we start | `kagent sandbox templates` returns an empty list |
| 2. Turn on sandboxes | The guest image values |
| 3. Create the template | The manifest, then `scripts/03-sandbox-template.sh`. The wait for the Helm upgrade and the golden snapshot, about a minute, is cut. |
| 4. Check it by hand | Create a sandbox, run Python, show that GitHub is unreachable |
| 5. Connect Pi | `pi mcp add`, then `pi mcp list` shows the server connected |
| 6. Ask Pi a question | Pi's own interface, with its bash, edit, and write tools off |
| 7. Watch Agent Substrate work | Six sandboxes created and deleted, with live counts and timings |
| 8. Nothing left behind | `kagent sandbox list` is empty |

## Where the numbers in scene 7 come from

`anim.py load` draws the panel. The running and suspended counts are read from
kagent's `SystemService/GetSubstrateSummary` with `grpcurl` after every step.
The timings are the wall clock of each `kagent sandbox create` call. The
suspended actors are idle agent sessions left over from earlier demos.

## Record it again

```bash
brew install vhs grpcurl

# From sandbox-templates/:
kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &
kubectl delete sandboxtemplate --all -n kagent   # so scene 1 shows an empty list
vhs video/demo.tape
```

| File | What to change there |
| --- | --- |
| `demo.tape` | The commands, the pauses (`Sleep`), the card text, the font size and theme, the model Pi uses |
| `cards.sh` | How a title card looks |
| `anim.py` | The intro animation and the stats panel |

The tape waits for `RUNTIME_STATE_DELETED` to appear on screen before it ends
the Pi scene, so a run where the model never deletes its sandbox times out
after four minutes.
