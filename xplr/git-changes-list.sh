#!/bin/sh
git -C "$1" status --porcelain 2>/dev/null \
  | awk '{ x=substr($0,1,1); y=substr($0,2,1); p=substr($0,4);
           if (x!=" " && x!="?") s[++ns]=sprintf("%-8s %s %s","staged",x,p);
           if (y!=" ")           u[++nu]=sprintf("%-8s %s %s","unstaged",y,p) }
         END { for(i=1;i<=ns;i++) print s[i]; for(i=1;i<=nu;i++) print u[i] }'
