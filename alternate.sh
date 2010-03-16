#!/bin/sh
# 
# USAGE
#
#     bzr2git SOURCE [DEST]
# 
# SUMMARY
#
#     Converts bzr branch at SOURCE to git repo at DEST.
#
#     DEST will be created and must not exist prior to calling.
#     If no DEST is provided, assume basename of SOURCE.
#
# SYNOPSIS
#
#     Convert local bzr branch at ~/bzr/some-project to new git repo
#     at ~/git/some-project:
#
#         $ mkdir ~/git
#         $ cd ~/git
#         $ bzr2git ~/bzr/some-project
#     
#     You can also specify the name of the new git directory:
#
#         $ mkdir ~/git
#         $ bzr2git ~/bzr/some-project ~/git/some-project
#
# NOTES
#
#     I whipped this together in about 15 minutes so don't get your hopes 
#     up. It should work fine for most simple cases but there's a variety
#     of issues that make it suboptimal: it's slow, doesn't track renames
#     properly, and won't bring in branches or tags properly. It works well
#     enough for bringing history on a single master branch, though.
#
#     You will need recent version of bzr and git as well as rsync.
# 
# Copyright (c) 2008, Ryan Tomayko <rtomayko@gmail.com>
#
# Please let me know if you make improvements to this script.

# bail on errors
set -e

# we need somewhere to do work...
WORK_DIR="/tmp/bzr2git-$$"
L="/tmp/bzr-log-$$"

# remove work stuff on exit
trap "rm -rf $WORK_DIR $L" 0

# exit with usage message
bail() {
  echo "usage: $0 SOURCE [DEST]"
  exit 1
}

# grab source and dest arguments
SOURCE="$1"
DEST="$2"

# bail if no source given
if [ -z "$SOURCE" ] ; then 
  echo >&2 "must specify source bzr repository and dest git tree"
  bail
fi

# default DEST to basename of source
[ -z "$DEST" ] && DEST=`basename $SOURCE`

# bail if DEST already exists
if [ -d "$DEST" ] ; then
  echo >&2 "$DEST already exists"
  exit 1
fi

ORIG_DIR=`pwd`

# create our work directory
mkdir -p $WORK_DIR

# initialize empty git repo
mkdir $WORK_DIR/git
cd $WORK_DIR/git
git init >/dev/null

# grab bzr branch at changeset 1
rev=1
cd $WORK_DIR
bzr branch -r$rev "$SOURCE" bzr >/dev/null 2>&1

# figure out how many changesets we have in our bzr branch
last_rev=`bzr version-info --custom --template='{revno}' $SOURCE`

# loop over each changeset number
while true 
do

  echo "===> Importing changeset $rev of $last_rev..."

  # grab meta data
  cd $WORK_DIR/bzr
  bzr log -r $rev > $L
  AUTHOR=`cat $L | grep ^committer: | cut -c12-`
  DATE=`cat $L | grep ^timestamp: | cut -c12-`

  # update git work dir
  rsync -ar --delete --exclude=.bzr/ --exclude=.git/ $WORK_DIR/bzr/ $WORK_DIR/git/

  # perform commit
  GIT_AUTHOR_DATE="$DATE"
  GIT_COMMITTER_DATE="$DATE"
  export GIT_AUTHOR_DATE GIT_COMMITTER_DATE
  cd $WORK_DIR/git
  git add .

  [ "$AUTHOR" = "rtomayko" ] && AUTHOR="Ryan Tomayko <rtomayko@gmail>"
  echo $AUTHOR
  cat $L | tail -n +7

  cat $L | tail -n +7 | cut -c3- | git commit -q -a --author "$AUTHOR" -F - || true

  # grab next rev
  rev=`echo $rev + 1 | bc`
  [ $rev -gt $last_rev ] && break
  cd $WORK_DIR/bzr
  bzr pull -r $rev --overwrite >/dev/null 2>&1

done

cd "$ORIG_DIR"
mv "$WORK_DIR/git" "$DEST"
cd $DEST
git gc --prune --aggressive
echo "New git repo ready in $DEST"