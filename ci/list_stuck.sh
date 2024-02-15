pgrep postgres | xargs -r ps
pgrep memcheck | xargs -r ps
pgrep python | xargs -r ps

pgrep bash | sudo xargs -r -I{} bash -c 'ps {}; gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" -p {}'