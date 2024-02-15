pgrep postgres | xargs -r ps
pgrep memcheck | xargs -r ps
pgrep python | xargs -r ps

pgrep postgres | sudo xargs -r gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" -p