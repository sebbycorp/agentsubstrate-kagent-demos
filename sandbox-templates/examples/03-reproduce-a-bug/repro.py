"""Repro steps from the ticket: "build script crashes on startup since we
upgraded". The engineer on Python 3.11 cannot see it."""
import sys

print("python", sys.version.split()[0])
from distutils.version import LooseVersion  # removed in Python 3.12

print("ok:", LooseVersion("1.10") > LooseVersion("1.9"))
