#!/bin/sh
#  BzrToGit - SCM migration tool for going from bzr to git
#  Copyright (C) 2009  Henrik Nilsson
#  Copyright (C) 2010  Brice Maron <brice@bmaron.net>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License, version 3, as 
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# bail on errors
set -e

removebzr="no"
verbose="no"
with_ignore="no"

for x in $@; do
  if [ "$x" = "--removebzr" ]; then removebzr="yes"

  elif [ "$x" = "-v" ] || [ "$x" = "--verbose" ]; then verbose="yes"

  elif [ "$x" = "--with-ignore" ]; then with_ignore="yes"

  elif [ "$x" = "--help" ]; then
    echo "--removebzr   = Remove the .bzr directory so that it can't be used by bazaar"
    echo "--with-ignore = Convert the Ignore file too"
    echo "-v --verbose  = Show processiong messages"
    echo "--help        = Display this list"
    exit

  else echo "${x}: unknown argument, type --help to see available arguments"; exit 1; fi
done

rev=1
git init

if [ "$verbose" != "no" ] ; then echo "Start Migration" ; fi

while bzr revert -r revno:$rev 2> /dev/null; do
  logentry="`bzr log -r $rev`"
  committer="`echo "$logentry" | sed -n -e "/^committer:/{s/^committer: //;p;}"`"
  timestamp="`echo "$logentry" | sed -n -e "/^timestamp:/{s/^timestamp: //;p;}"`"
  export GIT_AUTHOR_DATE="$timestamp"
  export GIT_COMMITTER_DATE="$timestamp"
  msg="`echo "$logentry" | sed -e "1,/^message:/d"`"
  ls -a1 | while read x; do
    if [ "$x" != ".bzr" ] && [ "$x" != "." ] && [ "$x" != ".." ]; then git add "$x"; fi
  done
  tag_name="`bzr tags -r $rev |  awk '{print $1}' `"
  
  git commit -a -m "$msg" --author="$committer"
  if [ -n "$tag_name" ]; then
    [ "$verbose" != "no" ] && echo "Tag added"
    git tag $tag_name
  fi


  let rev+=1
done

if [ -f .bzrignore ] && [ "$with_ignore" = "yes" ]; then
  cp  .bzrignore .gitignore
  git add .gitignore
  git commit -m "Adding Ignore file"
fi

[ "$removebzr" = "yes" ] && rm -r .bzr

[ "$verbose" != "no" ] && echo "Start Packing"
#Let's pack the newly created repo
git gc --aggressive

[ "$verbose" != "no" ] && echo "Migration Successfully ended"