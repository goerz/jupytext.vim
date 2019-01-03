---
name: Bug report
about: Create a bug report
title: ''
labels: ''
assignees: ''

---

**Describe the bug**

A clear and concise description of what the bug is.

**Diagnostics**

* `vim --version`:

* Operating system information (e.g. `uname -a`):

* `python --VV`:

* Are you using Anaconda?

* Put `let g:jupytext_print_debug_msgs = 1` in your `~/.vimrc`. What is the output of `:messages` when reproducing the problem?

* Does converting the notebook to/from ipynb with `jupytext` on the command line work?

* Does it work when you set `g:jupytext_command` in `~/.vimrc` to be the exact some `jupytext` that you used manually, with the exact same version of Python?
