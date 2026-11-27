Use the kagent sandbox tools to answer this question: what drove churn last
quarter?

The data is in the local file churn.csv. Do not analyze it yourself and do not
run anything on this machine. Instead:

1. Create one Sandbox from the `python` template in the `kagent` namespace,
   with ttl_seconds 600 and a request_id that ends in a random suffix,
   so that it does not collide with an earlier run.
2. Put churn.csv and a Python script into the Sandbox. Do not hand-encode
   base64 for write_sandbox_file. Instead, create each file with
   start_sandbox_process and a shell heredoc, for example the command
   ["sh", "-c", "cat > main.py <<'EOF'\n...file content...\nEOF"].
   The Sandbox has only the Python standard library and no network access.
3. Run the script there. Break churn rate down by plan and by support ticket
   volume (5 or more tickets versus fewer).
4. Read the output, then delete the Sandbox. Delete it even if a step failed.

Reply with a two-sentence answer, the program's output, and the Sandbox ID you
used and deleted.
